import Foundation

nonisolated struct ProgressionRequest: Sendable {
    var user: UserProfile
    var exercise: CatalogExercise
    var history = ExerciseHistory.empty
    // From the skeleton. The engine may return fewer, never more.
    var sets: Int
    // Passed in, never read from the clock: a domain object that reads the
    // clock cannot be tested and cannot be replayed.
    var now: Date?
    var deload = false
    // The movement touches an injury the client declared.
    var cautioned = false
    // What the day budgeted for a timed set. Conditioning starts there, so the
    // block the session was fitted around is the block prescribed.
    var secondsBudget: Int?
}

nonisolated struct ProgressionTarget: Equatable, Sendable {
    var sets: [ExerciseSet]
    // A guess the client's first session will correct, and the card says so.
    var isEstimate = false
    var outcome: ProgressionOutcome
    var notes: Set<ProgressionNote> = []
    var stallCount = 0
}

nonisolated enum ProgressionOutcome: Sendable {
    case calibrated, reseeded, repeated, held, loadAdded, repsAdded
    case secondsAdded, reduced, reAnchored, rampedBack, deloaded
}

// Asks for a different movement rather than lying about this one: the
// lightest barbell is still 20 kg, and a hold past ninety seconds is a
// different exercise, not a harder one.
nonisolated enum ProgressionNote: Hashable, Sendable {
    case needsHarderVariation, lighterThanTheBar
}

// Next week's targets from what the client actually did. The default tick-off
// logs exactly the target, so progression has to key off hitting it, not
// beating it.
nonisolated enum ProgressionEngine {

    static func next(_ request: ProgressionRequest) -> ProgressionTarget {
        let week = Week(request)
        switch request.exercise.measure {
        case .weightAndReps: return week.loaded()
        case .reps: return week.bodyweight()
        case .duration: return week.timed()
        }
    }
}

private nonisolated struct Week {
    let request: ProgressionRequest
    let user: UserProfile
    let exercise: CatalogExercise
    let units: UnitSystem
    let window: ClosedRange<Int>
    let askedSets: Int
    let sessions: [LoggedSession]
    let usable: [LoggedSession]
    let last: LoggedSession?
    let step: Double
    let gapDays: Int

    init(_ request: ProgressionRequest) {
        self.request = request
        user = request.user
        exercise = request.exercise
        units = request.user.weightUnits
        window = RepWindow.forExercise(request.user, request.exercise)
        askedSets = max(request.sets, 1)
        sessions = request.history.sessions
        let usable = request.history.sessions.filter { $0.isUsable(for: request.exercise.measure) }
        self.usable = usable
        last = usable.first
        let base = RepWindow.loadStepFraction(request.user, request.exercise)
        step = request.cautioned ? min(base, Self.cautiousStep) : base
        if let performed = usable.first?.performedAt, let now = request.now {
            gapDays = max(0, Int(now.timeIntervalSince(performed) / Self.secondsPerDay))
        } else {
            gapDays = 0
        }
    }

    func loaded() -> ProgressionTarget {
        if sessions.isEmpty { return calibrateLoaded() }
        guard let done = last else { return repeatUnperformed(sessions[0]) }
        guard let recorded = done.targetLoadKg else { return calibrateLoaded() }
        let anchor = LoadStep.snap(recorded, for: exercise, units: units, how: .down)
        let lastReps = done.targetAmount ?? window.lowerBound

        if request.deload {
            return loadedTarget(lastReps, anchor, askedSets / 2, .deloaded, anchor: anchor)
        }
        if Self.longLayoff.contains(gapDays) {
            let seed = SeedLoad.loadKg(user, exercise, reps: window.lowerBound) ?? anchor
            return loadedTarget(
                window.lowerBound, snapDown(min(seed, anchor * Self.afterLongLayoff)),
                askedSets, .calibrated, estimate: true
            )
        }
        if Self.monthAway.contains(gapDays) {
            return loadedTarget(
                lastReps, snapDown(anchor * Self.afterMonthAway), askedSets - 1, .reduced, anchor: anchor
            )
        }
        if Self.fortnightAway.contains(gapDays) {
            return loadedTarget(lastReps, anchor, askedSets, .repeated, anchor: anchor)
        }
        if isRampingBack() {
            let ramped = max(
                LoadStep.snap(anchor * Self.rampBack, for: exercise, units: units),
                LoadStep.nextUp(anchor, for: exercise, units: units)
            )
            return loadedTarget(lastReps, ramped, askedSets, .rampedBack, anchor: anchor)
        }
        if let range = done.targetAmountRange,
           range.upperBound < window.lowerBound || range.lowerBound > window.upperBound {
            return loadedTarget(
                window.lowerBound, reAnchor(anchor, done.minDone), askedSets, .reAnchored, estimate: true
            )
        }
        if !done.hasQuorum {
            return loadedTarget(lastReps, anchor, askedSets, .repeated, anchor: anchor)
        }
        if usable.count == 1 && !window.contains(done.minDone) {
            return loadedTarget(
                window.lowerBound, reseed(anchor, done.minDone, lastReps), askedSets,
                .reseeded, estimate: true
            )
        }
        if done.metInFull {
            if ladder(anchor) >= ladderTop(anchor) {
                let added = max(
                    LoadStep.snap(anchor * (1 + step), for: exercise, units: units),
                    LoadStep.nextUp(anchor, for: exercise, units: units)
                )
                return loadedTarget(window.lowerBound, added, askedSets, .loadAdded, anchor: anchor)
            }
            return loadedTarget(
                min(lastReps + 1, window.upperBound), anchor, askedSets, .held, anchor: anchor
            )
        }
        if done.isShortByALittle {
            return loadedTarget(lastReps, anchor, askedSets, .repeated, anchor: anchor)
        }
        return loadedTarget(
            window.lowerBound, snapDown(anchor * Self.afterStall), askedSets, .reduced,
            anchor: anchor, stall: request.history.stallCount
        )
    }

    func bodyweight() -> ProgressionTarget {
        let first = user.experienceLevel == .beginner && exercise.role == .compound
            ? min(window.lowerBound, Self.beginnerBodyweightReps)
            : window.lowerBound

        if sessions.isEmpty { return repsTarget(first, askedSets, .calibrated, estimate: true) }
        guard let done = last else {
            return repsTarget(sessions[0].targetAmount ?? first, askedSets, .repeated, estimate: true)
        }
        let lastReps = done.targetAmount ?? first
        if request.deload { return repsTarget(lastReps, askedSets / 2, .deloaded) }
        if Self.longLayoff.contains(gapDays) {
            return repsTarget(first, askedSets, .calibrated, estimate: true)
        }
        if Self.monthAway.contains(gapDays) { return repsTarget(lastReps, askedSets - 1, .reduced) }
        if Self.fortnightAway.contains(gapDays) || !done.hasQuorum {
            return repsTarget(lastReps, askedSets, .repeated)
        }
        if done.metInFull && lastReps >= window.upperBound {
            return repsTarget(lastReps, askedSets, .held, notes: [.needsHarderVariation])
        }
        if done.metInFull { return repsTarget(lastReps + 1, askedSets, .repsAdded) }
        return repsTarget(max(first, done.minDone), askedSets, .reduced)
    }

    func timed() -> ProgressionTarget {
        // A warm-up that grows five seconds a week is thirteen minutes of
        // warm-up in a year.
        if exercise.pattern == .mobility {
            let seconds = exercise.key == Self.warmUpKey ? SeedLoad.warmUpSeconds : SeedLoad.mobilitySeconds
            return secondsTarget(seconds, askedSets, sessions.isEmpty ? .calibrated : .held)
        }
        let conditioning = exercise.primary == .cardio
        let seed = conditioning
            ? (request.secondsBudget ?? SeedLoad.conditioningSeconds(user))
            : SeedLoad.holdSeconds(user)

        if sessions.isEmpty { return secondsTarget(seed, askedSets, .calibrated, estimate: true) }
        guard let done = last else {
            return secondsTarget(sessions[0].targetAmount ?? seed, askedSets, .repeated, estimate: true)
        }
        let lastSeconds = done.targetAmount ?? seed
        if request.deload { return secondsTarget(lastSeconds, askedSets / 2, .deloaded) }
        if Self.longLayoff.contains(gapDays) {
            return secondsTarget(seed, askedSets, .calibrated, estimate: true)
        }
        if Self.monthAway.contains(gapDays) { return secondsTarget(lastSeconds, askedSets - 1, .reduced) }
        if Self.fortnightAway.contains(gapDays) || !done.hasQuorum {
            return secondsTarget(lastSeconds, askedSets, .repeated)
        }
        return conditioning ? conditioningWeek(done, lastSeconds) : holdWeek(done, lastSeconds)
    }

    // Conditioning is missed for reasons that are rarely about capacity, so a
    // short week is repeated rather than cut.
    private func conditioningWeek(_ done: LoggedSession, _ lastSeconds: Int) -> ProgressionTarget {
        guard done.metInFull else { return secondsTarget(lastSeconds, askedSets, .repeated) }
        let grown = Int((Double(lastSeconds) * Self.conditioningGrowth / Double(Self.conditioningGranularity))
            .rounded()) * Self.conditioningGranularity
        let next = min(
            max(max(grown, lastSeconds + Self.minConditioningGain), Self.conditioningFloor),
            conditioningCeiling()
        )
        return secondsTarget(next, askedSets, .secondsAdded)
    }

    private func holdWeek(_ done: LoggedSession, _ lastSeconds: Int) -> ProgressionTarget {
        if done.metInFull {
            if lastSeconds >= Self.holdCeilingSeconds {
                return secondsTarget(lastSeconds, askedSets, .held, notes: [.needsHarderVariation])
            }
            return secondsTarget(
                min(lastSeconds + Self.holdStepSeconds, Self.holdCeilingSeconds), askedSets, .secondsAdded
            )
        }
        let shortTwice = usable.count >= 2 && usable.prefix(2).allSatisfy { !$0.metInFull }
        return shortTwice
            ? secondsTarget(max(lastSeconds - Self.holdCutSeconds, Self.holdFloorSeconds), askedSets, .reduced)
            : secondsTarget(lastSeconds, askedSets, .repeated)
    }

    private func calibrateLoaded() -> ProgressionTarget {
        let raw = SeedLoad.loadKg(user, exercise, reps: window.lowerBound)
        let lightest = LoadStep.lightest(exercise, units: units)
        var notes: Set<ProgressionNote> = []
        if exercise.equipment == .barbell, let raw, raw < lightest { notes.insert(.lighterThanTheBar) }
        return loadedTarget(
            window.lowerBound, raw.map(snapDown), askedSets, .calibrated, estimate: true, notes: notes
        )
    }

    // Prescribed and never done: there is nothing to judge, so the same targets
    // come back and stay marked as a guess.
    private func repeatUnperformed(_ latest: LoggedSession) -> ProgressionTarget {
        loadedTarget(
            latest.targetAmount ?? window.lowerBound, latest.targetLoadKg.map(snapDown),
            askedSets, .repeated, estimate: true
        )
    }

    // Consecutive most recent sessions at this same load that were met in full:
    // the rungs already climbed before the load moves.
    private func ladder(_ anchor: Double) -> Int {
        usable.prefix { session in
            guard session.metInFull, let load = session.targetLoadKg else { return false }
            return LoadStep.snap(load, for: exercise, units: units, how: .down) == anchor
        }.count
    }

    // Three rungs gives every goal a load change inside its own window. Where
    // the smallest increment is a big share of the load, more reps are banked
    // before taking it.
    private func ladderTop(_ anchor: Double) -> Int {
        let span = window.upperBound - window.lowerBound
        let coarse = LoadStep.stepFraction(of: anchor, for: exercise, units: units) > Self.coarseStep
        return min(coarse ? Self.coarseLadder : Self.ladder, span)
    }

    private func isRampingBack() -> Bool {
        (0...1).contains { index in
            guard index + 1 < usable.count,
                  let returned = usable[index].performedAt,
                  let before = usable[index + 1].performedAt
            else { return false }
            return Self.monthAway.contains(Int(returned.timeIntervalSince(before) / Self.secondsPerDay))
        }
    }

    private func reAnchor(_ anchor: Double, _ minDone: Int) -> Double {
        let oneRepMax = anchor * (1 + Double(min(minDone, Self.epleyCeiling)) / Self.epleyDivisor)
        let atFirst = oneRepMax / (1 + Double(min(window.lowerBound, Self.epleyCeiling)) / Self.epleyDivisor)
        return snapDown(min(max(atFirst, anchor * 0.75), anchor * 1.15))
    }

    private func reseed(_ anchor: Double, _ minDone: Int, _ targetReps: Int) -> Double {
        let scaled = anchor * Double(minDone + Self.reseedOffset) / Double(targetReps + Self.reseedOffset)
        return snapDown(min(max(scaled, anchor * 0.6), anchor * 1.5))
    }

    private func snapDown(_ kg: Double) -> Double {
        LoadStep.snap(kg, for: exercise, units: units, how: .down)
    }

    // No single week moves the load more than a fifth, so a garbage number in
    // history cannot become a garbage prescription. It never blocks a single
    // increment, though: on a light dumbbell one step is a quarter.
    private func bounded(_ kg: Double, _ anchor: Double) -> Double {
        let high = max(anchor * (1 + Self.maxWeeklyChange), LoadStep.nextUp(anchor, for: exercise, units: units))
        let low = min(anchor * (1 - Self.maxWeeklyChange), LoadStep.nextDown(anchor, for: exercise, units: units))
        if kg > high { return LoadStep.snap(high, for: exercise, units: units, how: .down) }
        if kg < low { return LoadStep.snap(low, for: exercise, units: units, how: .up) }
        return kg
    }

    private func loadedTarget(
        _ reps: Int,
        _ load: Double?,
        _ sets: Int,
        _ outcome: ProgressionOutcome,
        anchor: Double? = nil,
        estimate: Bool = false,
        notes: Set<ProgressionNote> = [],
        stall: Int = 0
    ) -> ProgressionTarget {
        let weight = load.map { raw -> Double in
            let kept = anchor.map { bounded(raw, $0) } ?? raw
            let floor = LoadStep.lightest(exercise, units: units)
            let ceiling = LoadStep.ceilingKg(exercise.equipment)
            return min(max(min(max(kept, floor), ceiling), Self.minWeightKg), Self.maxWeightKg)
        }
        return ProgressionTarget(
            sets: setNumbers(sets).map {
                ExerciseSet(setNumber: $0, targetReps: clamp(reps, Self.repBounds), targetWeightKg: weight)
            },
            isEstimate: estimate, outcome: outcome, notes: notes, stallCount: stall
        )
    }

    private func repsTarget(
        _ reps: Int, _ sets: Int, _ outcome: ProgressionOutcome,
        estimate: Bool = false, notes: Set<ProgressionNote> = []
    ) -> ProgressionTarget {
        ProgressionTarget(
            sets: setNumbers(sets).map { ExerciseSet(setNumber: $0, targetReps: clamp(reps, Self.repBounds)) },
            isEstimate: estimate, outcome: outcome, notes: notes
        )
    }

    private func secondsTarget(
        _ seconds: Int, _ sets: Int, _ outcome: ProgressionOutcome,
        estimate: Bool = false, notes: Set<ProgressionNote> = []
    ) -> ProgressionTarget {
        ProgressionTarget(
            sets: setNumbers(sets).map {
                ExerciseSet(setNumber: $0, targetSeconds: clamp(seconds, Self.secondBounds))
            },
            isEstimate: estimate, outcome: outcome, notes: notes
        )
    }

    // Never more sets than the skeleton paid for, so nothing downstream ever
    // has to trim.
    private func setNumbers(_ sets: Int) -> ClosedRange<Int> { 1...clamp(sets, 1...askedSets) }

    private func clamp(_ value: Int, _ range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private func conditioningCeiling() -> Int {
        switch user.fitnessGoal {
        case .weightLoss, .endurance: 3600
        case .generalFitness: 2400
        default: 1800
        }
    }

    private static let longLayoff = 43...Int.max
    private static let monthAway = 22...42
    private static let fortnightAway = 11...21
    private static let secondsPerDay = 86_400.0
    private static let warmUpKey = "warm_up"
    private static let cautiousStep = 0.025
    private static let afterLongLayoff = 0.70
    private static let afterMonthAway = 0.90
    private static let afterStall = 0.90
    private static let rampBack = 1.05
    private static let maxWeeklyChange = 0.20
    private static let coarseStep = 0.25
    private static let ladder = 2
    private static let coarseLadder = 5
    private static let reseedOffset = 5
    private static let epleyCeiling = 12
    private static let epleyDivisor = 30.0
    private static let beginnerBodyweightReps = 8
    private static let holdStepSeconds = 5
    private static let holdCeilingSeconds = 90
    private static let holdCutSeconds = 10
    private static let holdFloorSeconds = 20
    private static let conditioningGrowth = 1.10
    private static let conditioningGranularity = 30
    private static let minConditioningGain = 60
    private static let conditioningFloor = 300
    private static let repBounds = 1...100
    private static let secondBounds = 5...5400
    private static let minWeightKg = 0.5
    private static let maxWeightKg = 500.0
}
