import Foundation

// The shape of a week before anything picks a movement: which days, what each
// session is for, how many movements, in what order, with how many sets and
// what rest, and which movements could fill each place. A model then only
// chooses among a handful of keys per slot, and with no model at all the top
// of each list is already a week a coach would sign.
nonisolated final class PlanSkeletonBuilder: Sendable {

    static let maxCandidates = 8

    private let catalog: any ExerciseCatalog

    init(catalog: any ExerciseCatalog) {
        self.catalog = catalog
    }

    func build(_ request: PlanRequest) -> PlanSkeleton {
        let user = request.user
        let owned = Set(user.availableEquipment.isEmpty ? [Equipment.none] : user.availableEquipment)
        let pool = catalog.available(with: owned)
            .filter { !InjuryGuard.excludes($0, for: user.injuries) }
            .sorted { $0.key < $1.key }
        let required = ExerciseShortlist.requiredPatterns(pool, goal: user.fitnessGoal)
        let lastWeek = Set(request.previousWeek?.workoutDays.flatMap { $0.exercises.map(\.exerciseKey) } ?? [])

        let week = WeekBuilder(catalog: catalog, user: user, pool: pool, lastWeek: lastWeek)
        let days = Self.split(user).enumerated().map { index, entry in
            week.wishList(dayNumber: entry.0, focus: entry.1, index: index)
        }
        var uncovered = week.deal(required, into: days)
        let built = days.map { week.fit($0, uncovered: &uncovered) }

        return PlanSkeleton(
            title: Self.title(for: user),
            days: built,
            units: user.weightUnits,
            maxSetsPerSession: SessionBudget.maxSetsPerSession(user),
            sessionCeilingMinutes: SessionBudget.sessionCeilingMinutes(user),
            weeklySetsByRegion: week.setsByRegion(built),
            uncoveredPatterns: uncovered
        )
    }

    private static func split(_ user: UserProfile) -> [(Int, SessionFocus)] {
        let days = min(max(user.workoutDaysPerWeek, 1), 7)
        let numbers = dayNumbers[days] ?? [1]
        if user.fitnessGoal == .flexibility { return numbers.map { ($0, .mobilityFlow) } }
        return Array(zip(numbers, splits[days] ?? [.fullBody]))
    }

    private static func title(for user: UserProfile) -> String {
        let level = switch user.experienceLevel {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        }
        let aim = switch user.fitnessGoal {
        case .strength: "Strength"
        case .muscleGain: "Muscle Building"
        case .generalFitness: "General Fitness"
        case .weightLoss: "Weight Loss"
        case .endurance: "Endurance"
        case .flexibility: "Mobility"
        }
        return "\(level) \(aim)"
    }

    // Five hard days never three in a row inside the week.
    private static let dayNumbers: [Int: [Int]] = [
        1: [1], 2: [1, 4], 3: [1, 3, 5], 4: [1, 2, 4, 5], 5: [1, 2, 4, 5, 7],
        6: [1, 2, 3, 4, 5, 6], 7: Array(1...7),
    ]

    private static let splits: [Int: [SessionFocus]] = [
        1: [.fullBody], 2: [.fullBody, .fullBody], 3: [.fullBody, .fullBody, .fullBody],
        4: [.upper, .lower, .upper, .lower],
        5: [.push, .pull, .legs, .upper, .lower],
        6: [.push, .pull, .legs, .push, .pull, .legs],
        7: [.push, .pull, .legs, .activeRecovery, .upper, .lower, .activeRecovery],
    ]
}

private nonisolated final class Draft {
    let tier: SlotTier
    let id: String
    var patterns: [MovementPattern]
    let scope: Set<MuscleGroup>
    let minSets: Int
    let preferredSets: Int
    var muscles: Set<MuscleGroup>
    var required: PatternRequirement?
    var candidates: [String] = []
    var sets: Int
    var conditioningSeconds = 0

    init(tier: SlotTier, id: String, patterns: [MovementPattern], scope: Set<MuscleGroup>,
         minSets: Int, preferredSets: Int) {
        self.tier = tier
        self.id = id
        self.patterns = patterns
        self.scope = scope
        self.minSets = minSets
        self.preferredSets = preferredSets
        muscles = scope
        sets = minSets
    }

    var isDroppable: Bool { tier != .warmUp && tier != .primaryCompound && required == nil }

    // Compounds pick first so isolation can see what the day already trains;
    // the warm-up and cool-down draw last from what is left.
    var fillOrder: Int {
        switch tier {
        case .primaryCompound, .secondaryCompound, .accessory: 0
        case .warmUp: 1
        case .isolation, .core, .conditioning: 2
        case .mobility: 3
        }
    }
}

private nonisolated final class DayDraft {
    let dayNumber: Int
    let focus: SessionFocus
    var slots: [Draft]

    init(dayNumber: Int, focus: SessionFocus, slots: [Draft]) {
        self.dayNumber = dayNumber
        self.focus = focus
        self.slots = slots
    }
}

private nonisolated struct Shape {
    let count: Int
    let sets: [SlotTier: (Int, Int)]
    let drop: [String]
    // Weight loss and endurance take the rest of the session as conditioning;
    // every other goal takes a short fixed block.
    var conditioningFillsTheSession = false
}

private nonisolated final class WeekBuilder {
    private let catalog: any ExerciseCatalog
    private let user: UserProfile
    private let pool: [CatalogExercise]
    private let lastWeek: Set<String>
    private let shape: Shape
    private let maxSets: Int
    private let ceiling: Int
    private let conditioningDays: Set<Int>
    private var usesThisWeek: [String: Int] = [:]
    private var directSets: [MuscleRegion: Int] = [:]

    init(catalog: any ExerciseCatalog, user: UserProfile, pool: [CatalogExercise], lastWeek: Set<String>) {
        self.catalog = catalog
        self.user = user
        self.pool = pool
        self.lastWeek = lastWeek
        shape = Self.shape(for: user.fitnessGoal)
        maxSets = SessionBudget.maxSetsPerSession(user)
        ceiling = SessionBudget.sessionCeilingMinutes(user)
        conditioningDays = Self.conditioningDayIndexes(user.fitnessGoal, min(max(user.workoutDaysPerWeek, 1), 7))
    }

    func wishList(dayNumber: Int, focus: SessionFocus, index: Int) -> DayDraft {
        let scope = Self.scope(of: focus)
        var counts: [SlotTier: Int] = [:]
        let drafts = Self.wishList(for: focus).compactMap { tier -> Draft? in
            if tier == .conditioning && focus.isHard && !conditioningDays.contains(index) { return nil }
            guard let sets = shape.sets[tier] ?? (focus.isHard ? nil : (1, 1)) else { return nil }
            let instance = (counts[tier] ?? 0) + 1
            counts[tier] = instance
            let draft = Draft(
                tier: tier, id: Self.id(of: tier, instance), patterns: Self.family(of: focus, tier),
                scope: tier == .core ? Self.allMuscles : scope, minSets: sets.0, preferredSets: sets.1
            )
            draft.conditioningSeconds = shape.conditioningFillsTheSession
                ? Self.conditioningFloorSeconds
                : SeedLoad.conditioningSeconds(user)
            return draft
        }
        return DayDraft(dayNumber: dayNumber, focus: focus, slots: drafts)
    }

    // Each weekly requirement goes to the earliest compound slot that can
    // actually deliver it. Push and pull live in the secondary and accessory
    // slots of a full-body day, not the primary, so dealing only to primaries
    // would leave every full-body week without a press.
    func deal(_ required: Set<PatternRequirement>, into days: [DayDraft]) -> Set<PatternRequirement> {
        var uncovered: Set<PatternRequirement> = []
        for requirement in PatternRequirement.allCases where required.contains(requirement) {
            var home: Draft?
            outer: for day in days {
                for slot in day.slots where slot.tier.isCompound && slot.required == nil {
                    let scope = Self.scope(of: day.focus)
                    if slot.patterns.contains(where: { requirement.isMet(by: $0) && hasAny($0, in: scope) }) {
                        home = slot
                        break outer
                    }
                }
            }
            if let home {
                home.required = requirement
                home.patterns = home.patterns.filter { requirement.isMet(by: $0) }
            } else {
                uncovered.insert(requirement)
            }
        }
        return uncovered
    }

    func fit(_ day: DayDraft, uncovered: inout Set<PatternRequirement>) -> SkeletonDay {
        let drop = day.focus == .activeRecovery ? ["mobility_2", "core"] : shape.drop
        trimToCount(day, drop)
        fillCandidates(day, uncovered: &uncovered)
        fitMinimums(day, drop)
        topUp(day)
        for slot in day.slots {
            if let key = slot.candidates.first { countDirect(key, slot.sets) }
        }
        return SkeletonDay(
            dayNumber: day.dayNumber, focus: day.focus,
            slots: day.slots.sorted { $0.tier < $1.tier }.map(slot(from:))
        )
    }

    func setsByRegion(_ days: [SkeletonDay]) -> [MuscleRegion: Double] {
        var totals: [MuscleRegion: Double] = [:]
        for slot in days.flatMap(\.slots) {
            guard let key = slot.candidates.first, let top = catalog[key] else { continue }
            if top.primary.region.isTrainable { totals[top.primary.region, default: 0] += Double(slot.sets) }
            var seen: Set<MuscleRegion> = [top.primary.region]
            for region in top.secondary.map(\.region) where region.isTrainable && !seen.contains(region) {
                seen.insert(region)
                totals[region, default: 0] += Double(slot.sets) * 0.5
            }
        }
        return totals
    }

    private func trimToCount(_ day: DayDraft, _ drop: [String]) {
        for id in drop where day.slots.count > shape.count {
            day.slots.removeAll { $0.id == id && $0.isDroppable }
        }
    }

    private func fillCandidates(_ day: DayDraft, uncovered: inout Set<PatternRequirement>) {
        var takenToday: Set<String> = []
        var patternsToday: Set<MovementPattern> = []
        let order = day.slots.sorted { ($0.fillOrder, $0.tier.rawValue) < ($1.fillOrder, $1.tier.rawValue) }
        for slot in order {
            if slot.tier == .isolation { slot.muscles = isolationMuscles(for: day, takenToday: takenToday) }
            // Variety is for lifting. There are five mobility movements in the
            // catalog and a flexibility day uses four, so capping their weekly
            // uses would leave the sixth day with nothing, and stretching every
            // day is simply normal.
            let eligible = pool.filter {
                !takenToday.contains($0.key)
                    && (slot.tier.isTimed || (usesThisWeek[$0.key] ?? 0) < Self.maxWeeklyUses)
            }
            var matched: [CatalogExercise] = []
            if slot.tier.isCompound {
                for pattern in slot.patterns where !patternsToday.contains(pattern) {
                    let found = eligible.filter { fits($0, slot) && $0.pattern == pattern }
                    if !found.isEmpty {
                        matched = found
                        slot.patterns = [pattern]
                        break
                    }
                }
            } else {
                matched = eligible.filter { fits($0, slot) }
            }
            let sharing = order.filter { $0.tier == slot.tier && $0.candidates.isEmpty }.count
            let share = slot.tier == .warmUp
                ? 1
                : max(1, min(PlanSkeletonBuilder.maxCandidates, matched.count / max(1, sharing)))
            slot.candidates = Array(matched.sorted { ranked($0, $1, slot) }.prefix(share).map(\.key))
            guard let top = slot.candidates.first else {
                if let required = slot.required { uncovered.insert(required) }
                continue
            }
            takenToday.formUnion(slot.candidates)
            if slot.tier.isCompound { patternsToday.formUnion(slot.patterns) }
            usesThisWeek[top, default: 0] += 1
        }
        day.slots.removeAll { $0.candidates.isEmpty }
    }

    // Pass B: the minimums have to fit before anything is topped up.
    private func fitMinimums(_ day: DayDraft, _ drop: [String]) {
        for id in drop where !fits(day) {
            day.slots.removeAll { $0.id == id && $0.isDroppable }
        }
        while !fits(day) {
            let shrink = day.slots.filter { $0.sets > 1 }
                .sorted { ($0.tier.isCompound ? 0 : 1, -$0.tier.rawValue) < ($1.tier.isCompound ? 0 : 1, -$1.tier.rawValue) }
                .first
            guard let shrink else { break }
            shrink.sets -= 1
        }
    }

    // Pass C, aimed at the session the client asked for rather than the
    // ceiling above it: every slot to its preferred sets first, then a little
    // more where a long session has room, then the rest of a weight-loss
    // session to conditioning. Extra sets go to the first movements of the
    // day, the same fatigue rule as the order itself.
    private func topUp(_ day: DayDraft) {
        grow(day) { $0.preferredSets }
        grow(day) { $0.tier.isTimed && $0.tier != .mobility ? $0.preferredSets : $0.preferredSets + Self.stretchSets }
        if shape.conditioningFillsTheSession { fillWithConditioning(day) }
    }

    private func grow(_ day: DayDraft, limit: (Draft) -> Int) {
        var grew = true
        while grew {
            grew = false
            for slot in day.slots.sorted(by: { $0.tier < $1.tier }) {
                guard slot.sets < min(limit(slot), Self.maxSetsPerSlot) else { continue }
                slot.sets += 1
                if fits(day) && isWithinTheAnswer(day) { grew = true } else { slot.sets -= 1 }
            }
        }
    }

    private func fillWithConditioning(_ day: DayDraft) {
        guard let block = day.slots.first(where: { $0.tier == .conditioning }) else { return }
        while block.conditioningSeconds + Self.conditioningStepSeconds <= Self.conditioningCeilingSeconds {
            block.conditioningSeconds += Self.conditioningStepSeconds
            if !fits(day) || !isWithinTheAnswer(day) {
                block.conditioningSeconds -= Self.conditioningStepSeconds
                return
            }
        }
    }

    // The hard limit: never more sets than the session pays for, and never
    // past its ceiling even at the top of every rep window, so no week of the
    // ladder can break it.
    private func fits(_ day: DayDraft) -> Bool {
        day.slots.reduce(0) { $0 + $1.sets } <= maxSets
            && SessionMinutes.forDay(day.slots.map { minutes(of: $0, atTop: true) }) <= ceiling
    }

    // The aim: about as long as the answer, priced at the reps a set is
    // typically done at rather than the most it could ever ask.
    private func isWithinTheAnswer(_ day: DayDraft) -> Bool {
        SessionMinutes.forDay(day.slots.map { minutes(of: $0, atTop: false) }) <= user.workoutDuration
    }

    private func minutes(of slot: Draft, atTop: Bool) -> Int {
        guard let key = slot.candidates.first, let top = catalog[key] else { return 0 }
        if top.measure == .duration {
            return SessionMinutes.forExercise(
                measure: .duration, perSet: Array(repeating: seconds(for: slot, top), count: slot.sets),
                restSeconds: rest(for: slot)
            )
        }
        let window = RepWindow.forExercise(user, top)
        let reps = atTop ? window.upperBound : min(window.lowerBound + Self.typicalRepClimb, window.upperBound)
        return SessionMinutes.forExercise(
            measure: top.measure, perSet: Array(repeating: reps, count: slot.sets),
            restSeconds: rest(for: slot), unilateral: top.unilateral
        )
    }

    private func seconds(for slot: Draft, _ top: CatalogExercise) -> Int {
        switch slot.tier {
        case .warmUp: top.key == Self.warmUpKey ? SeedLoad.warmUpSeconds : SeedLoad.mobilitySeconds
        case .mobility: SeedLoad.mobilitySeconds
        case .conditioning: slot.conditioningSeconds
        default: Self.holdBudgetSeconds
        }
    }

    private func rest(for slot: Draft) -> Int {
        if slot.tier.isCompound { return SessionBudget.restSeconds(for: user.fitnessGoal, role: .compound) }
        if slot.tier.isTimed { return SessionBudget.restSeconds(for: user.fitnessGoal, role: .timed) }
        return SessionBudget.restSeconds(for: user.fitnessGoal, role: .isolation)
    }

    // Isolation goes where the week has had the least direct work. Counted
    // direct only: assists would let arms look trained from rows alone while
    // calves, which nothing assists, took every slot.
    private func isolationMuscles(for day: DayDraft, takenToday: Set<String>) -> Set<MuscleGroup> {
        let scope = Self.scope(of: day.focus)
        var regions: [MuscleRegion] = []
        for exercise in pool where exercise.pattern == .isolation && scope.contains(exercise.primary)
            && !takenToday.contains(exercise.key) && exercise.primary.region.isTrainable
            && exercise.primary.region != .core && !regions.contains(exercise.primary.region) {
            regions.append(exercise.primary.region)
        }
        let order = MuscleRegion.allCases
        guard let region = regions.min(by: {
            ((directSets[$0] ?? 0), order.firstIndex(of: $0) ?? 0) < ((directSets[$1] ?? 0), order.firstIndex(of: $1) ?? 0)
        }) else { return scope }
        return scope.filter { $0.region == region }
    }

    private func ranked(_ lhs: CatalogExercise, _ rhs: CatalogExercise, _ slot: Draft) -> Bool {
        let left = rank(lhs, slot)
        let right = rank(rhs, slot)
        return left == right ? lhs.key < rhs.key : left.lexicographicallyPrecedes(right)
    }

    private func rank(_ exercise: CatalogExercise, _ slot: Draft) -> [Int] {
        let used = (usesThisWeek[exercise.key] ?? 0) > 0
        return [
            slot.tier == .warmUp && exercise.key == Self.warmUpKey ? 0 : 1,
            lastWeek.contains(exercise.key) ? 0 : 1,
            slot.required?.isMet(by: exercise.pattern) == true ? 0 : 1,
            exercise.staple ? 0 : 1,
            slot.tier.isCompound == used ? 0 : 1,
            directSets[exercise.primary.region] ?? 0,
        ]
    }

    private func fits(_ exercise: CatalogExercise, _ slot: Draft) -> Bool {
        switch slot.tier {
        case .warmUp, .mobility: exercise.pattern == .mobility
        case .conditioning: exercise.primary == .cardio && exercise.measure == .duration
        case .core: exercise.pattern == .core
        case .isolation:
            exercise.pattern == .isolation && slot.muscles.contains(exercise.primary)
                && exercise.measure != .duration
        default:
            slot.patterns.contains(exercise.pattern) && slot.scope.contains(exercise.primary)
                && exercise.measure != .duration
        }
    }

    private func hasAny(_ pattern: MovementPattern, in scope: Set<MuscleGroup>) -> Bool {
        pool.contains { $0.pattern == pattern && scope.contains($0.primary) && $0.measure != .duration }
    }

    private func countDirect(_ key: String, _ sets: Int) {
        guard let region = catalog[key]?.primary.region, region.isTrainable else { return }
        directSets[region, default: 0] += sets
    }

    private func slot(from draft: Draft) -> SkeletonSlot {
        let top = draft.candidates.first.flatMap { catalog[$0] }
        return SkeletonSlot(
            id: draft.id, label: Self.label(of: draft.tier), tier: draft.tier, patterns: draft.patterns,
            muscles: draft.muscles, candidates: draft.candidates, sets: draft.sets,
            restSeconds: rest(for: draft),
            secondsPerSet: top.flatMap { $0.measure == .duration ? seconds(for: draft, $0) : nil },
            required: draft.required
        )
    }

    // How many of the week's days carry a conditioning block, spread across the
    // week rather than bunched at its start. A weight-loss week needs its
    // minutes every day; a strength week needs them once and short, since
    // conditioning next to heavy legs blunts the lifting (Wilson 2012).
    private static func conditioningDayIndexes(_ goal: FitnessGoal, _ days: Int) -> Set<Int> {
        let wanted: Int = switch goal {
        case .strength, .flexibility: 1
        case .muscleGain: 2
        case .generalFitness: 3
        case .weightLoss, .endurance: days
        }
        let count = min(wanted, days)
        return Set((0..<count).map { $0 * days / count })
    }

    // A strength day sheds breadth to keep depth, a weight-loss day sheds the
    // lifting tail to keep its conditioning, and a flexibility day has no
    // compound slots at all.
    private static func shape(for goal: FitnessGoal) -> Shape {
        switch goal {
        case .strength:
            Shape(count: 6, sets: [
                .warmUp: (1, 1), .primaryCompound: (3, 5), .secondaryCompound: (2, 4), .accessory: (2, 3),
                .isolation: (2, 2), .core: (1, 2), .conditioning: (1, 1),
            ], drop: ["isolation_2", "conditioning", "mobility_1", "accessory", "core", "isolation_1"])
        case .muscleGain:
            Shape(count: 8, sets: [
                .warmUp: (1, 1), .primaryCompound: (2, 4), .secondaryCompound: (2, 3), .accessory: (2, 3),
                .isolation: (2, 3), .core: (1, 3), .conditioning: (1, 1), .mobility: (1, 1),
            ], drop: ["mobility_1", "conditioning", "isolation_2", "core", "accessory", "isolation_1"])
        case .generalFitness:
            Shape(count: 8, sets: [
                .warmUp: (1, 1), .primaryCompound: (2, 3), .secondaryCompound: (2, 3), .accessory: (2, 3),
                .isolation: (2, 3), .core: (1, 3), .conditioning: (1, 1), .mobility: (1, 1),
            ], drop: ["mobility_1", "isolation_2", "isolation_1", "core", "conditioning", "accessory"])
        case .weightLoss, .endurance:
            Shape(count: 7, sets: [
                .warmUp: (1, 1), .primaryCompound: (2, 3), .secondaryCompound: (2, 3), .accessory: (2, 3),
                .isolation: (2, 2), .core: (2, 3), .conditioning: (1, 1), .mobility: (1, 1),
            ], drop: ["isolation_2", "isolation_1", "accessory", "mobility_1", "secondary", "core"],
            conditioningFillsTheSession: true)
        case .flexibility:
            Shape(count: 6, sets: [
                .warmUp: (1, 1), .core: (1, 2), .conditioning: (1, 1), .mobility: (3, 4),
            ], drop: ["core", "conditioning", "mobility_4", "mobility_3"])
        }
    }

    private static func wishList(for focus: SessionFocus) -> [SlotTier] {
        switch focus {
        case .fullBody:
            [.warmUp, .primaryCompound, .secondaryCompound, .accessory, .isolation, .core, .conditioning, .mobility]
        case .activeRecovery:
            [.warmUp, .core, .conditioning, .mobility, .mobility]
        case .mobilityFlow:
            [.warmUp, .core, .mobility, .mobility, .mobility, .conditioning]
        default:
            [.warmUp, .primaryCompound, .secondaryCompound, .accessory, .isolation, .isolation,
             .core, .conditioning, .mobility]
        }
    }

    private static let allMuscles = Set(MuscleGroup.allCases)

    private static func scope(of focus: SessionFocus) -> Set<MuscleGroup> {
        switch focus {
        case .upper: [.chest, .lats, .upperBack, .traps, .shoulders, .biceps, .triceps, .forearms]
        case .lower, .legs: [.quadriceps, .hamstrings, .glutes, .abductors, .adductors, .calves]
        case .push: [.chest, .shoulders, .triceps]
        case .pull: [.lats, .upperBack, .traps, .biceps, .forearms, .shoulders]
        default: allMuscles
        }
    }

    // Preference-ordered, walked until one has movements; a day never repeats a
    // pattern across its compound slots.
    private static func family(of focus: SessionFocus, _ tier: SlotTier) -> [MovementPattern] {
        guard tier.isCompound else { return [] }
        let families: [[MovementPattern]] = switch focus {
        case .fullBody: [[.squat, .hinge, .lunge], [.horizontalPush, .verticalPush], [.horizontalPull, .verticalPull]]
        case .upper: [[.horizontalPush, .verticalPush], [.verticalPull, .horizontalPull],
                      [.verticalPush, .horizontalPull, .horizontalPush]]
        case .lower: [[.squat, .hinge], [.hinge, .squat], [.lunge, .squat, .hinge]]
        case .push: [[.horizontalPush], [.verticalPush], [.horizontalPush, .verticalPush]]
        case .pull: [[.verticalPull, .horizontalPull], [.horizontalPull, .verticalPull], [.hinge, .horizontalPull]]
        case .legs: [[.squat], [.hinge], [.lunge, .squat, .hinge]]
        default: []
        }
        let index = tier.rawValue - SlotTier.primaryCompound.rawValue
        return families.indices.contains(index) ? families[index] : []
    }

    private static func id(of tier: SlotTier, _ instance: Int) -> String {
        switch tier {
        case .warmUp: "warm_up"
        case .primaryCompound: "primary"
        case .secondaryCompound: "secondary"
        case .accessory: "accessory"
        case .isolation: "isolation_\(instance)"
        case .core: "core"
        case .conditioning: "conditioning"
        case .mobility: "mobility_\(instance)"
        }
    }

    private static func label(of tier: SlotTier) -> String {
        switch tier {
        case .warmUp: "the warm-up"
        case .primaryCompound: "the main lift"
        case .secondaryCompound: "the second lift"
        case .accessory: "the accessory lift"
        case .isolation: "an isolation movement"
        case .core: "the core movement"
        case .conditioning: "the conditioning"
        case .mobility: "the cool-down"
        }
    }

    private static let maxWeeklyUses = 3
    private static let maxSetsPerSlot = 10
    private static let holdBudgetSeconds = 90
    private static let stretchSets = 2
    private static let typicalRepClimb = 2
    private static let conditioningFloorSeconds = 300
    private static let conditioningStepSeconds = 60
    private static let conditioningCeilingSeconds = 3600
    private static let warmUpKey = "warm_up"
}
