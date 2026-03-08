import XCTest
@testable import Skwad

final class MCPToolHandlerTests: XCTestCase {

    private var coordinator: AgentCoordinator!
    private var handler: MCPToolHandler!

    override func setUp() async throws {
        coordinator = AgentCoordinator.shared
        handler = MCPToolHandler(mcpService: coordinator)
    }

    // MARK: - Tool Registration

    func testViewMermaidToolIsRegistered() async {
        let tools = await handler.listTools()
        let toolNames = tools.map { $0.name }
        XCTAssertTrue(toolNames.contains("view-mermaid"))
    }

    func testViewMermaidToolHasCorrectSchema() async {
        let tools = await handler.listTools()
        let tool = tools.first { $0.name == "view-mermaid" }!

        let properties = tool.inputSchema.properties
        XCTAssertNotNil(properties["agentId"])
        XCTAssertNotNil(properties["source"])
        XCTAssertNotNil(properties["title"])

        let required = tool.inputSchema.required
        XCTAssertTrue(required.contains("agentId"))
        XCTAssertTrue(required.contains("source"))
        XCTAssertFalse(required.contains("title"))
    }

    // MARK: - view-mermaid Argument Validation

    func testViewMermaidMissingAgentId() async {
        let result = await handler.callTool(name: "view-mermaid", arguments: [
            "source": "graph TD; A-->B;"
        ])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(result.content[0].text.contains("agentId"))
    }

    func testViewMermaidMissingSource() async {
        let result = await handler.callTool(name: "view-mermaid", arguments: [
            "agentId": UUID().uuidString
        ])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(result.content[0].text.contains("source"))
    }

    func testViewMermaidUnknownAgent() async {
        let (provider, _) = MockAgentDataProvider.createTestSetup(agentCount: 1)
        await coordinator.setAgentDataProvider(provider)

        let result = await handler.callTool(name: "view-mermaid", arguments: [
            "agentId": UUID().uuidString,
            "source": "graph TD; A-->B;"
        ])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(result.content[0].text.contains("not found"))
    }

    func testViewMermaidSuccess() async {
        let (provider, _) = MockAgentDataProvider.createTestSetup(agentCount: 1)
        await coordinator.setAgentDataProvider(provider)

        let agents = await provider.getAgents()
        let agentId = agents[0].id.uuidString

        let result = await handler.callTool(name: "view-mermaid", arguments: [
            "agentId": agentId,
            "source": "graph TD; A-->B;"
        ])
        XCTAssertEqual(result.isError, false)
        XCTAssertTrue(result.content[0].text.contains("success"))
    }

    func testViewMermaidWithTitle() async {
        let (provider, _) = MockAgentDataProvider.createTestSetup(agentCount: 1)
        await coordinator.setAgentDataProvider(provider)

        let agents = await provider.getAgents()
        let agentId = agents[0].id.uuidString

        let result = await handler.callTool(name: "view-mermaid", arguments: [
            "agentId": agentId,
            "source": "graph TD; A-->B;",
            "title": "My Diagram"
        ])
        XCTAssertEqual(result.isError, false)
    }

    // MARK: - Unknown Tool

    func testUnknownToolReturnsError() async {
        let result = await handler.callTool(name: "nonexistent-tool", arguments: [:])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(result.content[0].text.contains("Unknown tool"))
    }

    // MARK: - create-agent Tool

    func testCreateAgentToolHasPersonaIdParam() async {
        let tools = await handler.listTools()
        let tool = tools.first { $0.name == "create-agent" }!
        XCTAssertNotNil(tool.inputSchema.properties["personaId"])
    }

    @MainActor
    func testCreateAgentDescriptionIncludesPersonas() async {
        let settings = AppSettings.shared
        let originalPersonas = settings.personas

        let persona = settings.addPersona(name: "TDD Expert", instructions: "Follow TDD")
        let tools = await handler.listTools()
        let tool = tools.first { $0.name == "create-agent" }!

        XCTAssertTrue(tool.description.contains("TDD Expert"))
        XCTAssertTrue(tool.description.contains(persona.id.uuidString))

        settings.personas = originalPersonas
    }

    @MainActor
    func testCreateAgentDescriptionOmitsPersonasWhenEmpty() async {
        let settings = AppSettings.shared
        let originalPersonas = settings.personas

        settings.personas = []
        let tools = await handler.listTools()
        let tool = tools.first { $0.name == "create-agent" }!

        XCTAssertFalse(tool.description.contains("Available personas"))

        settings.personas = originalPersonas
    }

    func testCreateAgentMissingAgentId() async {
        let result = await handler.callTool(name: "create-agent", arguments: [
            "name": "Test",
            "agentType": "claude",
            "repoPath": "/tmp"
        ])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(result.content[0].text.contains("agentId"))
    }

    func testCreateAgentMissingRequiredParamsWithoutBench() async {
        let (provider, _) = MockAgentDataProvider.createTestSetup(agentCount: 1)
        await coordinator.setAgentDataProvider(provider)
        let agents = await provider.getAgents()

        let result = await handler.callTool(name: "create-agent", arguments: [
            "agentId": agents[0].id.uuidString
        ])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(result.content[0].text.contains("name"))
        XCTAssertTrue(result.content[0].text.contains("agentType"))
        XCTAssertTrue(result.content[0].text.contains("repoPath"))
        XCTAssertTrue(result.content[0].text.contains("benchAgentId"))
    }

    func testCreateAgentMissingPartialParams() async {
        let (provider, _) = MockAgentDataProvider.createTestSetup(agentCount: 1)
        await coordinator.setAgentDataProvider(provider)
        let agents = await provider.getAgents()

        let result = await handler.callTool(name: "create-agent", arguments: [
            "agentId": agents[0].id.uuidString,
            "name": "Test"
        ])
        XCTAssertEqual(result.isError, true)
        XCTAssertFalse(result.content[0].text.contains("name"))
        XCTAssertTrue(result.content[0].text.contains("agentType"))
        XCTAssertTrue(result.content[0].text.contains("repoPath"))
    }

    @MainActor
    func testCreateAgentWithBenchAgentId() async {
        let settings = AppSettings.shared
        let originalBench = settings.benchAgents

        // Set up bench agent
        settings.benchAgents = [BenchAgent(name: "BenchBot", avatar: "🤖", folder: "/tmp", agentType: "claude")]
        let benchAgentId = settings.benchAgents.first!.id

        let (provider, _) = MockAgentDataProvider.createTestSetup(agentCount: 1)
        await coordinator.setAgentDataProvider(provider)
        let agents = await provider.getAgents()

        let result = await handler.callTool(name: "create-agent", arguments: [
            "agentId": agents[0].id.uuidString,
            "benchAgentId": benchAgentId.uuidString
        ])
        XCTAssertEqual(result.isError, false)

        let allAgents = await provider.getAgents()
        let created = allAgents.first { $0.name == "BenchBot" }
        XCTAssertNotNil(created)
        XCTAssertEqual(created?.folder, "/tmp")
        XCTAssertEqual(created?.agentType, "claude")

        settings.benchAgents = originalBench
    }

    @MainActor
    func testCreateAgentWithBenchAgentOverrides() async {
        let settings = AppSettings.shared
        let originalBench = settings.benchAgents

        settings.benchAgents = [BenchAgent(name: "BenchBot", avatar: "🤖", folder: "/tmp", agentType: "claude")]
        let benchAgentId = settings.benchAgents.first!.id

        let (provider, _) = MockAgentDataProvider.createTestSetup(agentCount: 1)
        await coordinator.setAgentDataProvider(provider)
        let agents = await provider.getAgents()

        let result = await handler.callTool(name: "create-agent", arguments: [
            "agentId": agents[0].id.uuidString,
            "benchAgentId": benchAgentId.uuidString,
            "name": "CustomName"
        ])
        XCTAssertEqual(result.isError, false)

        let allAgents = await provider.getAgents()
        let created = allAgents.first { $0.name == "CustomName" }
        XCTAssertNotNil(created)
        XCTAssertEqual(created?.folder, "/tmp") // from bench
        XCTAssertEqual(created?.agentType, "claude") // from bench

        settings.benchAgents = originalBench
    }

    func testCreateAgentWithInvalidBenchAgentId() async {
        let (provider, _) = MockAgentDataProvider.createTestSetup(agentCount: 1)
        await coordinator.setAgentDataProvider(provider)
        let agents = await provider.getAgents()

        let result = await handler.callTool(name: "create-agent", arguments: [
            "agentId": agents[0].id.uuidString,
            "benchAgentId": UUID().uuidString
        ])
        XCTAssertEqual(result.isError, true)
        XCTAssertTrue(result.content[0].text.contains("Bench agent not found"))
    }

    @MainActor
    func testCreateAgentDescriptionIncludesBenchAgents() async {
        let settings = AppSettings.shared
        let originalBench = settings.benchAgents

        settings.benchAgents = [BenchAgent(name: "MyBot", avatar: "🤖", folder: "/tmp", agentType: "codex")]
        let tools = await handler.listTools()
        let tool = tools.first { $0.name == "create-agent" }!

        XCTAssertTrue(tool.description.contains("MyBot"))
        XCTAssertTrue(tool.description.contains("codex"))
        XCTAssertNotNil(tool.inputSchema.properties["benchAgentId"])

        settings.benchAgents = originalBench
    }

    func testCreateAgentWithPersonaIdPassesThrough() async {
        let (provider, _) = MockAgentDataProvider.createTestSetup(agentCount: 1)
        await coordinator.setAgentDataProvider(provider)

        let agents = await provider.getAgents()
        let agentId = agents[0].id.uuidString
        let personaId = UUID()

        let result = await handler.callTool(name: "create-agent", arguments: [
            "agentId": agentId,
            "name": "TestAgent",
            "agentType": "claude",
            "repoPath": "/tmp",
            "personaId": personaId.uuidString
        ])

        XCTAssertEqual(result.isError, false)

        // Verify the agent was created with the personaId
        let allAgents = await provider.getAgents()
        let created = allAgents.first { $0.name == "TestAgent" }
        XCTAssertNotNil(created)
        XCTAssertEqual(created?.personaId, personaId)
    }
}
