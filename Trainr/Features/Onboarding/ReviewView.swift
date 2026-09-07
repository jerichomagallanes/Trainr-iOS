import SwiftUI

struct ReviewView: View {
    let profile: UserProfile
    var isRegenerating = false
    var isProfileUpdate = false
    let onConfirm: () -> Void
    let onBack: () -> Void
    let onEdit: (Route) -> Void

    var body: some View {
        ScreenScaffold(
            onBack: onBack,
            closeInsteadOfBack: isRegenerating || isProfileUpdate
        ) {
            VStack(spacing: Spacing.small) {
                // With the button rather than at the end of the scroll: this is the moment it matters.
                if !isProfileUpdate {
                    Text(L10n.healthDisclaimer)
                        .font(.body12)
                        .foregroundStyle(Color.textMuted)
                }
                PrimaryButton(
                    title: isProfileUpdate ? L10n.saveProfile : L10n.generateMyWorkoutPlan,
                    action: onConfirm
                )
            }
        } content: {
            if !isRegenerating && !isProfileUpdate {
                StepProgressBar(currentStep: 6, totalSteps: 7)
                    .padding(.horizontal, Spacing.large)
            }

            ScreenContent {
                Spacer().frame(height: Spacing.extraLarge)
                ScreenTitle(text: L10n.yourFitnessProfile)
                Spacer().frame(height: Spacing.small)
                Subtitle(text: isProfileUpdate
                    ? L10n.reviewProfileDescription : L10n.reviewDescription)
                Spacer().frame(height: Spacing.extraLarge)

                ProfileSection(
                    title: L10n.personalInformation,
                    items: [
                        (L10n.nameLabel, profile.firstName),
                        (L10n.ageLabel, L10n.yearsOldFormat(profile.age)),
                        (L10n.genderLabel, profile.gender.displayName),
                        (L10n.experienceLabel, profile.experienceLevel.displayName)
                    ],
                    onEdit: { onEdit(.basicInfo(editing: true)) }
                )

                Spacer().frame(height: Spacing.screen)

                ProfileSection(
                    title: L10n.measurementsLabel,
                    items: [
                        (L10n.heightLabel, heightText),
                        (L10n.weightLabel, weightText)
                    ],
                    onEdit: { onEdit(.bodyMetrics(editing: true)) }
                )

                Spacer().frame(height: Spacing.screen)

                ProfileSection(
                    title: L10n.fitnessGoalsLabel,
                    items: [
                        (L10n.mainGoalLabel, profile.fitnessGoal.displayName),
                        (L10n.workoutStyleLabel, profile.workoutType.displayName)
                    ],
                    onEdit: { onEdit(.fitnessGoal(editing: true)) }
                )

                Spacer().frame(height: Spacing.screen)

                ProfileSection(
                    title: L10n.workoutSetupLabel,
                    items: setupItems,
                    onEdit: { onEdit(.workoutSetup(editing: true)) }
                )

                Spacer().frame(height: Spacing.screen)

                ProfileSection(
                    title: L10n.limitationsLabel,
                    items: [
                        (L10n.injuriesConcernsLabel, profile.injuries.isEmpty
                            ? L10n.noneLabel
                            : profile.injuries.joined(separator: ", "))
                    ],
                    onEdit: { onEdit(.limitations(editing: true)) }
                )

                Spacer().frame(height: Spacing.extraLarge)

                if !isProfileUpdate {
                    AIPreviewCard(profile: profile)
                    Spacer().frame(height: Spacing.medium)
                }
            }
        }
    }

    // Read back in the units they were entered in; the profile is stored in cm and kg either way.
    private var heightText: String {
        if profile.bodyUnitSystem == .imperial {
            BodyMetricsConverter.convertHeightToImperial(String(Int(profile.height)))
        } else {
            L10n.heightCmFormat(Int(profile.height))
        }
    }

    private var weightText: String {
        if profile.bodyUnitSystem == .imperial {
            L10n.weightLbsFormat(
                BodyMetricsConverter.convertWeightToImperial(String(profile.weight)))
        } else {
            L10n.weightKgFormat(profile.weight)
        }
    }

    private var setupItems: [(String, String)] {
        var items: [(String, String)] = [
            (L10n.locationLabel, profile.workoutLocation.displayName),
            (L10n.equipmentLabelFull, equipmentText)
        ]
        if let liftingUnits = profile.liftingUnitSystem {
            items.append((
                L10n.weightsInLabel,
                liftingUnits == .imperial ? L10n.weightColumnLbs : L10n.weightColumn
            ))
        }
        items.append((L10n.scheduleLabel, profile.workoutDaysPerWeek == 0
            ? L10n.flexibleSchedule
            : L10n.daysPerWeekFormat(profile.workoutDaysPerWeek)))
        items.append((L10n.durationLabel, L10n.durationMinutesFormat(profile.workoutDuration)))
        items.append((L10n.preferredTimeLabel, profile.preferredWorkoutTime.displayName))
        return items
    }

    private var equipmentText: String {
        if profile.availableEquipment.isEmpty || profile.availableEquipment.contains(.none) {
            L10n.bodyweightOnlyLabel
        } else {
            profile.availableEquipment.map(\.displayName).joined(separator: ", ")
        }
    }
}

private struct ProfileSection: View {
    let title: String
    let items: [(String, String)]
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: Spacing.card) {
            HStack {
                SectionTitle(text: title)
                Spacer()
                Button(L10n.edit, action: onEdit)
                    .font(.labelLarge)
                    .foregroundStyle(Color.orange500)
            }
            ForEach(items, id: \.0) { label, value in
                HStack(alignment: .top, spacing: Spacing.card) {
                    Text(label)
                        .font(.body16)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(value)
                        .font(.body16)
                        .foregroundStyle(Color.slate800)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(Spacing.card)
        .background(Color.gray100.opacity(0.5),
                    in: RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
}

private struct AIPreviewCard: View {
    let profile: UserProfile

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: Spacing.small) {
                Image(.smartToy)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(Color.white)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.extraSmall) {
                    Text(L10n.aiRoutinePreviewLabel)
                        .font(.fieldLabel)
                        .foregroundStyle(Color.white)
                    Text(L10n.aiRoutineDescription(
                        profile.workoutDaysPerWeek == 0
                            ? L10n.flexibleSchedule
                            : L10n.programLengthFormat(profile.workoutDaysPerWeek),
                        profile.workoutType.programPhrase,
                        profile.fitnessGoal.focusPhrase
                    ))
                    .font(.body14)
                    .foregroundStyle(Color.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Spacing.medium)
            .background(Color.slate800)

            Rectangle().fill(Color.orange500).frame(height: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
}

#Preview {
    ReviewView(
        profile: UserProfile(firstName: "Alex", age: 30, height: 175, weight: 70),
        onConfirm: {}, onBack: {}, onEdit: { _ in }
    )
}
