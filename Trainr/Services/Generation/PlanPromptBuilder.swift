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

        When the client's answers pull against each other, this is the order that
        decides: injuries first, then the equipment they actually have, then the
        time they have, then their goal, then their preferred style. The style
        decides what the sessions are made of; the goal decides how they are
        loaded.

        Program design rules:
        - Plan exactly the number of training days requested, placed across the
          seven days of the week (1 = the first day of the week .. 7 = the last),
          spacing hard sessions with at least one rest day where possible. The
          week begins on the day the client starts, which may be any weekday.
        - Split by days per week: 1-3 days full body; 4 days upper/lower; 5-6 days
          push/pull/legs style. At 7 days, program at most 5 hard sessions and make
          the others easy mobility or low-intensity work.
        - Train every major muscle group at least twice in the week: the same work
          split over two days beats all of it on one.
        - Reach the weekly set target given below for each major muscle group, and
          never exceed the session set cap given below. The cap is what the
          client's session length pays for once warm-up and rest are counted, so a
          session that exceeds it is a session they will not finish.
        - Include a lower-body push, an upper-body push and an upper-body pull
          every week. Order each session large muscle groups before small,
          multi-joint before single-joint.
        - Each day starts with a short warm-up exercise (DURATION measure): easy
          versions of the movements that follow, not a generic routine and not
          static stretching.
        - Load and reps follow the goal: strength 3-6 reps and 180s rest, heavy;
          muscle gain 6-12 reps, 90-120s rest on multi-joint work and 60-90s on
          isolation; endurance and weight loss 12-20 reps or timed work with
          30-60s rest; general fitness 8-12 reps with 60-90s rest; flexibility
          timed holds of about 60 seconds per muscle group.
        - Leave 1-3 repetitions in reserve on every working set and never program
          a set to failure: failure is not needed for strength or size. A beginner
          or a first week stays at 2-3 in reserve, and technique comes before load.
        - Where no external load is available, a strength goal is served by harder
          leverage - slower tempo, fuller range, one-limb versions - never by
          prescribing a low-rep maximum the client has no weight to reach.
        - Prescribe conditioning by time, never by distance, and meet the weekly
          conditioning minutes given below where there are any. Where the goal is
          muscle or strength, keep conditioning short and low-impact and keep it
          off the day before a hard leg session: running blunts strength and size
          gains where cycling does not.
        - Use ONLY the client's available equipment, and list in each day's
          equipment array only items from that list. Prescribe a weight (measure
          WEIGHT_AND_REPS, weightKg on every set) only for movements loaded by that
          equipment; bodyweight movements are REPS; timed work, holds and cardio
          are DURATION with seconds.
        - Weights are kilograms, whatever the client reads them in. Every
          weightKg must be a multiple of the client's smallest loadable
          increment, given below, or the plan asks for a weight they cannot
          make. For a first week or a beginner, choose conservative loads the
          client can complete with three reps in reserve; progress comes later.
        - Respect injuries strictly: avoid movements that load the injured area
          (e.g. lower back pain: no loaded spinal flexion or heavy hinging from the
          floor; knee problems: no jumps or deep loaded knee flexion; shoulder
          injury: no overhead pressing or dips), substitute a safe alternative, and
          put the relevant form cue in that exercise's instructions.
        - Scale volume to experience: beginners 2-3 sets of simple movements with
          clear form cues; intermediate moderate volume; advanced higher volume and
          intensity.
        - Age 65 and over: include balance work in every session, prefer supported
          or machine versions of each movement, and program no maximal attempts.
          Under 18: bodyweight competence and technique first, moderate loads, and
          no maximal attempts.

        Progression rules when a previous week is provided:
        - Reuse the same exerciseKey for the same movement so history carries over.
        - If every set hit its target, add load: one increment at minimum, and
          2-10% where that is more. An increase smaller than one increment is not
          an increase, because the client cannot load it. Where there is no load,
          add 1-2 reps or 5-10 seconds instead.
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
          Strength", "Lower Body Power") - never letter or index labels like
          "Full Body A" or "Day 1".
        - The plan title names the block, not its position: "Beginner Muscle
          Building", never "... - Week 2". The app shows which week it is.
        - prescription is a short chip under about 25 characters, shaped like
          "3 sets of 12 reps", "3 sets of 45 seconds" or "5 minutes". Per-side,
          tempo or pacing detail belongs in instructions, never the prescription.
        - instructions are 1-2 sentences of how and why with one form cue.
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
            "- Preferred training style: \(text(for: user.workoutType))",
            "- Trains at: \(user.workoutLocation.rawValue)",
            "- Available equipment: \(text(for: user.availableEquipment))",
            "- Days per week: \(user.workoutDaysPerWeek) (plan EXACTLY this many days)",
            "- Session length: about \(user.workoutDuration) minutes",
            "- Session set cap: at most \(SessionBudget.maxSetsPerSession(user)) sets in "
                + "one day, warm-up included",
            "- Weekly set target: about \(SessionBudget.weeklySetsPerMuscle(user)) hard sets "
                + "per major muscle group across the week",
            "- Reads weights in \(weightWord(for: user.weightUnits)); smallest loadable "
                + "increment \(incrementKg(for: user.weightUnits)) kg"
        ]
        if let conditioning = weeklyConditioningMinutes(for: user) {
            lines.append("- Weekly conditioning: \(conditioning)")
        }
        if !user.injuries.isEmpty {
            let named = user.injuries.map(text(for:)).joined(separator: ", ")
            lines.append("- Injuries or areas to protect: \(named)")
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

    // Public-health dose, so the plan reaches it rather than leaving the
    // client to guess: 150-300 minutes a week for health, and more than 250
    // before weight loss becomes clinically meaningful (WHO 2020; ACSM 2009).
    private func weeklyConditioningMinutes(for user: UserProfile) -> String? {
        switch user.fitnessGoal {
        case .weightLoss: "at least 250 minutes of moderate work across the week"
        case .endurance: "150-300 minutes of moderate work across the week"
        case .generalFitness: "at least 150 minutes of moderate work across the week"
        default: nil
        }
    }

    private func text(for injury: Injury) -> String {
        switch injury {
        case .lowerBack: "lower back pain"
        case .knee: "knee problems"
        case .shoulder: "shoulder injury"
        case .wrist: "wrist pain"
        case .ankle: "ankle issues"
        case .hip: "hip problems"
        case .neck: "neck pain"
        }
    }

    private func text(for style: WorkoutType) -> String {
        switch style {
        case .strength: "resistance training"
        case .cardio: "cardio"
        case .hiit: "high-intensity intervals"
        case .yoga: "mobility and yoga"
        case .mixed: "a mix of resistance and conditioning"
        }
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
            equipment.filter { $0 != .none }.map(text(for:)).joined(separator: ", ")
        }
    }

    // Named the way a coach would name them, so the model knows what a
    // machine is for rather than guessing from an enum case.
    private func text(for item: Equipment) -> String {
        switch item {
        case .none: "bodyweight only"
        case .dumbbells: "dumbbells"
        case .barbell: "barbell and plates"
        case .bench: "adjustable bench"
        case .resistanceBands: "resistance bands"
        case .pullUpBar: "pull-up bar"
        case .kettlebells: "kettlebells"
        case .squatRack: "squat rack"
        case .cableMachine: "cable machine"
        case .machines: "weight machines (lat pulldown, leg press, chest press, leg curl)"
        case .cardioMachines: "cardio machines (treadmill, bike, rower)"
        case .mat: "exercise mat"
        case .jumpRope: "jump rope"
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
