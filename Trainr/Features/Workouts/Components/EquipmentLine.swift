import SwiftUI

// One string in two weights, so the label and the list cannot wrap apart.
nonisolated enum EquipmentLine {

    static func text(_ equipment: [String], labelFont: Font) -> AttributedString {
        var label = AttributedString(L10n.equipmentLabel + " ")
        label.font = labelFont
        return label + AttributedString(equipment.joined(separator: ", "))
    }
}
