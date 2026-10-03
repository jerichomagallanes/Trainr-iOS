import Foundation

nonisolated enum UnstuckText {

    static func joinAnd(_ parts: [String]) -> String {
        guard let last = parts.last else { return "" }
        guard parts.count > 1 else { return last }
        return L10n.joinAndFormat(parts.dropLast().joined(separator: ", "), last)
    }
}

nonisolated extension MuscleRegion {
    var displayName: String {
        switch self {
        case .chest: L10n.regionChest
        case .back: L10n.regionBack
        case .shoulders: L10n.regionShoulders
        case .arms: L10n.regionArms
        case .core: L10n.regionCore
        case .quads: L10n.regionQuads
        case .hamstrings: L10n.regionHamstrings
        case .hips: L10n.regionHips
        case .calves: L10n.regionCalves
        case .other: L10n.regionOtherLabel
        }
    }
}

nonisolated extension TradeoffUi {
    var text: String {
        switch code {
        case .lessWorkForRegions:
            L10n.tradeoffLessWorkFormat(UnstuckText.joinAnd(regions.map(\.displayName)))
        case .reducedSession: L10n.tradeoffReducedSession
        case .differentResistance: L10n.tradeoffDifferentResistance
        case .differentMovement: L10n.tradeoffDifferentMovement
        case .lessBarbellPractice: L10n.tradeoffLessBarbellFormat(exerciseName ?? "")
        case .separateLoadHistory: L10n.tradeoffSeparateHistory
        }
    }
}
