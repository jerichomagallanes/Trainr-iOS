import SwiftUI

struct PlanCard: View {
    let term: String
    let price: String
    let billing: String
    let saved: Int?
    var trial: String?
    let isSelected: Bool
    var stacked = false
    let onSelect: () -> Void

    private var ink: Color { isSelected ? .onSurfaceSelected : .onSurface }
    private var subdued: Color { isSelected ? .onSurfaceSelected : .onSurfaceMuted }

    // The trial takes the strip where there is one, and the saving moves down
    // beside the billing term rather than disappearing.
    private var banner: String? {
        if let trial { return L10n.proTrialBadge(trial) }
        if let saved { return L10n.proSavePercent(saved) }
        return nil
    }

    private var bills: String {
        guard trial != nil, let saved else { return billing }
        return L10n.proBilledWithSaving(billing, saved)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 0) {
                if let banner {
                    Text(banner)
                        .font(.body12)
                        .foregroundStyle(Color.onBrand)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                        .background(Color.brandLarge)
                }
                if stacked { spread } else { stack }
            }
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.surfaceSelected : Color.surfaceCard)
            .clipShape(.rect(cornerRadius: CornerRadius.medium))
            .overlay {
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .strokeBorder(
                        isSelected ? Color.brandLarge : Color.outlineControl, lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var stack: some View {
        VStack(spacing: 2) {
            Text(term).font(.labelMedium).foregroundStyle(ink)
            Text(price).font(.sectionTitle).foregroundStyle(ink)
            Text(bills).font(.body12).foregroundStyle(subdued)
        }
        .padding(.vertical, Spacing.small)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity)
    }

    // The price shares the line while the term and what it bills still have
    // room for their own words on it, and takes a line of its own once they do
    // not: a term cut mid-word is a plan the screen has not stated, and the
    // price is the one thing on the card that may not be cut at all.
    private var spread: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.small) {
                terms
                Spacer(minLength: Spacing.small)
                amount
            }
            VStack(alignment: .leading, spacing: 2) {
                terms
                amount
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, Spacing.small)
        .padding(.horizontal, Spacing.card)
    }

    private var terms: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(term).font(.labelMedium).foregroundStyle(ink)
            Text(bills).font(.body12).foregroundStyle(subdued)
        }
    }

    private var amount: some View {
        Text(price).font(.sectionTitle).foregroundStyle(ink)
    }
}
