import SwiftUI

struct WorkspaceDashboardView: View {
    @Environment(AgentManager.self) var agentManager
    @ObservedObject private var settings = AppSettings.shared
    @Binding var forkPrefill: AgentPrefill?
    @State private var sort: DashboardSort = .manual
    @State private var agentToEdit: Agent?
    @State private var now = Date()

    private var agents: [Agent] {
        sort.sorted(agentManager.currentWorkspaceAgents.filter { !$0.isCompanion })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header (integrated in window title bar)
            HStack(spacing: 12) {
                HeaderTitleView(title: agentManager.currentWorkspace?.name ?? "Workspace")

                Spacer()

                StatusSummaryView(agents: agentManager.currentWorkspaceAgents)
            }
            .frame(height: 32)
            .padding(.leading, 32)
            .padding(.trailing, 16)
            .background(settings.sidebarBackgroundColor)

            // Card grid
            GeometryReader { geo in
                ScrollView {
                    DashboardAgentGrid(
                        forkPrefill: $forkPrefill,
                        agentToEdit: $agentToEdit,
                        agents: agents,
                        now: now,
                        onAgentTap: { agent in navigateToAgent(agent) },
                        onAddAgent: { addAgent() }
                    )
                    .frame(width: DashboardMetrics.gridWidth(for: geo.size.width, itemCount: agents.count + 1))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 64)
                    .padding(.bottom, 24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(settings.effectiveBackgroundColor)
        .overlay(alignment: .topTrailing) {
            DashboardSortPicker(sort: $sort)
                .padding(.top, 40)
                .padding(.trailing, 16)
        }
        .sheet(item: $agentToEdit) { agent in
            AgentSheet(editing: agent)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            now = Date()
        }
    }

    // MARK: - Actions

    private func addAgent() {
        let folder = agents.first?.folder ?? ""
        let lastAgentId = agentManager.currentWorkspace?.agentIds.last
        forkPrefill = AgentPrefill(name: "", avatar: nil, folder: folder, agentType: "claude", insertAfterId: lastAgentId)
    }

    private func navigateToAgent(_ agent: Agent) {
        agentManager.selectAgent(agent.id)
        withAnimation(.easeInOut(duration: 0.25)) {
            agentManager.showDashboard = false
        }
    }
}

// MARK: - Preview

@MainActor private func previewDashboardManager() -> AgentManager {
    let m = AgentManager()
    let agents = [
        previewDashboardAgent("skwad", "🐱", "/Users/nbonamy/src/skwad", status: .running, title: "Implementing dashboard views", gitStats: .init(insertions: 156, deletions: 12, files: 5)),
        previewDashboardAgent("witsy", "🤖", "/Users/nbonamy/src/witsy", status: .idle, gitStats: .init(insertions: 0, deletions: 0, files: 0)),
        previewDashboardAgent("api", "🦊", "/Users/nbonamy/src/api", status: .input, title: "Awaiting API key"),
        previewDashboardAgent("docs", "📚", "/Users/nbonamy/src/docs", status: .running, title: "Updating README.md", gitStats: .init(insertions: 23, deletions: 5, files: 2)),
        previewDashboardAgent("tests", "🧪", "/Users/nbonamy/src/tests", status: .idle, gitStats: .init(insertions: 8, deletions: 3, files: 1)),
    ]
    m.agents = agents
    let workspace = Workspace(name: "My Project", colorHex: WorkspaceColor.purple.rawValue, agentIds: agents.map { $0.id })
    m.workspaces = [workspace]
    m.currentWorkspaceId = workspace.id
    m.activeAgentIds = [agents[0].id]
    return m
}

#Preview("Workspace Dashboard") {
    WorkspaceDashboardView(forkPrefill: .constant(nil))
        .environment(previewDashboardManager())
        .frame(width: 900, height: 600)
}
