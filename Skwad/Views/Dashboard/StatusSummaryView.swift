import SwiftUI

struct StatusSummaryView: View {
    let agents: [Agent]

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Self.statusCounts(for: agents), id: \.0) { status, count in
                HStack(spacing: 4) {
                    Circle()
                        .fill(status.color)
                        .frame(width: 8, height: 8)
                    Text("\(count) \(Self.statusLabel(status, count: count))")
                        .font(.body)
                        .foregroundColor(Theme.secondaryText)
                }
            }
        }
    }

    static func statusCounts(for agents: [Agent]) -> [(AgentState, Int)] {
        let nonShell = agents.filter { !$0.isShell }
        let grouped = Dictionary(grouping: nonShell, by: { $0.state })
        let order: [AgentState] = [.input, .running, .idle, .error]
        return order.compactMap { status in
            guard let count = grouped[status]?.count, count > 0 else { return nil }
            return (status, count)
        }
    }

    static func statusLabel(_ status: AgentState, count: Int) -> String {
        switch status {
        case .idle: return "Idle"
        case .running: return "Working"
        case .input: return "Awaiting Input"
        case .error: return count == 1 ? "Error" : "Errors"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        StatusSummaryView(agents: [
            previewDashboardAgent("a", "🤖", "/src/a", status: .running),
            previewDashboardAgent("b", "🐱", "/src/b", status: .running),
            previewDashboardAgent("c", "🦊", "/src/c", status: .idle),
            previewDashboardAgent("d", "🐶", "/src/d", status: .input),
        ])

        StatusSummaryView(agents: [
            previewDashboardAgent("a", "🤖", "/src/a", status: .idle),
            previewDashboardAgent("b", "🐱", "/src/b", status: .idle),
        ])
    }
    .padding()
}
