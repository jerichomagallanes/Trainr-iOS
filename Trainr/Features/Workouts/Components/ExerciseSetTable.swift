import SwiftUI

// A floor rather than a fixed size, so larger text grows the row instead of
// clipping the number in it.
private let setRowHeight: CGFloat = 34

struct ExerciseSetTable: View {
    let measure: ExerciseMeasure
    let sets: [ExerciseSet]
    var previousSets: [ExerciseSet] = []
    var units = UnitSystem.metric
    let onSetChanged: (ExerciseSet) -> Void
    let onAddSet: () -> Void
    var onDeleteSet: (ExerciseSet) -> Void = { _ in }
    var isReadOnly = false

    // Point sizes that hold text: the tick and the set number are illegible,
    // and then clipped, once the type outgrows them.
    @ScaledMetric(relativeTo: .subheadline) private var checkSize: CGFloat = 24
    @ScaledMetric(relativeTo: .subheadline) private var setColumnWidth: CGFloat = 34

    private var showsPrevious: Bool { !previousSets.isEmpty }

    var body: some View {
        VStack(spacing: Spacing.small) {
            // The Add set button below is not tied to the headings either, so
            // deleting the last set leaves a live day a way back.
            if !sets.isEmpty {
                headings
            }
            ForEach(sets) { set in
                SwipeToDelete(
                    label: L10n.deleteSet,
                    enabled: !isReadOnly,
                    onDelete: { onDeleteSet(set) },
                    content: {
                        SetRow(
                            measure: measure,
                            set: set,
                            checkSize: checkSize,
                            setColumnWidth: setColumnWidth,
                            previousText: showsPrevious
                                ? SetFormatting.previousCell(
                                    measure: measure,
                                    previous: previousSets.first { $0.setNumber == set.setNumber },
                                    units: units
                                )
                                : nil,
                            units: units,
                            isReadOnly: isReadOnly,
                            onSetChanged: onSetChanged
                        )
                    }
                )
                // Keyed to the set, so a renumbered survivor cannot inherit a
                // dismissed row's state.
                .id(set.id)
            }
            if !isReadOnly {
                addSetButton
            }
        }
    }

    private var headings: some View {
        HStack(spacing: 0) {
            ColumnLabel(L10n.setColumn).frame(width: setColumnWidth)
            if showsPrevious {
                ColumnLabel(L10n.previousColumn).frame(maxWidth: .infinity)
            }
            if measure == .weightAndReps {
                ColumnLabel(units == .imperial ? L10n.weightColumnLbs : L10n.weightColumn)
                    .frame(maxWidth: .infinity)
            }
            ColumnLabel(measure == .duration ? L10n.timeColumn : L10n.repsColumn)
                .frame(maxWidth: .infinity)
            Color.clear.frame(width: checkSize, height: 1)
        }
    }

    private var addSetButton: some View {
        Button(action: onAddSet) {
            Text(L10n.addSet)
                .font(.labelLarge)
                .foregroundStyle(Color.onSurface)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.small)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .strokeBorder(Color.outlineControl, lineWidth: 1)
        }
    }
}

private struct ColumnLabel: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.labelSmall)
            .foregroundStyle(Color.onSurfaceMuted)
            .multilineTextAlignment(.center)
    }
}

private struct SetRow: View {
    let measure: ExerciseMeasure
    let set: ExerciseSet
    let checkSize: CGFloat
    let setColumnWidth: CGFloat
    let previousText: String?
    let units: UnitSystem
    let isReadOnly: Bool
    let onSetChanged: (ExerciseSet) -> Void

    @State private var outOfRange: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("\(set.setNumber)")
                    .font(.labelLarge)
                    .foregroundStyle(Color.onSurface)
                    .frame(minWidth: setColumnWidth)

                if let previousText {
                    Text(previousText)
                        .font(.body12)
                        .foregroundStyle(Color.onSurfaceMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                if measure == .weightAndReps {
                    weightCell
                        .frame(maxWidth: .infinity)
                }

                measureCell
                    .frame(maxWidth: .infinity)

                tick
            }
            FieldError(message: outOfRange)
        }
    }

    private var weightCell: some View {
        NumberCell(
            value: set.actualWeightKg.map { SetFormatting.weight($0, in: units) },
            placeholder: set.targetWeightKg.map { SetFormatting.weight($0, in: units) },
            isDecimal: true,
            rangeMessage: L10n.valueRangeHint(
                L10n.weightLabel,
                "\(NumberRules.lowestWeight)",
                "\(NumberRules.maxWeight(in: units)) "
                    + (units == .imperial ? L10n.weightColumnLbs : L10n.weightColumn)
            ),
            check: { NumberRules.weight($0, in: units) },
            isReadOnly: isReadOnly,
            onChange: { entered in
                var changed = set
                changed.actualWeightKg = entered
                    .flatMap(Double.init)
                    .map { WeightUnit.kilograms($0, in: units) }
                onSetChanged(changed)
            },
            onOutOfRange: { outOfRange = $0 }
        )
    }

    @ViewBuilder
    private var tick: some View {
        if isReadOnly {
            tickMark
                .accessibilityLabel(set.isCompleted ? L10n.completed : L10n.notCompleted)
        } else {
            Button {
                var changed = set
                changed.isCompleted.toggle()
                onSetChanged(changed)
            } label: {
                tickMark.contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isCompleted ? L10n.markSetIncomplete : L10n.markSetComplete)
        }
    }

    private var tickMark: some View {
        Image(systemName: set.isCompleted ? "checkmark.square.fill" : "square")
            .font(.oneOff(20))
            .foregroundStyle(set.isCompleted ? Color.statusDoneInk : Color.outlineControl)
            .frame(width: checkSize, height: checkSize)
    }

    @ViewBuilder
    private var measureCell: some View {
        switch measure {
        case .duration:
            DurationCell(
                seconds: set.actualSeconds,
                placeholderSeconds: set.targetSeconds,
                rangeMessage: L10n.valueRangeHint(
                    L10n.timeColumn,
                    SetFormatting.seconds(NumberRules.lowestSeconds),
                    SetFormatting.seconds(NumberRules.maxSeconds)
                ),
                isReadOnly: isReadOnly,
                onChange: { entered in
                    var changed = set
                    changed.actualSeconds = entered
                    onSetChanged(changed)
                },
                onOutOfRange: { outOfRange = $0 }
            )
        default:
            NumberCell(
                value: set.actualReps.map(String.init),
                placeholder: set.targetReps.map(String.init),
                isDecimal: false,
                rangeMessage: L10n.valueRangeHint(
                    L10n.repsColumn, "\(NumberRules.lowestReps)", "\(NumberRules.maxReps)"
                ),
                check: NumberRules.reps,
                isReadOnly: isReadOnly,
                onChange: { entered in
                    var changed = set
                    changed.actualReps = entered.flatMap(Int.init)
                    onSetChanged(changed)
                },
                onOutOfRange: { outOfRange = $0 }
            )
        }
    }
}

// The target is the placeholder rather than the value, so an untouched row
// shows what was asked for without claiming you did it.
private struct NumberCell: View {
    let value: String?
    let placeholder: String?
    let isDecimal: Bool
    let rangeMessage: String
    let check: (String) -> NumberEntry
    var isReadOnly = false
    let onChange: (String?) -> Void
    let onOutOfRange: (String?) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        if isReadOnly {
            LoggedCell(value: value, placeholder: placeholder)
        } else {
            field
        }
    }

    private var field: some View {
        TextField(placeholder ?? "", text: $text)
            .font(.body14)
            .foregroundStyle(Color.onSurface)
            .multilineTextAlignment(.center)
            .keyboardType(isDecimal ? .decimalPad : .numberPad)
            .focused($isFocused)
            .keyboardDone(whenFocused: isFocused) { isFocused = false }
            .frame(minHeight: setRowHeight)
            .frame(maxWidth: .infinity)
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .strokeBorder(Color.outlineControl, lineWidth: 1)
            }
            .padding(.horizontal, Spacing.extraSmall)
            .onAppear { text = value ?? "" }
            // The same number written another way is not a correction: "22." and
            // "22.50" both hold 22.5, and rewriting the field would eat the
            // keystroke after them.
            .onChange(of: value) { _, latest in
                if Double(latest ?? "") != Double(text) { text = latest ?? "" }
            }
            .onChange(of: text) { previous, typed in
                guard typed != value ?? "" else { return }
                judge(typed, against: previous)
            }
    }

    private func judge(_ typed: String, against previous: String) {
        switch check(typed) {
        case .accepted:
            onOutOfRange(nil)
            onChange(typed.isEmpty ? nil : typed)
        case .outOfRange:
            onOutOfRange(rangeMessage)
            if NumberRules.movesTowardRange(from: previous, to: typed, check) {
                onChange(typed.isEmpty ? nil : typed)
            } else {
                text = previous
            }
        case .malformed:
            text = previous
        }
    }
}

// Digits fill in from the seconds end ("500" is 5:00), shown as m:ss to match
// the exercise timer, stored as seconds.
private struct DurationCell: View {
    let seconds: Int?
    let placeholderSeconds: Int?
    let rangeMessage: String
    var isReadOnly = false
    let onChange: (Int?) -> Void
    let onOutOfRange: (String?) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var face: String { seconds.map(SetFormatting.seconds) ?? "" }

    var body: some View {
        if isReadOnly {
            LoggedCell(
                value: seconds.map(SetFormatting.seconds),
                placeholder: placeholderSeconds.map(SetFormatting.seconds)
            )
        } else {
            field
        }
    }

    private var field: some View {
        TextField(placeholderSeconds.map(SetFormatting.seconds) ?? "", text: $text)
            .onChange(of: text) { previous, typed in
                guard typed != face else { return }
                judge(typed, against: previous)
            }
        .font(.body14)
        .foregroundStyle(Color.onSurface)
        .multilineTextAlignment(.center)
        .keyboardType(.numberPad)
        .focused($isFocused)
        .keyboardDone(whenFocused: isFocused) { isFocused = false }
        .frame(minHeight: setRowHeight)
        .frame(maxWidth: .infinity)
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .strokeBorder(Color.outlineControl, lineWidth: 1)
        }
        .padding(.horizontal, Spacing.extraSmall)
        .onAppear { text = face }
        // The row keeps its id when the stored seconds are rewritten, so
        // onAppear alone leaves a stale time. Only on disagreement, so a
        // write-back never interrupts typing.
        .onChange(of: seconds) { _, latest in
            let shown = latest.map(SetFormatting.seconds) ?? ""
            if shown != text { text = shown }
        }
    }

    private func judge(_ typed: String, against previous: String) {
        switch NumberRules.duration(typed, isShortening: typed.count < previous.count) {
        case .accepted:
            onOutOfRange(nil)
            let total = elapsed(typed)
            // Written back as the face of the seconds it now holds, so the
            // clock shown can never read as a time the cell does not store.
            text = total.map(SetFormatting.seconds) ?? ""
            onChange(total)
        case .outOfRange:
            onOutOfRange(rangeMessage)
            if NumberRules.movesTowardRange(from: previous, to: typed, { NumberRules.duration($0) }) {
                onChange(elapsed(typed))
            } else {
                text = previous
            }
        case .malformed:
            text = previous
        }
    }

    private func elapsed(_ face: String) -> Int? {
        SetFormatting.secondsFromDigits(face.filter { $0 != ":" })
    }
}

// A record shows what was logged and keeps the prescription muted behind it,
// the way the field it stands in for reads.
private struct LoggedCell: View {
    let value: String?
    let placeholder: String?

    var body: some View {
        Text(value ?? placeholder ?? "")
            .font(.body14)
            .foregroundStyle(value == nil ? Color.onSurfaceMuted : Color.onSurface)
            .multilineTextAlignment(.center)
            .frame(minHeight: setRowHeight)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.extraSmall)
    }
}
