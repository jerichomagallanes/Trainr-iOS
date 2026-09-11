import Foundation
import Testing
@testable import Trainr

struct PlanSelectionSchemaTests {

    private let builder: PlanSkeletonBuilder

    init() throws {
        let url = try #require(Bundle.main.url(forResource: "exercise-catalog", withExtension: "json"))
        builder = PlanSkeletonBuilder(catalog: ExerciseCatalogReader.read(try Data(contentsOf: url)))
    }

    private func user(
        goal: FitnessGoal = .muscleGain, days: Int = 4, minutes: Int = 60, experience: ExperienceLevel = .intermediate
    ) -> UserProfile {
        var user = UserProfile()
        user.age = 34
        user.weight = 80
        user.fitnessGoal = goal
        user.experienceLevel = experience
        user.availableEquipment = Equipment.allCases
        user.workoutDaysPerWeek = days
        user.workoutDuration = minutes
        return user
    }

    private func skeleton(_ profile: UserProfile? = nil) -> PlanSkeleton {
        builder.build(PlanRequest(user: profile ?? user(), weekNumber: 1, startDate: Date(timeIntervalSince1970: 0)))
    }

    private func slot(_ id: String, _ candidates: String...) -> SkeletonSlot {
        SkeletonSlot(
            id: id, label: "the \(id)", tier: .accessory, patterns: [], muscles: [],
            candidates: candidates, sets: 3, restSeconds: 60
        )
    }

    private func handBuilt(_ days: SkeletonDay...) -> PlanSkeleton {
        PlanSkeleton(
            title: "Test Week", days: days, units: .metric, maxSetsPerSession: 20, sessionCeilingMinutes: 90,
            weeklySetsByRegion: [:], uncoveredPatterns: []
        )
    }

    private func properties(_ schema: SelectionSchema?) -> [SelectionProperty] {
        if case .object(let properties) = schema { return properties }
        return []
    }

    private func child(_ schema: SelectionSchema?, _ name: String) -> SelectionSchema? {
        properties(schema).first { $0.name == name }?.schema
    }

    @Test func everyOpenSlotIsAnEnumOfItsOwnCandidatesInRankOrder() {
        let skeleton = skeleton()
        let schema = PlanSelectionSchema.schema(for: skeleton)

        for day in skeleton.days where !day.openSlots.isEmpty {
            for slot in day.openSlots {
                #expect(child(child(schema, day.id), slot.id) == .oneOf(slot.candidates, description: slot.label))
            }
        }
    }

    // Disjoint lists are what make a movement used twice in one session
    // something the model cannot write.
    @Test func noSessionOffersOneMovementInTwoSlots() {
        for goal in FitnessGoal.allCases {
            for session in properties(PlanSelectionSchema.schema(for: skeleton(user(goal: goal, days: 5)))) {
                let offered = properties(session.schema).flatMap { property -> [String] in
                    if case .oneOf(let values, _) = property.schema { return values }
                    return []
                }
                #expect(offered.count == Set(offered).count, "\(goal) \(session.name)")
            }
        }
    }

    @Test func settledSlotsAndSettledSessionsAreNotAsked() {
        let schema = PlanSelectionSchema.schema(for: handBuilt(
            SkeletonDay(dayNumber: 1, focus: .fullBody, slots: [slot("warm_up", "arm_circles"), slot("primary", "a", "b")]),
            SkeletonDay(dayNumber: 4, focus: .mobilityFlow, slots: [slot("mobility", "stretching")])
        ))

        #expect(properties(schema).map(\.name) == ["day1"])
        #expect(properties(child(schema, "day1")).map(\.name) == ["primary", "title"])
    }

    @Test func aSlotWithNothingToOfferAsksForTextRatherThanAnImpossibleEnum() {
        let schema = PlanSelectionSchema.schema(for: handBuilt(
            SkeletonDay(dayNumber: 1, focus: .fullBody, slots: [slot("primary"), slot("secondary", "a", "b")])
        ))

        #expect(child(child(schema, "day1"), "primary") == .text(description: "the primary"))
    }

    // Both platforms render the same bytes from the same week, so the two
    // apps cannot drift apart in what they ask a model for.
    @Test func theSchemaMatchesTheSharedFixture() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let fixture = try String(
            contentsOf: root.appendingPathComponent("docs/fixtures/plan-selection-schema.json"), encoding: .utf8
        )

        #expect(PlanSelectionSchema.schema(for: skeleton()).json == fixture)
    }

    @Test func theRenderingIsJsonThatRequiresEverything() throws {
        let data = Data(PlanSelectionSchema.schema(for: skeleton()).json.utf8)
        let rendered = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let required = try #require(rendered["required"] as? [String])
        let named = try #require(rendered["properties"] as? [String: Any])

        #expect(Set(required) == Set(named.keys))
    }

    // The schema is paid for on every request, so the largest week the setup
    // screen allows has to stay cheap.
    @Test func theLargestWeekStaysUnderTwelveKilobytes() {
        for goal in FitnessGoal.allCases {
            for days in 1...7 {
                let bytes = PlanSelectionSchema.schema(
                    for: skeleton(user(goal: goal, days: days, minutes: 90, experience: .advanced))
                ).json.utf8.count
                #expect(bytes < 12 * 1024, "\(goal) \(days)d")
            }
        }
    }
}
