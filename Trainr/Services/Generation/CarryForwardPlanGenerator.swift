import Foundation

// Next week is last week's movements, progressed from what was lifted: a lift
// only moves on while it stays in the programme. A profile
// edit that rules a movement out, a split with no room for it, or a client
// asking for new movements hands the week to the generator behind this one.
struct CarryForwardPlanGenerator: PlanGenerator {

    private let builder: PlanSkeletonBuilder
    private let assembler: PlanAssembler
    private let next: any PlanGenerator

    init(catalog: any ExerciseCatalog, next: any PlanGenerator) {
        builder = PlanSkeletonBuilder(catalog: catalog)
        assembler = PlanAssembler(catalog: catalog)
        self.next = next
    }

    func generate(_ request: PlanRequest) async -> PlanGenerationResult {
        if !request.freshCast, let previous = request.previousWeek, let carried = carry(previous, request) {
            return .generated(carried)
        }
        return await next.generate(request)
    }

    private func carry(_ previous: WeeklyPlan, _ request: PlanRequest) -> WeeklyPlan? {
        let skeleton = builder.build(request)
        guard skeleton.isComplete, let selection = selection(from: previous, skeleton) else { return nil }
        return assembler.assemble(skeleton, selection: selection, request: request)
    }

    // Each of last week's movements back in a slot that offers it, on the same
    // day, under the same title. Nil when one is left over or a slot is left
    // empty, because the week would then not be last week's.
    private func selection(from previous: WeeklyPlan, _ skeleton: PlanSkeleton) -> PlanSelection? {
        guard previous.workoutDays.count == skeleton.days.count else { return nil }
        var days: [String: DaySelection] = [:]
        for day in skeleton.days {
            guard let before = previous.workoutDays.first(where: { $0.dayNumber == day.dayNumber }) else { return nil }
            var remaining = before.exercises.map(\.exerciseKey)
            for slot in day.slots where slot.isDecided {
                if let index = remaining.firstIndex(of: slot.candidates[0]) { remaining.remove(at: index) }
            }
            var slots: [String: String] = [:]
            for slot in day.openSlots {
                guard let index = remaining.firstIndex(where: slot.candidates.contains) else { return nil }
                slots[slot.id] = remaining.remove(at: index)
            }
            guard remaining.isEmpty else { return nil }
            days[day.id] = DaySelection(slots: slots, title: before.title)
        }
        return PlanSelection(days: days)
    }
}
