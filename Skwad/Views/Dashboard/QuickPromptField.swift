import SwiftUI

struct QuickPromptField: View {
    let agent: Agent
    let onSend: (String) -> Void
    let onSendAndSwitch: (String) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var isDisabled: Bool {
        agent.state == .running
    }

    var body: some View {
        HStack(spacing: 6) {
            TextField(isDisabled ? "Working..." : "Send prompt...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFocused)
                .disabled(isDisabled)
                .onSubmit {
                    send(andSwitch: false)
                }
                .onKeyPress(.return, phases: .down) { press in
                    if press.modifiers.contains(.command) {
                        send(andSwitch: true)
                        return .handled
                    }
                    return .ignored
                }

            if !text.isEmpty {
                Button {
                    send(andSwitch: false)
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.callout)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Send (⏎) · Send & Go (⌘⏎)")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(isDisabled ? 0.02 : 0.06))
        .cornerRadius(6)
        .opacity(isDisabled ? 0.5 : 1)
    }

    private func send(andSwitch: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if andSwitch {
            onSendAndSwitch(trimmed)
        } else {
            onSend(trimmed)
        }
        text = ""
    }
}

#Preview {
    VStack(spacing: 12) {
        QuickPromptField(
            agent: previewDashboardAgent("idle-agent", "🤖", "/src/project", status: .idle),
            onSend: { _ in },
            onSendAndSwitch: { _ in }
        )
        QuickPromptField(
            agent: previewDashboardAgent("busy-agent", "🐱", "/src/project", status: .running),
            onSend: { _ in },
            onSendAndSwitch: { _ in }
        )
    }
    .padding()
    .frame(width: 280)
}
