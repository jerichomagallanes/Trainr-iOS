import Foundation

nonisolated struct PlanPromptBuilder {

    // The video catalog's keys. Other movements may get new keys, but these
    // must use these exact ones or history and tutorials silently split.
    private let canonicalKeys: [String]

    init(canonicalKeys: Set<String> = []) {
        self.canonicalKeys = canonicalKeys.sorted()
    }

    func systemInstruction() -> String {
        """
        You are an experienced, certified strength and conditioning coach writing a
        one-week training program for a real client. Program like a professional:
        every choice must have a coaching reason, and the week must be one the
        client can actually complete and recover from.

        Program design rules:
        - Plan exactly the number of training days requested, placed across the
          seven days of the week (1 = the first day of the week .. 7 = the last),
          spacing hard sessions with at least one rest day where possible. The
          week begins on the day the client starts, which may be any weekday.
        - Split by days per week: 2-3 days full body; 4 days upper/lower; 5-6 days
          push/pull/legs style. Respect the client's preferred training style.
        - Each day starts with a short warm-up exercise (DURATION measure).
        - Match rep ranges and rest to the goal: strength 3-6 reps with 120-180s
          rest; muscle gain 6-12 reps with 60-120s rest; endurance and weight loss
          12-20 reps or timed work with 30-60s rest; general fitness balanced;
          flexibility mobility-focused timed holds.
        - A session's exercise durationMinutes must sum close to the requested
          session length, warm-up included.
        - Use ONLY the client's available equipment. Prescribe a weight (measure
          WEIGHT_AND_REPS, weightKg on every set) only for movements loaded by that
          equipment; bodyweight movements are REPS; timed work, holds and cardio
          are DURATION with seconds. Prescribe cardio by time, never by distance.
        - Weights are kilograms, whatever the client reads them in. Every
          weightKg must be a multiple of the client's smallest loadable
          increment, given below, or the plan asks for a weight they cannot
          make. For a first week or a beginner, choose conservative loads the
          client can complete with two reps in reserve; progress comes later,
          technique comes first.
        - Respect injuries strictly: avoid movements that load the injured area
          (e.g. lower back pain: no loaded spinal flexion or heavy hinging from the
          floor; knee problems: no jumps or deep loaded knee flexion; shoulder
          injury: no overhead pressing or dips), substitute a safe alternative, and
          put the relevant form cue in that exercise's instructions.
        - Scale volume to experience: beginners 2-3 sets of simple movements with
          clear form cues; intermediate moderate volume; advanced higher volume and
          intensity.

        Progression rules when a previous week is provided:
        - Reuse the same exerciseKey for the same movement so history carries over.
        - If every set hit its target, add load: at least one increment, and
          roughly 2.5-5% where that is more. Where there is no load, add 1-2
          reps or 5-10 seconds instead. An increase smaller than one increment
          is not an increase, because the client cannot load it.
        - If a set missed its target by 2 or more reps, keep or reduce the target
          by about 10%.
        - If an exercise was skipped, repeat its week unchanged.

        Output rules:
        - exerciseKey is a canonical English lower_snake_case slug (goblet_squat,
          bent_over_row), singular, identical for the same movement in every week
          and language. It is an identifier, never translated.\(knownKeysRule())
        - name, titles, equipment, prescription and instructions are display copy
          in the requested language. Capitalize each equipment item ("Dumbbells",
          "Yoga Mat").
        - Day titles are short and name the session's focus ("Full Body
          Strength", "Lower Body Power") — never letter or index labels like
          "Full Body A" or "Day 1".
        - The plan title names the block, not its position: "Beginner Muscle
          Building", never "... - Week 2". The app shows which week it is.
        - prescription is a short chip under about 25 characters, shaped like
          "3 sets of 12 reps", "3 sets of 45 seconds" or "5 minutes". Per-side,
          tempo or pacing detail belongs in instructions, never the prescription.
        - instructions are 1-2 sentences of how and why with one form cue.
        - durationMinutes is the time allotted to the exercise in the session; it
          is independent of the prescription.
        - Respond with JSON only, exactly matching the provided schema.
        """
    }

    func userPrompt(_ request: PlanRequest) -> String {
        let user = request.user
        var lines = [
            "Write week \(request.weekNumber) for this client.",
            "",
            "Client profile:",
            "- Age \(user.age), height \(user.height) cm, weight \(user.weight) kg",
            "- Goal: \(text(for: user.fitnessGoal))",
            "- Experience: \(user.experienceLevel.rawValue)",
            "- Preferred training style: \(user.workoutType.rawValue)",
            "- Trains at: \(user.workoutLocation.rawValue)",
            "- Available equipment: \(text(for: user.availableEquipment))",
            "- Days per week: \(user.workoutDaysPerWeek) (plan EXACTLY this many days)",
            "- Session length: about \(user.workoutDuration) minutes",
            "- Reads weights in \(weightWord(for: user.weightUnits)); smallest loadable "
                + "increment \(incrementKg(for: user.weightUnits)) kg"
        ]
        if !user.injuries.isEmpty {
            lines.append("- Injuries or areas to protect: \(user.injuries.joined(separator: ", "))")
        }
        lines.append("- Write all display copy in: \(language(for: request.languageCode))")
        if let previousWeek = request.previousWeek {
            lines.append(contentsOf: history(of: previousWeek))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func knownKeysRule() -> String {
        if canonicalKeys.isEmpty {
            ""
        } else {
            "\n- When you prescribe one of these movements or a close variant of"
                + "\n  it, use exactly this key rather than minting a near-duplicate:"
                + "\n  \(canonicalKeys.joined(separator: ", "))."
        }
    }

    private func history(of week: WeeklyPlan) -> [String] {
        var lines = ["", "Last week (week \(week.weekNumber)) and what was actually done:"]
        for day in week.workoutDays {
            let outcome = day.status == .completed ? "completed" : "skipped"
            lines.append("- \(day.title) (\(outcome)):")
            for exercise in day.exercises {
                lines.append("  - \(historyLine(for: exercise))")
            }
        }
        lines.append("Apply the progression rules to this history, reusing each exerciseKey.")
        return lines
    }

    private func historyLine(for exercise: WorkoutExercise) -> String {
        let done = exercise.sets.map { set in
            if !set.isCompleted {
                "skipped"
            } else if exercise.measure == .duration {
                "\(set.actualSeconds ?? 0)s"
            } else if let weight = set.actualWeightKg {
                "\(weight)kg x \(set.actualReps ?? 0)"
            } else {
                "\(set.actualReps ?? 0)"
            }
        }.joined(separator: ", ")
        return "\(exercise.exerciseKey): prescribed \"\(exercise.prescription)\", did: \(done)"
    }

    private func text(for goal: FitnessGoal) -> String {
        switch goal {
        case .weightLoss: "lose weight"
        case .muscleGain: "build muscle"
        case .strength: "get stronger"
        case .endurance: "improve endurance"
        case .generalFitness: "general fitness"
        case .flexibility: "flexibility and mobility"
        }
    }

    private func weightWord(for units: UnitSystem) -> String {
        switch units {
        case .metric: "kilograms"
        case .imperial: "pounds"
        }
    }

    // In kilograms, the unit the contract speaks: five pounds is 2.27 kg, so a
    // client in pounds gets multiples that land on plates they actually own.
    private func incrementKg(for units: UnitSystem) -> String {
        switch units {
        case .metric: "2.5"
        case .imperial: "2.27"
        }
    }

    private func text(for equipment: [Equipment]) -> String {
        if equipment.isEmpty || equipment == [.none] {
            "none - bodyweight only"
        } else {
            equipment.map(text(for:)).joined(separator: ", ")
        }
    }

    private func text(for item: Equipment) -> String {
        switch item {
        case .none: "none"
        case .dumbbells: "dumbbells"
        case .barbell: "barbell"
        case .bench: "bench"
        case .resistanceBands: "resistance bands"
        case .pullUpBar: "pull up bar"
        case .kettlebells: "kettlebells"
        case .squatRack: "squat rack"
        case .cableMachine: "cable machine"
        case .cardioMachines: "cardio machines"
        case .others: "others"
        }
    }

    private func language(for code: String) -> String {
        switch code {
        case "ja": "Japanese"
        case "tl": "Tagalog (Filipino)"
        default: "English"
        }
    }
}
