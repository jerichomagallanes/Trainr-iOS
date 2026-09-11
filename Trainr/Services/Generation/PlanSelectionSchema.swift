import Foundation

// Everything the model may answer, as plain data rather than the SDK's type,
// so both platforms render it to the same bytes (docs/fixtures) and the same
// tree can become an on-device grammar later. Every property is required.
nonisolated enum SelectionSchema: Equatable, Sendable {
    case object([SelectionProperty])
    case oneOf([String], description: String)
    case text(description: String)

    var json: String {
        var out = ""
        Self.write(self, depth: 0, into: &out)
        return out + "\n"
    }

    private static func write(_ schema: SelectionSchema, depth: Int, into out: inout String) {
        let pad = String(repeating: "  ", count: depth + 1)
        out += "{\n"
        switch schema {
        case .object(let properties):
            out += pad + "\"type\": \"object\",\n"
            out += pad + "\"properties\": {"
            for (index, property) in properties.enumerated() {
                out += index == 0 ? "\n" : ",\n"
                out += pad + "  " + quoted(property.name) + ": "
                write(property.schema, depth: depth + 2, into: &out)
            }
            out += properties.isEmpty ? "},\n" : "\n" + pad + "},\n"
            out += pad + "\"required\": [" + properties.map { quoted($0.name) }.joined(separator: ", ") + "]\n"
        case .oneOf(let values, let description):
            out += pad + "\"type\": \"string\",\n"
            out += pad + "\"description\": " + quoted(description) + ",\n"
            out += pad + "\"enum\": [" + values.map(quoted).joined(separator: ", ") + "]\n"
        case .text(let description):
            out += pad + "\"type\": \"string\",\n"
            out += pad + "\"description\": " + quoted(description) + "\n"
        }
        out += String(repeating: "  ", count: depth) + "}"
    }

    private static func quoted(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}

nonisolated struct SelectionProperty: Equatable, Sendable {
    let name: String
    let schema: SelectionSchema
}

nonisolated enum PlanSelectionSchema {

    // A session with nothing left to choose is not in it at all, and each open
    // slot is an enum of its own candidates, so a movement the slot does not
    // offer cannot be written. Slots come before the title, so a session is
    // named after what it holds.
    static func schema(for skeleton: PlanSkeleton) -> SelectionSchema {
        .object(skeleton.days.filter { !$0.openSlots.isEmpty }.map { SelectionProperty(name: $0.id, schema: day($0)) })
    }

    private static func day(_ day: SkeletonDay) -> SelectionSchema {
        let title = SelectionSchema.text(
            description: "Two to four words naming what this \(day.focus.title.lowercased()) session trains"
        )
        return .object(
            day.openSlots.map { SelectionProperty(name: $0.id, schema: slot($0)) }
                + [SelectionProperty(name: "title", schema: title)]
        )
    }

    // Unreachable, but an enum with no members is an answer no model can give;
    // a string lets the repair explain the problem instead.
    private static func slot(_ slot: SkeletonSlot) -> SelectionSchema {
        slot.candidates.isEmpty
            ? .text(description: slot.label)
            : .oneOf(slot.candidates, description: slot.label)
    }
}
