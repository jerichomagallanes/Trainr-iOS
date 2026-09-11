import Foundation
import Testing
@testable import Trainr

struct PlanSelectionRepairTests {

    private let repair = PlanSelectionRepair()

    private static func slot(_ id: String, _ label: String, _ candidates: String...) -> SkeletonSlot {
        SkeletonSlot(
            id: id, label: label, tier: .accessory, patterns: [], muscles: [],
            candidates: candidates, sets: 3, restSeconds: 60
        )
    }

    private static func skeleton(_ days: SkeletonDay...) -> PlanSkeleton {
        PlanSkeleton(
            title: "Test Week", days: days, units: .metric, maxSetsPerSession: 20, sessionCeilingMinutes: 90,
            weeklySetsByRegion: [:], uncoveredPatterns: []
        )
    }

    // Five open slots: the warm-up is settled and is not the model's to choose.
    private let week = skeleton(
        SkeletonDay(dayNumber: 1, focus: .fullBody, slots: [
            slot("warm_up", "the warm-up", "arm_circles"),
            slot("primary", "the main lift", "goblet_squat", "dumbbell_squat", "split_squat"),
            slot("secondary", "the second lift", "push_up", "dumbbell_bench_press"),
            slot("isolation", "the isolation", "biceps_curl", "hammer_curl")
        ]),
        SkeletonDay(dayNumber: 3, focus: .upper, slots: [
            slot("primary", "the main lift", "dumbbell_row", "pull_up"),
            slot("accessory", "the accessory lift", "lateral_raise", "front_raise")
        ])
    )

    private static let goodDay1 = [
        "primary": "dumbbell_squat", "secondary": "push_up", "isolation": "hammer_curl", "title": "Legs and Push"
    ]
    private static let goodDay3 = ["primary": "pull_up", "accessory": "lateral_raise", "title": "Upper Body Pull"]

    private func answer(
        day1: [String: String]? = PlanSelectionRepairTests.goodDay1,
        day3: [String: String]? = PlanSelectionRepairTests.goodDay3
    ) -> String {
        var object: [String: [String: String]] = [:]
        object["day1"] = day1
        object["day3"] = day3
        return String(decoding: try! JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }

    private func accepted(_ json: String) -> (selection: PlanSelection, repairs: Int)? {
        guard case .accepted(let selection, let repairs) = repair.repair(json, skeleton: week) else { return nil }
        return (selection, repairs)
    }

    private func problems(_ json: String) -> [String]? {
        guard case .rejected(let problems) = repair.repair(json, skeleton: week) else { return nil }
        return problems
    }

    private func with(_ day: [String: String], _ changes: [String: String]) -> [String: String] {
        day.merging(changes) { $1 }
    }

    @Test func aCleanAnswerIsTakenAsItIs() throws {
        let result = try #require(accepted(answer()))

        #expect(result.repairs == 0)
        #expect(result.selection.days["day1"] == DaySelection(
            slots: ["primary": "dumbbell_squat", "secondary": "push_up", "isolation": "hammer_curl"],
            title: "Legs and Push"
        ))
        #expect(result.selection.days["day3"]?.title == "Upper Body Pull")
    }

    // V0. The decoder's own words are not passed on: they can quote the answer.
    @Test func anAnswerThatIsNotAnObjectGoesBackWithOneFixedMessage() {
        for json in ["not json at all", "[1, 2]", "\"day1\"", ""] {
            #expect(problems(json) == [PlanSelectionRepair.notAnObject], "\(json)")
        }
    }

    // V1: a whole session missing is every one of its slots repaired.
    @Test func aMissingSessionIsFilledFromTheTopOfEachList() throws {
        let result = try #require(accepted(answer(day3: nil)))

        #expect(result.repairs == 2)
        #expect(result.selection.days["day3"] == DaySelection(
            slots: ["primary": "dumbbell_row", "accessory": "lateral_raise"], title: "Upper Body"
        ))
    }

    // V2
    @Test func aMissingSlotTakesTheTopOfItsList() throws {
        let result = try #require(accepted(answer(day1: Self.goodDay1.filter { $0.key != "isolation" })))

        #expect(result.repairs == 1)
        #expect(result.selection.days["day1"]?.slots["isolation"] == "biceps_curl")
    }

    // V3
    @Test func aMovementTheSlotNeverOfferedIsReplacedByItsBest() throws {
        let result = try #require(accepted(answer(day1: with(Self.goodDay1, ["isolation": "barbell_curl"]))))

        #expect(result.repairs == 1)
        #expect(result.selection.days["day1"]?.slots["isolation"] == "biceps_curl")
    }

    // V4
    @Test func aMovementAlreadyUsedThatDayIsNotUsedTwice() throws {
        let result = try #require(accepted(answer(day1: with(Self.goodDay1, ["secondary": "dumbbell_squat"]))))
        let chosen = Array(result.selection.days["day1"]?.slots.values ?? [:].values)

        #expect(result.repairs == 1)
        #expect(chosen.count == Set(chosen).count)
        #expect(result.selection.days["day1"]?.slots["secondary"] == "push_up")
    }

    // V5 to V8 are the app's to fix: a bad title costs no request.
    @Test func aTitleThatNamesNothingFallsBackToTheSessionAndCostsNoRetry() throws {
        let titles = [
            "Legs", "", "Five Words Is Too Many", String(repeating: "A", count: 20) + " " + String(repeating: "B", count: 21),
            "Full Body A", "Day 2 Legs", "Week 3 Push", "Good Form Training", "Upper Training Session"
        ]
        for title in titles {
            let result = try #require(accepted(answer(day1: with(Self.goodDay1, ["title": title]))))

            #expect(result.repairs == 0, "\(title)")
            #expect(result.selection.days["day1"]?.title == "Full Body", "\(title)")
        }
    }

    @Test func twoSessionsWithOneNameKeepItForTheFirstOnly() throws {
        let result = try #require(accepted(answer(
            day1: with(Self.goodDay1, ["title": "Upper Body Strength"]),
            day3: with(Self.goodDay3, ["title": "upper body strength"])
        )))

        #expect(result.selection.days["day1"]?.title == "Upper Body Strength")
        #expect(result.selection.days["day3"]?.title == "Upper Body")
    }

    // V9: mostly repaired is mostly the app's week, so the model is asked
    // again, told every problem at once.
    @Test func anAnswerMostlyRepairedGoesBackWithEveryProblemNamed() throws {
        let sent = try #require(problems(answer(
            day1: ["secondary": "goblet_squat", "isolation": "barbell_curl", "title": "Full Body A"],
            day3: with(Self.goodDay3, ["title": "Good Form Training"])
        )))

        #expect(Set(sent) == [
            "In day1 (Full Body) you left out the main lift. Fill every slot with one movement from that slot's own list.",
            "In day1 (Full Body), 'goblet_squat' is already used earlier in that session. Each slot needs a different movement.",
            "In day1 (Full Body), the isolation was answered with 'barbell_curl'. That is not on that slot's list. "
                + "Choose only from the keys listed for the slot you are filling.",
            "The title for day1 (Full Body) is an index label. The app already shows which day and which week it is; "
                + "name what the session trains.",
            "The title for day3 (Upper Body) uses \"good form\", which says nothing about this session. "
                + "Name the region and the focus instead."
        ])
        #expect(sent.count == 5)
    }

    @Test func aSessionLeftOutAndATitleTooShortAreBothNamed() throws {
        let sent = try #require(problems(answer(day1: ["title": "Legs"], day3: nil)))

        #expect(sent.contains(
            "You left out day3 (Upper Body). Answer every session in the schema, each with its title and each of its slots."
        ))
        #expect(sent.contains(
            "The title for day1 (Full Body) must be two to four words naming the body region and the focus, "
                + "like \"Upper Body Strength\". \"Legs\" is not."
        ))
    }

    @Test func anAnswerThatAnswersNoSessionGoesBack() {
        #expect(problems("{}")?.count == 2)
        #expect(problems(#"{"day2": {"primary": "push_up"}}"#)?.count == 2)
    }

    @Test func aWeekWithNothingLeftToChooseNeedsNoAnswer() {
        let settled = Self.skeleton(
            SkeletonDay(dayNumber: 1, focus: .fullBody, slots: [Self.slot("primary", "the main lift", "push_up")])
        )

        #expect(repair.repair("not json at all", skeleton: settled) == .accepted(PlanSelection(), repairs: 0))
    }
}
