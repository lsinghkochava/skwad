import Testing
import SwiftUI
@testable import Skwad

@Suite("Dashboard", .serialized)
struct DashboardTests {

    // MARK: - Test Helpers

    @MainActor
    static func setupManager(agentCount: Int) -> AgentManager {
        let manager = AgentManager()
        manager.agents = []
        manager.workspaces = []
        manager.currentWorkspaceId = nil

        let agents = (0..<agentCount).map { i in
            Agent(name: "Agent\(i)", avatar: "🤖", folder: "/tmp/test/agent\(i)")
        }
        manager.agents = agents
        let workspace = Workspace(
            name: "Test",
            colorHex: WorkspaceColor.blue.rawValue,
            agentIds: agents.map { $0.id },
            activeAgentIds: agents.isEmpty ? [] : [agents[0].id]
        )
        manager.workspaces = [workspace]
        manager.currentWorkspaceId = workspace.id
        return manager
    }

    // MARK: - lastStatusChange

    @Suite("lastStatusChange")
    struct LastStatusChangeTests {

        @Test("lastStatusChange is updated when status changes")
        @MainActor
        func lastStatusChangeUpdated() async {
            let manager = DashboardTests.setupManager(agentCount: 1)
            let agentId = manager.agents[0].id
            let initialDate = manager.agents[0].lastStatusChange

            // Small delay to ensure date differs
            try? await Task.sleep(for: .milliseconds(10))
            manager.updateStatus(for: agentId, status: .running)

            #expect(manager.agents[0].lastStatusChange > initialDate)
        }

        @Test("lastStatusChange not updated when status unchanged")
        @MainActor
        func lastStatusChangeNotUpdatedWhenSame() async {
            let manager = DashboardTests.setupManager(agentCount: 1)
            let agentId = manager.agents[0].id
            // Agent starts as .idle
            let initialDate = manager.agents[0].lastStatusChange

            try? await Task.sleep(for: .milliseconds(10))
            manager.updateStatus(for: agentId, status: .idle)

            #expect(manager.agents[0].lastStatusChange == initialDate)
        }
    }

    // MARK: - showDashboard

    @Suite("Workspace Dashboard State")
    struct WorkspaceDashboardStateTests {

        @Test("showDashboard defaults to false")
        @MainActor
        func showDashboardDefaultsFalse() {
            let manager = DashboardTests.setupManager(agentCount: 1)
            #expect(manager.showDashboard == false)
        }

        @Test("showDashboard can be toggled")
        @MainActor
        func showDashboardToggle() {
            let manager = DashboardTests.setupManager(agentCount: 1)
            manager.showDashboard = true
            #expect(manager.showDashboard == true)
            manager.showDashboard = false
            #expect(manager.showDashboard == false)
        }

        @Test("showDashboard persisted per workspace")
        @MainActor
        func showDashboardPerWorkspace() {
            let manager = DashboardTests.setupManager(agentCount: 1)

            // Create second workspace
            let ws2 = manager.addWorkspace(name: "Second")
            manager.switchToWorkspace(ws2.id)

            // Set dashboard on ws2
            manager.showDashboard = true
            #expect(manager.showDashboard == true)

            // Switch back to ws1 — should be false
            manager.switchToWorkspace(manager.workspaces[0].id)
            #expect(manager.showDashboard == false)

            // Switch to ws2 — should still be true
            manager.switchToWorkspace(ws2.id)
            #expect(manager.showDashboard == true)
        }
    }

    // MARK: - showGlobalDashboard

    @Suite("Global Dashboard State")
    struct GlobalDashboardStateTests {

        @Test("showGlobalDashboard defaults to false")
        @MainActor
        func showGlobalDashboardDefaultsFalse() {
            let manager = DashboardTests.setupManager(agentCount: 1)
            #expect(manager.showGlobalDashboard == false)
        }

        @Test("showGlobalDashboard can be toggled")
        @MainActor
        func showGlobalDashboardToggle() {
            let manager = DashboardTests.setupManager(agentCount: 1)
            manager.showGlobalDashboard = true
            #expect(manager.showGlobalDashboard == true)
        }
    }

    // MARK: - Workspace.isDashboardVisible

    @Suite("Workspace Dashboard Migration")
    struct WorkspaceDashboardMigrationTests {

        @Test("isDashboardVisible defaults to false when showDashboard is nil")
        func isDashboardVisibleDefaultsFalse() {
            let workspace = Workspace(name: "Test", colorHex: WorkspaceColor.blue.rawValue)
            #expect(workspace.isDashboardVisible == false)
        }

        @Test("isDashboardVisible reflects showDashboard value")
        func isDashboardVisibleReflectsValue() {
            var workspace = Workspace(name: "Test", colorHex: WorkspaceColor.blue.rawValue, showDashboard: true)
            #expect(workspace.isDashboardVisible == true)
            workspace.isDashboardVisible = false
            #expect(workspace.isDashboardVisible == false)
        }
    }

    // MARK: - DashboardSort

    @Suite("DashboardSort")
    struct DashboardSortTests {

        @Test("manual sort preserves original order")
        func manualSortPreservesOrder() {
            var a1 = Agent(name: "Alpha", avatar: "🤖", folder: "/tmp/a")
            var a2 = Agent(name: "Beta", avatar: "🤖", folder: "/tmp/b")
            a1.lastStatusChange = Date().addingTimeInterval(-100)
            a2.lastStatusChange = Date()

            let sorted = DashboardSort.manual.sorted([a1, a2])
            #expect(sorted.map(\.name) == ["Alpha", "Beta"])
        }

        @Test("activity sort orders by most recent status change")
        func activitySortByRecent() {
            var a1 = Agent(name: "Old", avatar: "🤖", folder: "/tmp/a")
            var a2 = Agent(name: "Recent", avatar: "🤖", folder: "/tmp/b")
            a1.lastStatusChange = Date().addingTimeInterval(-100)
            a2.lastStatusChange = Date()

            let sorted = DashboardSort.activity.sorted([a1, a2])
            #expect(sorted.map(\.name) == ["Recent", "Old"])
        }
    }

    // MARK: - idleDuration

    @Suite("Idle Duration Formatting")
    struct IdleDurationTests {

        @Test("shows less than 1 minute for 0 seconds")
        func zeroSeconds() {
            let now = Date()
            #expect(DashboardMetrics.idleDuration(since: now, now: now) == "< 1 minute ago")
        }

        @Test("shows less than 1 minute for 59 seconds")
        func fiftyNineSeconds() {
            let now = Date()
            let since = now.addingTimeInterval(-59)
            #expect(DashboardMetrics.idleDuration(since: since, now: now) == "< 1 minute ago")
        }

        @Test("shows singular minute for 60 seconds")
        func sixtySeconds() {
            let now = Date()
            let since = now.addingTimeInterval(-60)
            #expect(DashboardMetrics.idleDuration(since: since, now: now) == "1 minute ago")
        }

        @Test("shows plural minutes for 120 seconds")
        func twoMinutes() {
            let now = Date()
            let since = now.addingTimeInterval(-120)
            #expect(DashboardMetrics.idleDuration(since: since, now: now) == "2 minutes ago")
        }
    }

    // MARK: - StatusSummaryView

    @Suite("Status Summary")
    struct StatusSummaryTests {

        @Test("excludes shell agents")
        func excludesShellAgents() {
            var shell = Agent(name: "Shell", avatar: "🐚", folder: "/tmp/s")
            shell.isShell = true
            shell.state = .running
            var normal = Agent(name: "Normal", avatar: "🤖", folder: "/tmp/n")
            normal.state = .running

            let counts = StatusSummaryView.statusCounts(for: [shell, normal])
            #expect(counts.count == 1)
            #expect(counts[0].1 == 1)
        }

        @Test("orders by priority: input, running, idle, error")
        func ordersByPriority() {
            var idle = Agent(name: "A", avatar: "🤖", folder: "/tmp/a")
            idle.state = .idle
            var running = Agent(name: "B", avatar: "🤖", folder: "/tmp/b")
            running.state = .running
            var input = Agent(name: "C", avatar: "🤖", folder: "/tmp/c")
            input.state = .input
            var error = Agent(name: "D", avatar: "🤖", folder: "/tmp/d")
            error.state = .error

            let counts = StatusSummaryView.statusCounts(for: [idle, running, input, error])
            #expect(counts.map(\.0) == [.input, .running, .idle, .error])
        }

        @Test("omits states with zero agents")
        func omitsZeroCounts() {
            var a = Agent(name: "A", avatar: "🤖", folder: "/tmp/a")
            a.state = .idle
            var b = Agent(name: "B", avatar: "🤖", folder: "/tmp/b")
            b.state = .idle

            let counts = StatusSummaryView.statusCounts(for: [a, b])
            #expect(counts.count == 1)
            #expect(counts[0].0 == .idle)
            #expect(counts[0].1 == 2)
        }

        @Test("empty agents returns empty counts")
        func emptyAgents() {
            let counts = StatusSummaryView.statusCounts(for: [])
            #expect(counts.isEmpty)
        }

        @Test("statusLabel returns correct labels")
        func statusLabels() {
            #expect(StatusSummaryView.statusLabel(.idle, count: 1) == "Idle")
            #expect(StatusSummaryView.statusLabel(.running, count: 1) == "Working")
            #expect(StatusSummaryView.statusLabel(.input, count: 1) == "Awaiting Input")
            #expect(StatusSummaryView.statusLabel(.input, count: 3) == "Awaiting Input")
            #expect(StatusSummaryView.statusLabel(.error, count: 1) == "Error")
            #expect(StatusSummaryView.statusLabel(.error, count: 2) == "Errors")
        }
    }

    // MARK: - setAgentStatusText

    @Suite("Agent Status Text")
    struct AgentStatusTextTests {

        @Test("setAgentStatusText updates agent status string")
        @MainActor
        func setAgentStatusText() {
            let manager = DashboardTests.setupManager(agentCount: 1)
            let agentId = manager.agents[0].id

            manager.setAgentStatusText(for: agentId, status: "Implementing auth module")
            #expect(manager.agents[0].statusText == "Implementing auth module")
        }

        @Test("setAgentStatusText can clear status with empty string")
        @MainActor
        func clearAgentStatusText() {
            let manager = DashboardTests.setupManager(agentCount: 1)
            let agentId = manager.agents[0].id

            manager.setAgentStatusText(for: agentId, status: "Working")
            manager.setAgentStatusText(for: agentId, status: "")
            #expect(manager.agents[0].statusText == "")
        }

        @Test("setAgentStatusText via MockAgentDataProvider")
        func setAgentStatusViaProvider() async {
            let provider = MockAgentDataProvider()
            let agent = Agent(name: "Test", avatar: "🤖", folder: "/tmp/test")
            await provider.addAgent(agent)

            await provider.setAgentStatus(for: agent.id, status: "Running tests")

            let updated = await provider.getAgent(id: agent.id)
            #expect(updated?.statusText == "Running tests")
        }
    }
}
