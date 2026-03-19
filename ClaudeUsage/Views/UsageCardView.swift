import SwiftUI

struct UsageCardView: View {
    let title: String
    let window: UsageWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(window.percentage)%")
                    .font(.system(.title2, design: .monospaced, weight: .bold))
                    .foregroundStyle(window.statusColor)
            }

            ProgressView(value: window.normalizedValue)
                .tint(window.statusColor)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)

            if let countdown = window.countdownString {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text("Resets in \(countdown)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
