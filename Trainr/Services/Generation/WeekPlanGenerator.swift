import Foundation

// A whole week from the catalog: the skeleton, a movement for every slot, and
// the engine's numbers. Next week is last week's movements, progressed from
// what was lifted, for as long as every one of them still has a place; a
// profile edit that rules one out, a split with no room for it, or a client
// asking for new movements picks the week afresh.
struct WeekPlanGenerator: PlanGenerator {

    private let catalog: any ExerciseCatalog
    private let builder: PlanSkeletonBuilder
    private let expander: PlanExpander
    private let parser: GeneratedPlanParser

    // Two candidates, not three: measured against the volume and frequency
    // the evidence asks for, going deeper spread a week's sets thinner
    // without buying any more variety worth having.
    private static let varietyDepth = 2
    private static let fnvOffset: Int32 = -2_128_831_035
    private static let fnvPrime: Int32 = 16_777_619

    init(catalog: any ExerciseCatalog = BundleExerciseCatalog()) {
        self.catalog = catalog
        builder = PlanSkeletonBuilder(catalog: catalog)
        expander = PlanExpander(catalog: catalog)
        parser = GeneratedPlanParser(catalog: catalog)
    }

    func generate(_ request: PlanRequest) async -> PlanGenerationResult {
        guard !catalog.all.isEmpty else { return .failed }
        let skeleton = builder.build(request)
        guard skeleton.isComplete else { return .failed }
        let previous = request.freshCast ? nil : request.previousWeek
        let carried = previous.flatMap { carry($0, skeleton) }
            .flatMap { assemble(skeleton, selection: $0, request: request) }
        return (carried ?? assemble(skeleton, selection: choose(skeleton, request), request: request))
            .map { PlanGenerationResult.generated($0) } ?? .failed
    }

    private func assemble(_ skeleton: PlanSkeleton, selection: PlanSelection, request: PlanRequest) -> WeeklyPlan? {
        let limits = PlanLimits(
            maxSetsPerSession: skeleton.maxSetsPerSession,
            allowedKeys: skeleton.allowedKeys,
            requiredPatterns: skeleton.requiredPatterns,
            sessionMinutes: request.user.workoutDuration,
            sessionCeilingMinutes: skeleton.sessionCeilingMinutes
        )
        switch parser.parse(
            expander.expand(skeleton, selection: selection, request: request),
            userID: request.user.id, weekNumber: request.weekNumber,
            startDate: request.startDate, limits: limits
        ) {
        case .parsed(let plan): return plan
        case .invalid: return nil
        }
    }

    // Each of last week's movements back in a slot that offers it, on the same
    // day, under the same title. Nil when one is left over or a slot is left
    // empty, because the week would then not be last week's.
    private func carry(_ previous: WeeklyPlan, _ skeleton: PlanSkeleton) -> PlanSelection? {
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

    // Two clients who answered the same way should not train the same week for
    // ever. Each slot takes one of its best few rather than always its first,
    // chosen from the client's own answers: the same person rebuilding the same
    // week gets the same movements, and the next person does not. Asking for a
    // fresh cast moves everyone along by a week.
    private func choose(_ skeleton: PlanSkeleton, _ request: PlanRequest) -> PlanSelection {
        let client = seed(of: request)
        var days: [String: DaySelection] = [:]
        for day in skeleton.days {
            var taken: Set<String> = []
            // A day that trains the same muscle the same way twice has spent
            // a slot on nothing, so variety never buys itself a repeat.
            var trained = Set(day.slots.filter(\.isDecided).compactMap { shape(of: $0.candidates[0]) })
            var slots: [String: String] = [:]
            for slot in day.openSlots {
                let order = rotated(slot, client: client, dayNumber: day.dayNumber, freshCast: request.freshCast)
                    .filter { !taken.contains($0) }
                let pick = order.first { candidate in shape(of: candidate).map { !trained.contains($0) } ?? true }
                    ?? order.first
                    ?? slot.candidates[0]
                taken.insert(pick)
                if let shape = shape(of: pick) { trained.insert(shape) }
                slots[slot.id] = pick
            }
            days[day.id] = DaySelection(slots: slots, title: day.fallbackTitle)
        }
        return PlanSelection(days: days)
    }

    // What a movement trains and how, which is what makes two of them a repeat.
    private func shape(of key: String) -> Shape? {
        catalog[key].map { Shape(pattern: $0.pattern, primary: $0.primary) }
    }

    private struct Shape: Hashable {
        let pattern: MovementPattern
        let primary: MuscleGroup
    }

    private func rotated(_ slot: SkeletonSlot, client: Int32, dayNumber: Int, freshCast: Bool) -> [String] {
        // A fresh cast is a paid request for a different week, so it moves the
        // window itself rather than only the order inside it: where a slot's
        // best two train the same muscle the same way, reordering them alone
        // would leave the day unchanged.
        let pool = freshCast && slot.candidates.count > 1
            ? Array(slot.candidates.dropFirst()) + [slot.candidates[0]]
            : slot.candidates
        let best = Array(pool.prefix(Self.varietyDepth))
        guard best.count >= 2 else { return pool }
        // Hashed together rather than xored: xor leaves the choice riding on the
        // seed's lowest bits, so with two candidates every slot in the week
        // turned on one bit and there were only ever two weeks to go round.
        let offset = Int(Self.mixed(Self.hash("\(client):\(slot.id):\(dayNumber)")) % UInt32(best.count))
        return Array(best.dropFirst(offset)) + Array(best.prefix(offset)) + Array(pool.dropFirst(Self.varietyDepth))
    }

    // Who the client is, not how long they have. Session length and day count
    // reshape the week on their own; letting them move the seed as well would
    // mean answering "90 minutes" reshuffled every movement, and a longer
    // answer could then buy a shorter session.
    private func seed(of request: PlanRequest) -> Int32 {
        let user = request.user
        var answers = [
            user.id.uuidString,
            String(user.age),
            String(Int((user.weight * 10).rounded())),
            user.gender.rawValue,
            user.fitnessGoal.rawValue,
            user.experienceLevel.rawValue,
            user.availableEquipment.map(\.rawValue).sorted().joined(separator: ","),
            user.injuries.map(\.rawValue).sorted().joined(separator: ",")
        ].joined(separator: ";")
        if request.freshCast { answers += ";again:\(request.weekNumber)" }
        return Self.hash(answers)
    }

    // FNV-1a over the same code units the Android app hashes, so both apps
    // rotate identically. Swift's own string hashing is seeded per process.
    // FNV-1a's low bits are a parity of the input's low bits, so a modulo read
    // straight off them turned every slot in the week on one bit and forty
    // clients shared two weeks. Murmur's finalizer spreads the high bits down.
    private static func mixed(_ hashed: Int32) -> UInt32 {
        var bits = UInt32(bitPattern: hashed)
        bits ^= bits >> 16; bits &*= 0x85ebca6b
        bits ^= bits >> 13; bits &*= 0xc2b2ae35
        return bits ^ (bits >> 16)
    }

    private static func hash(_ text: String) -> Int32 {
        var hashed = fnvOffset
        for unit in text.utf16 { hashed = (hashed ^ Int32(unit)) &* fnvPrime }
        return hashed
    }
}
