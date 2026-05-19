import SwiftUI

struct OperatorCard: View {
    let item: OperatorItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.type.symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: item.pinned ? "pin.fill" : "pin.slash")
                        .font(.caption)
                        .foregroundStyle(item.pinned ? Color.red : Color.secondary)
                        .accessibilityLabel(item.pinned ? "Pinned" : "Not pinned")
                }

                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(item.type.label)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.thinMaterial, in: Capsule())
                    Text(item.status.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let due = item.dueDate {
                        Spacer()
                        Text(due, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
    }
}
