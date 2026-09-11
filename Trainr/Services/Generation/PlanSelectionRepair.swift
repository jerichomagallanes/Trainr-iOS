import Foundation

nonisolated enum SelectionRepairResult: Equatable, Sendable {
    // Repairs counts slots only: a title the app can name itself is no reason
    // to spend another request.
    case accepted(PlanSelection, repairs: Int)
    case rejected([String])
}

// What the schema cannot rule out, repaired from each slot's own ranking. An
// answer goes back only when repairing it would leave more of the week the
// app's choice than the model's. The messages quote the answer, so they are
// for the model and never for the trail.
nonisolated struct PlanSelectionRepair: Sendable {

    func repair(_ json: String, skeleton: PlanSkeleton) -> SelectionRepairResult {
        let open = skeleton.days.filter { !$0.openSlots.isEmpty }
        if open.isEmpty { return .accepted(PlanSelection(), repairs: 0) }
        guard let data = json.data(using: .utf8),
              let answer = (try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)) as? [String: Any]
        else { return .rejected([Self.notAnObject]) }

        var problems: [String] = []
        var repairs = 0
        var answered = 0
        var days: [String: DaySelection] = [:]
        var named: [String: SkeletonDay] = [:]

        for day in open {
            let session = Self.session(day)
            let given = answer[day.id] as? [String: Any]
            if given == nil {
                problems.append(
                    "You left out \(session). Answer every session in the schema, each with its title and each of its slots."
                )
                repairs += day.openSlots.count
            } else {
                answered += 1
            }

            var taken = Set(day.slots.filter(\.isDecided).flatMap(\.candidates))
            var slots: [String: String] = [:]
            for slot in day.openSlots {
                let key = given.flatMap { Self.text($0[slot.id]) }
                if given != nil, let problem = slotProblem(session, slot, key, taken) {
                    problems.append(problem)
                    repairs += 1
                }
                let valid = key.flatMap { slot.candidates.contains($0) && !taken.contains($0) ? $0 : nil }
                if let chosen = valid ?? slot.candidates.first(where: { !taken.contains($0) }) {
                    taken.insert(chosen)
                    slots[slot.id] = chosen
                }
            }

            var title = day.fallbackTitle
            if let given {
                let written = (Self.text(given[Self.titleKey]) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if let problem = titleProblem(session, written) {
                    problems.append(problem)
                } else if let earlier = named[written.lowercased()] {
                    problems.append(
                        "\(Self.session(earlier)) and \(session) are both called \"\(written)\". Each session needs its own name."
                    )
                } else {
                    title = written
                    named[written.lowercased()] = day
                }
            }
            days[day.id] = DaySelection(slots: slots, title: title)
        }

        let openSlots = open.reduce(0) { $0 + $1.openSlots.count }
        if answered == 0 || repairs * 2 > openSlots { return .rejected(problems) }
        return .accepted(PlanSelection(days: days), repairs: repairs)
    }

    private func slotProblem(_ session: String, _ slot: SkeletonSlot, _ key: String?, _ taken: Set<String>) -> String? {
        guard let key else {
            return "In \(session) you left out \(slot.label). Fill every slot with one movement from that slot's own list."
        }
        if taken.contains(key) {
            return "In \(session), '\(key)' is already used earlier in that session. Each slot needs a different movement."
        }
        if !slot.candidates.contains(key) {
            return "In \(session), \(slot.label) was answered with '\(key)'. That is not on that slot's list. "
                + "Choose only from the keys listed for the slot you are filling."
        }
        return nil
    }

    private func titleProblem(_ session: String, _ title: String) -> String? {
        let words = title.split(whereSeparator: \.isWhitespace).count
        if title.isEmpty || title.count > Self.maxTitleChars || !(2...4).contains(words) {
            return "The title for \(session) must be two to four words naming the body region and the focus, "
                + "like \"Upper Body Strength\". \"\(title)\" is not."
        }
        if title.range(of: Self.indexLabel, options: [.regularExpression, .caseInsensitive]) != nil {
            return "The title for \(session) is an index label. The app already shows which day and which week it is; "
                + "name what the session trains."
        }
        if let filler = Self.filler.first(where: { title.range(of: $0, options: .caseInsensitive) != nil }) {
            return "The title for \(session) uses \"\(filler)\", which says nothing about this session. "
                + "Name the region and the focus instead."
        }
        return nil
    }

    private static func text(_ value: Any?) -> String? {
        guard let text = value as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }

    private static func session(_ day: SkeletonDay) -> String { "\(day.id) (\(day.fallbackTitle))" }

    // Deliberately without the decoder's own words: they can quote the
    // answer, which was written from the profile.
    static let notAnObject = "Your answer was not a JSON object. Reply with only the JSON described by "
        + "the schema, with nothing before or after it."

    private static let titleKey = "title"
    private static let maxTitleChars = 40
    private static let indexLabel = #"\b(day|week|session|workout|phase)\s*\d|\b[a-z]$"#
    private static let filler = ["good form", "engage your core", "full body workout", "training session"]
}
