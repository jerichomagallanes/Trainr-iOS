import Foundation

// duration, exerciseCount and equipment are generator outputs that applying an
// adjustment deliberately leaves alone, so undo can restore the day exactly.
// Everything shown is therefore derived from the sets that are still planned.
nonisolated extension WorkoutDay {

    // An omitted set stays in the record so undo can put it back, but it is not
    // part of today's session and nothing may count it.
    var visibleExercises: [WorkoutExercise] {
        exercises.filter { !$0.isOmittedToday }
    }

    var isAdjustedToday: Bool {
        exercises.contains { $0.addedBy != nil || $0.sets.contains { $0.omittedBy != nil } }
    }

    var derivedExerciseCount: Int {
        isAdjustedToday ? visibleExercises.count : exerciseCount
    }

    func derivedEquipment(_ catalog: any ExerciseCatalog) -> [String] {
        guard isAdjustedToday else { return equipment }
        var kit: [String] = []
        for item in visibleExercises.compactMap({ catalog[$0.exerciseKey]?.equipment })
            .filter({ $0 != Equipment.none })
            .map(\.catalogDisplayText) where !kit.contains(item) {
            kit.append(item)
        }
        return kit
    }

    func remainingMinutes(_ user: UserProfile, _ catalog: any ExerciseCatalog) -> Int {
        SessionEstimate.minutes(self, user: user, scope: .wholeSession, catalog: catalog)
    }
}

nonisolated struct AdjustedBannerUi: Equatable, Sendable {
    var kind: Kind
    var regions: [MuscleRegion] = []
    var fromName = ""
    var toName = ""

    nonisolated enum Kind: Equatable, Sendable {
        case lessWorkForRegions
        case reducedSession
        case replaced
    }

    var message: String {
        switch kind {
        case .lessWorkForRegions:
            L10n.adjustedTimeBannerFormat(UnstuckText.joinAnd(regions.map(\.displayName)))
        case .reducedSession: L10n.adjustedReducedBanner
        case .replaced: L10n.adjustedReplacedBannerFormat(fromName, toName)
        }
    }
}
