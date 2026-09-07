import SwiftUI

// "Equipment: Dumbbells, Yoga Mat" as one string in two weights, so the label
// and the list beside it cannot wrap apart from each other. Shared because the
// day card and the routine screen say the same sentence, and said it in two
// places that had to be kept in step by hand.
nonisolated enum EquipmentLine {

    static func text(_ equipment: [String], labelFont: Font) -> AttributedString {
        var label = AttributedString(L10n.equipmentLabel + " ")
        label.font = labelFont
        return label + AttributedString(equipment.joined(separator: ", "))
    }
}
