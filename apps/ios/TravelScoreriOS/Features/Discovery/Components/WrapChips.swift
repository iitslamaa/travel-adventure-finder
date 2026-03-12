import SwiftUI

struct WrapChips: View {
    let countries: [WhenToGoItem]
    let onSelect: (WhenToGoItem) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(countries) { country in
                chip(for: country)
            }
        }
    }

    private func chip(for country: WhenToGoItem) -> some View {
        let score = country.country.score
        let bg = score != nil ? scoreBackground(Double(score!)) : Color.gray.opacity(0.15)

        return Button {
            onSelect(country)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(country.country.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(bg.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
