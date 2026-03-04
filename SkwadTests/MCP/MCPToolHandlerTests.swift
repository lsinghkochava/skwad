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
