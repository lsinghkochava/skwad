import SwiftUI

struct GlobalDashboardView: View {
    @Environment(AgentManager.self) var agentManager
    @ObservedObject private var settings = AppSettings.shared
    @Binding var forkPrefill: AgentPrefill?
    @State private var sort: DashboardSort = .manual
    @State private var agentToEdit: Agent?
    @State private var now = Date()

    /// Max agent count (+1 for add card) across all workspaces, so all sections share the same grid width.
    private var maxItemCount: Int {
        let counts = agentManager.workspaces.map { workspace in
            workspace.agentIds.filter { id in
                agentManager.agents.contains { $0.id == id && !$0.isCompanion }
            }.count
        }
        return (counts.max() ?? 0) + 1
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header (integrated in window title bar)
            HStack(spacing: 12) {
                HeaderTitleView(title: "All Workspaces")

                Spacer()

                StatusSummaryView(agents: agentManager.agents)
            }
            .frame(height: 32)
            .padding(.leading, 32)
            .padding(.trailing, 16)
            .background(settings.sidebarBackgroundColor)

            // Workspace sections
            GeometryReader { geo in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        ForEach(agentManager.workspaces) { workspace in
                            workspaceSection(workspace)
                        }
                    }
                    .frame(width: DashboardMetrics.gridWidth(for: geo.size.width, itemCount: maxItemCount))
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

    // MARK: - Workspace Section

    private func workspaceSection(_ workspace: Workspace) -> some View {
        let workspaceAgents = sort.sorted(workspace.agentIds.compactMap { id in
            agentManager.agents.first { $0.id == id }
        }.filter { !$0.isCompanion })

        return VStack(alignment: .leading, spacing: 12) {
            // Workspace header with color bar
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(workspace.color)
                    .frame(width: 4, height: 24)

                Button {
                    navigateToWorkspaceDashboard(workspace)
                } label: {
                    Text(workspace.name)
                        .font(.title2.bold())
                        .foregroundColor(Theme.primaryText)
                }
                .buttonStyle(.plain)

                StatusSummaryView(agents: workspaceAgents)

                Spacer()
            }

            // Agent cards grid
            if workspaceAgents.isEmpty {
                Text("No agents")
                    .font(.callout)
                    .foregroundColor(Theme.secondaryText)
                    .padding(.leading, 14)
            } else {
                DashboardAgentGrid(
                    forkPrefill: $forkPrefill,
                    agentToEdit: $agentToEdit,
                    agents: workspaceAgents,
                    now: now,
                    onAgentTap: { agent in navigateToAgent(agent, in: workspace) },
                    onAddAgent: { addAgent(to: workspace) }
                )
            }
        }
    }

    // MARK: - Actions

    private func addAgent(to workspace: Workspace) {
        let folder = workspace.agentIds.compactMap { id in
            agentManager.agents.first { $0.id == id }
        }.first?.folder ?? ""
        forkPrefill = AgentPrefill(name: "", avatar: nil, folder: folder, agentType: "claude", insertAfterId: workspace.agentIds.last)
    }

    // MARK: - Navigation

    private func navigateToWorkspaceDashboard(_ workspace: Workspace) {
        withAnimation(.easeInOut(duration: 0.25)) {
            agentManager.showGlobalDashboard = false
        }
        agentManager.switchToWorkspace(workspace.id)
        agentManager.showDashboard = true
    }

    private func navigateToAgent(_ agent: Agent, in workspace: Workspace) {
        withAnimation(.easeInOut(duration: 0.25)) {
            agentManager.showGlobalDashboard = false
        }
        agentManager.switchToWorkspace(workspace.id)
        agentManager.selectAgent(agent.id)
    }
}

// MARK: - Preview

@MainActor private func previewGlobalDashboardManager() -> AgentManager {
    let m = AgentManager()

    let agents1 = [
        previewDashboardAgent("skwad", "🐱", "/src/skwad", status: .running, title: "Building dashboard", gitStats: .init(insertions: 156, deletions: 12, files: 5)),
        previewDashboardAgent("witsy", "🤖", "/src/witsy", status: .idle, gitStats: .init(insertions: 0, deletions: 0, files: 0)),
    ]
    let agents2 = [
        previewDashboardAgent("api", "🦊", "/src/api", status: .input, title: "Awaiting API key"),
        previewDashboardAgent("docs", "📚", "/src/docs", status: .running, title: "Updating docs", gitStats: .init(insertions: 23, deletions: 5, files: 2)),
        previewDashboardAgent("tests", "🧪", "/src/tests", status: .idle, gitStats: .init(insertions: 8, deletions: 3, files: 1)),
    ]

    m.agents = agents1 + agents2

    let ws1 = Workspace(name: "Skwad", colorHex: WorkspaceColor.blue.rawValue, agentIds: agents1.map { $0.id })
    let ws2 = Workspace(name: "Backend", colorHex: WorkspaceColor.purple.rawValue, agentIds: agents2.map { $0.id })
    m.workspaces = [ws1, ws2]
    m.currentWorkspaceId = ws1.id
    m.showGlobalDashboard = true
    return m
}

#Preview("Global Dashboard") {
    GlobalDashboardView(forkPrefill: .constant(nil))
        .environment(previewGlobalDashboardManager())
        .frame(width: 900, height: 600)
}
