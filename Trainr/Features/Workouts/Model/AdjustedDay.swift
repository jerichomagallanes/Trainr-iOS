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

    // Starts from the stored line, which names kit the catalog does not know: a
    // substitute adds its own, an omitted exercise's goes once nothing visible needs it.
    func derivedEquipment(_ catalog: any ExerciseCatalog) -> [String] {
        guard isAdjustedToday else { return equipment }
        let visible = visibleExercises
        let needed = Set(visible.kit(catalog))
        let dropped = exercises.filter(\.isOmittedToday).kit(catalog).filter { !needed.contains($0) }
        let kept = equipment.filter { name in !dropped.contains { name.describes($0) } }
        var added: [String] = []
        for item in visible.filter({ $0.addedBy != nil }).kit(catalog).map(\.catalogDisplayText)
        where !added.contains(item) && !kept.contains(where: { $0.describes(item) }) {
            added.append(item)
        }
        let line = kept + added
        return line.isEmpty ? equipment : line
    }

    func remainingMinutes(_ user: UserProfile, _ catalog: any ExerciseCatalog) -> Int {
        SessionEstimate.minutes(self, user: user, scope: .wholeSession, catalog: catalog)
    }
}

private nonisolated extension [WorkoutExercise] {
    func kit(_ catalog: any ExerciseCatalog) -> [Equipment] {
        compactMap { catalog[$0.exerciseKey]?.equipment }.filter { $0 != Equipment.none }
    }
}

private nonisolated extension String {
    func describes(_ equipment: Equipment) -> Bool {
        describes(equipment.catalogDisplayText)
    }

    func describes(_ text: String) -> Bool {
        lowercased().hasPrefix(text.lowercased())
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
