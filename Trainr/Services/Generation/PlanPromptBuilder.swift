import Foundation

// Only what the choice needs. Everything the old brief asked for in words is
// now decided before the model is asked or computed after it answers, so none
// of it is a rule the model can break. Injuries are not mentioned at all: a
// movement they rule out is on no slot's list.
nonisolated struct PlanPromptBuilder {

    func systemInstruction() -> String {
        """
        You are a strength coach choosing which movements a client trains this week.

        The app has already decided the split, which days they train, how many slots
        each day holds and what each slot is for, and it computes every set, load,
        rest and instruction afterwards. Your job is which movement fills each slot,
        and what to call each session.

        Every slot offers only movements this client can perform, with the kit they
        own, that are safe for them. Choose one of them for each slot.

        - Take the candidate that best does that slot's job for this client. Where
          two do it equally well, prefer the one their experience and age suit.
        - A day is one session, not six separate choices: no two slots should take
          near-versions of the same movement, and a day of free weights should not
          send the client across four machines to finish it.
        - Titles are English, two to four words, and name the region and the focus:
          "Upper Body Strength", "Legs and Core" - never "Day 2", "Week 3" or
          "Full Body A".
        - Answer with JSON only, in the shape given.
        """
    }

    func userPrompt(_ request: PlanRequest, skeleton: PlanSkeleton) -> String {
        let user = request.user
        var lines = [
            "Choose the movements for week \(request.weekNumber).",
            "",
            "Client: \(user.age), \(user.experienceLevel.rawValue), training to \(text(for: user.fitnessGoal)).",
            "",
            "Sessions, in the order they are trained:"
        ]
        for day in skeleton.days where !day.openSlots.isEmpty {
            let count = day.openSlots.count
            lines.append("- \(day.id), \(day.focus.title.lowercased()), \(count) \(count == 1 ? "slot" : "slots")")
        }
        lines += [
            "",
            "Each slot names the job it does and carries its own list of movements.",
            "Slots that are already settled are not shown; leave the rest of the week alone."
        ]
        return lines.joined(separator: "\n") + "\n"
    }

    private func text(for goal: FitnessGoal) -> String {
        switch goal {
        case .weightLoss: "lose weight"
        case .muscleGain: "build muscle"
        case .strength: "get stronger"
        case .endurance: "build endurance"
        case .generalFitness: "get generally fitter"
        case .flexibility: "move more freely"
        }
    }
}
