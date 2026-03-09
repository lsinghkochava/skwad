import SwiftUI

struct AddAgentCardView: View {
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "plus.circle")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(Theme.secondaryText.opacity(isHovered ? 0.8 : 0.5))
            Text("Add Agent")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Theme.secondaryText.opacity(isHovered ? 0.8 : 0.5))
            Spacer()
        }
        .frame(minHeight: 160)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(isHovered ? 0.03 : 0.01))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    Color.primary.opacity(isHovered ? 0.15 : 0.10),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            onTap()
        }
    }
}
