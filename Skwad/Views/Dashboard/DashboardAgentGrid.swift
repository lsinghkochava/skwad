import SwiftUI

/// Pure agent card grid used by both GlobalDashboardView and WorkspaceDashboardView.
/// Sort, timer, edit sheet, and sort picker are owned by the parent dashboard view.
struct DashboardAgentGrid: View {
    @Environment(AgentManager.self) var agentManager
    @ObservedObject private var settings = AppSettings.shared
    @Binding var forkPrefill: AgentPrefill?
    @Binding var agentToEdit: Agent?

    let agents: [Agent]
    let now: Date
    let onAgentTap: (Agent) -> Void
    let onAddAgent: () -> Void

    @State private var availableWidth: CGFloat = 0

    private var showAddCard: Bool {
        let cardWidth = DashboardMetrics.cardWidth
        let spacing = DashboardMetrics.gridSpacing
        let columns = max(1, Int((availableWidth + spacing) / (cardWidth + spacing)))
        return agents.count % columns != 0
    }

    var body: some View {
        LazyVGrid(columns: DashboardMetrics.gridColumns, alignment: .leading, spacing: DashboardMetrics.gridSpacing) {
            ForEach(agents) { agent in
                AgentContextMenu(
                    agent: agent,
                    onEdit: { agentToEdit = agent },
                    onFork: { forkPrefill = agent.forkPrefill() },
                    onNewCompanion: { forkPrefill = agent.companionPrefill() },
                    onShellCompanion: { agentManager.createShellCompanion(for: agent) },
                    onSaveToBench: { settings.addToBench(agent) }
                ) {
                    AgentCardView(
                        agent: agent,
                        onTap: { onAgentTap(agent) },
                        onSend: { text in
                            agentManager.injectText(text, for: agent.id)
                        },
                        onSendAndSwitch: { text in
                            agentManager.injectText(text, for: agent.id)
                            onAgentTap(agent)
                        },
                        now: now
                    )
                }
            }

            if showAddCard {
                AddAgentCardView(onTap: onAddAgent)
            }
        }
        .background(GeometryReader { geo in
            Color.clear.onAppear { availableWidth = geo.size.width }
                .onChange(of: geo.size.width) { _, newValue in availableWidth = newValue }
        })
    }
}
