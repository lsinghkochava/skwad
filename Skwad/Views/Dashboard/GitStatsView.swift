import SwiftUI

/// Reusable view for displaying git insertion/deletion stats.
/// Used in both AgentCardView (dashboard) and AgentFullHeader (terminal).
struct GitStatsView: View {
    let stats: GitLineStats
    var font: Font = .callout
    var monospaced: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            if stats.insertions == 0 && stats.deletions == 0 {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.green.opacity(0.7))
                    Text("No changes")
                        .font(font)
                        .foregroundColor(Theme.secondaryText)
                }
            } else {
                if stats.insertions > 0 {
                    Text("+\(stats.insertions)")
                        .font(monospaced ? font.monospaced() : font)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
                if stats.deletions > 0 {
                    Text("-\(stats.deletions)")
                        .font(monospaced ? font.monospaced() : font)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                }
                Text("\(stats.files) file\(stats.files == 1 ? "" : "s")")
                    .font(font)
                    .foregroundColor(Theme.secondaryText)
            }
        }
    }
}
