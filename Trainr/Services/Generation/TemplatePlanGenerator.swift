import Foundation

// A whole week from the catalog: the skeleton, a movement for every slot, and
// the engine's numbers.
struct TemplatePlanGenerator: PlanGenerator {

    private let catalog: any ExerciseCatalog
    private let builder: PlanSkeletonBuilder
    private let assembler: PlanAssembler

    // Two candidates, not three: measured against the volume and frequency
    // the evidence asks for, going deeper spread a week's sets thinner
    // without buying any more variety worth having.
    private static let varietyDepth = 2
    private static let fnvOffset: Int32 = -2_128_831_035
    private static let fnvPrime: Int32 = 16_777_619

    init(catalog: any ExerciseCatalog = BundleExerciseCatalog()) {
        self.catalog = catalog
        builder = PlanSkeletonBuilder(catalog: catalog)
        assembler = PlanAssembler(catalog: catalog)
    }

    func generate(_ request: PlanRequest) async -> PlanGenerationResult {
        guard !catalog.all.isEmpty else { return .failed }
        let skeleton = builder.build(request)
        guard skeleton.isComplete else { return .failed }
        return assembler.assemble(skeleton, selection: choose(skeleton, request), request: request)
            .map { PlanGenerationResult.generated($0) } ?? .failed
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
        let offset = Int(UInt32(bitPattern: Self.hash("\(client):\(slot.id):\(dayNumber)")) % UInt32(best.count))
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
    private static func hash(_ text: String) -> Int32 {
        var h = fnvOffset
        for unit in text.utf16 { h = (h ^ Int32(unit)) &* fnvPrime }
        return h
    }
}
