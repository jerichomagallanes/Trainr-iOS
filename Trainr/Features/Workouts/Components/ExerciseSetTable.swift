import SwiftUI

struct ExerciseSetTable: View {
    let measure: ExerciseMeasure
    let sets: [ExerciseSet]
    var previousSets: [ExerciseSet] = []
    var units = UnitSystem.metric
    let onSetChanged: (ExerciseSet) -> Void
    let onAddSet: () -> Void
    var onDeleteSet: (ExerciseSet) -> Void = { _ in }

    private static let rowHeight: CGFloat = 34
    private static let checkSize: CGFloat = 24
    private static let setColumnWidth: CGFloat = 34

    // No column at all without history: a week-one card looks exactly like the
    // design, which has no PREVIOUS.
    private var showsPrevious: Bool { !previousSets.isEmpty }

    var body: some View {
        VStack(spacing: Spacing.small) {
            // Column headings over nothing are noise, so an emptied table is
            // just its Add set button. The button itself is never conditional:
            // deleting the last set has to leave a way back.
            if !sets.isEmpty {
                headings
            }
            ForEach(sets) { set in
                SwipeToDelete(
                    label: L10n.deleteSet,
                    onDelete: { onDeleteSet(set) },
                    content: {
                        SetRow(
                            measure: measure,
                            set: set,
                            previousText: showsPrevious
                                ? SetFormatting.previousCell(
                                    measure: measure,
                                    previous: previousSets.first { $0.setNumber == set.setNumber },
                                    units: units
                                )
                                : nil,
                            units: units,
                            onSetChanged: onSetChanged
                        )
                    }
                )
                // Keyed to the set itself, so a renumbered survivor cannot
                // inherit a dismissed row's state.
                .id(set.id)
            }
            addSetButton
        }
    }

    private var headings: some View {
        HStack(spacing: 0) {
            ColumnLabel(L10n.setColumn).frame(width: Self.setColumnWidth)
            if showsPrevious {
                ColumnLabel(L10n.previousColumn).frame(maxWidth: .infinity)
            }
            if measure == .weightAndReps {
                ColumnLabel(units == .imperial ? L10n.weightColumnLbs : L10n.weightColumn)
                    .frame(maxWidth: .infinity)
            }
            ColumnLabel(measure == .duration ? L10n.timeColumn : L10n.repsColumn)
                .frame(maxWidth: .infinity)
            Color.clear.frame(width: Self.checkSize, height: 1)
        }
    }

    private var addSetButton: some View {
        Button(action: onAddSet) {
            Text(L10n.addSet)
                .font(.labelLarge)
                .foregroundStyle(Color.slate800)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.small)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(Color.outlineGray, lineWidth: 1)
        }
    }
}

private struct ColumnLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.labelSmall)
            .foregroundStyle(Color.textMuted)
            .multilineTextAlignment(.center)
    }
}

private struct SetRow: View {
    let measure: ExerciseMeasure
    let set: ExerciseSet
    let previousText: String?
    let units: UnitSystem
    let onSetChanged: (ExerciseSet) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text("\(set.setNumber)")
                .font(.labelLarge)
                .foregroundStyle(Color.slate800)
                .frame(width: 34)

            if let previousText {
                Text(previousText)
                    .font(.body12)
                    .foregroundStyle(Color.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            if measure == .weightAndReps {
                NumberCell(
                    value: set.actualWeightKg.map { SetFormatting.weight($0, in: units) },
                    placeholder: set.targetWeightKg.map { SetFormatting.weight($0, in: units) },
                    isDecimal: true
                ) { entered in
                    var changed = set
                    changed.actualWeightKg = entered
                        .flatMap(Double.init)
                        .map { WeightUnit.kilograms($0, in: units) }
                    onSetChanged(changed)
                }
                .frame(maxWidth: .infinity)
            }

            measureCell
                .frame(maxWidth: .infinity)

            Button {
                var changed = set
                changed.isCompleted.toggle()
                onSetChanged(changed)
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(set.isCompleted ? Color.statusCompleted : Color.outlineGray)
                    .frame(width: 24, height: 24)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isCompleted ? L10n.markSetIncomplete : L10n.markSetComplete)
        }
    }

    @ViewBuilder
    private var measureCell: some View {
        switch measure {
        case .duration:
            DurationCell(
                seconds: set.actualSeconds,
                placeholderSeconds: set.targetSeconds
            ) { entered in
                var changed = set
                changed.actualSeconds = entered
                onSetChanged(changed)
            }
        default:
            NumberCell(
                value: set.actualReps.map(String.init),
                placeholder: set.targetReps.map(String.init),
                isDecimal: false
            ) { entered in
                var changed = set
                changed.actualReps = entered.flatMap(Int.init)
                onSetChanged(changed)
            }
        }
    }
}

// The target is the placeholder rather than the value, so an untouched row
// shows what was asked for without claiming you did it.
private struct NumberCell: View {
    let value: String?
    let placeholder: String?
    let isDecimal: Bool
    let onChange: (String?) -> Void

    @State private var text = ""

    var body: some View {
        TextField(placeholder ?? "", text: $text)
            .font(.body14)
            .foregroundStyle(Color.slate800)
            .multilineTextAlignment(.center)
            .keyboardType(isDecimal ? .decimalPad : .numberPad)
            .frame(height: 34)
            .frame(maxWidth: .infinity)
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .strokeBorder(Color.outlineGray, lineWidth: 1)
            }
            .padding(.horizontal, Spacing.extraSmall)
            .onAppear { text = value ?? "" }
            .onChange(of: value) { _, latest in
                // Only when the model disagrees with what is on screen, so a
                // write-back never interrupts typing.
                if latest ?? "" != text { text = latest ?? "" }
            }
            .onChange(of: text) { _, typed in
                let capped = String(typed.prefix(6))
                if capped != typed { text = capped }
                onChange(capped.isEmpty ? nil : capped)
            }
    }
}

// Digits fill in from the seconds end ("500" is 5:00), shown as m:ss to match
// the exercise timer, stored as seconds.
private struct DurationCell: View {
    let seconds: Int?
    let placeholderSeconds: Int?
    let onChange: (Int?) -> Void

    // The field's own text, rewritten after every keystroke. A computed
    // binding was not enough: the field kept what was typed and showed
    // "5:50000" for a five typed into the middle of "5:00".
    @State private var text = ""

    var body: some View {
        TextField(placeholderSeconds.map(SetFormatting.seconds) ?? "", text: $text)
            .onChange(of: text) { _, typed in
                let digits = String(String(typed.filter(\.isNumber)).suffix(4))
                let total = SetFormatting.secondsFromDigits(digits)
                let formatted = total.map(SetFormatting.seconds) ?? ""
                if formatted != typed { text = formatted }
                onChange(total)
            }
        .font(.body14)
        .foregroundStyle(Color.slate800)
        .multilineTextAlignment(.center)
        .keyboardType(.numberPad)
        .frame(height: 34)
        .frame(maxWidth: .infinity)
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .strokeBorder(Color.outlineGray, lineWidth: 1)
        }
        .padding(.horizontal, Spacing.extraSmall)
        .onAppear { text = seconds.map(SetFormatting.seconds) ?? "" }
    }
}
