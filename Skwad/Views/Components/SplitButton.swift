import SwiftUI

/// A split button with a primary action on the left and a dropdown chevron on the right.
/// The chevron presents arbitrary popover content.
struct SplitButton<PopoverContent: View>: View {
    let title: String
    let height: CGFloat
    let action: () -> Void
    @ViewBuilder let popoverContent: () -> PopoverContent

    @State private var showPopover = false

    init(
        _ title: String,
        height: CGFloat = 38,
        action: @escaping () -> Void,
        @ViewBuilder popover: @escaping () -> PopoverContent
    ) {
        self.title = title
        self.height = height
        self.action = action
        self.popoverContent = popover
    }

    var body: some View {
        HStack(spacing: 0) {
            // Main button
            Button {
                action()
            } label: {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .background(Color.accentColor)

            // Separator
            Rectangle()
                .fill(Color.black.opacity(0.2))
                .frame(width: 1, height: height)

            // Chevron button
            Button {
                showPopover.toggle()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: height)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color.accentColor)
            .popover(isPresented: $showPopover) {
                popoverContent()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
