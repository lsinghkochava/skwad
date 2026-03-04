# Personas Feature

## Overview

Personas are named instruction sets appended to the system prompt of compatible agents (Claude, Codex). They shape agent behavior (e.g. "Kent Beck TDD Expert", "Security Auditor") without changing the underlying skwad registration prompt.

## Design Decisions

- Per-agent persona selection (at creation time only, not editable after)
- Global persona list stored in AppSettings (like BenchAgents)
- Persona management UI in a dedicated "Personas" settings tab
- MCP: new `list-personas` tool + `personaId` param on `create-agent`
- Default/bundled personas deferred to later

## Implementation Phases

### Phase 1: Data Model & Persistence
- [x] Add `Persona` struct to `AppSettings.swift` (Codable, Identifiable, Equatable: id, name, instructions)
- [x] Add `personasData` @AppStorage + computed `personas` property + CRUD helpers
- [x] Add `personaId: UUID?` to `Agent` struct (CodingKeys, init(from:), inits)
- [x] Add `personaId: UUID?` to `SavedAgent` struct (CodingKeys, init(from:), init)
- [x] Update `AgentManager.addAgent()` to accept `personaId`
- [x] Update `saveAgents()` and `loadSavedAgents()` to include `personaId`

### Phase 2: System Prompt Injection
- [x] Add `personaInstructions: String?` param to `TerminalCommandBuilder.buildAgentCommand()`
- [x] Append persona instructions after registration system prompt in `getInlineRegistrationArguments()`
- [x] Add `personaInstructions: String?` to `TerminalSessionController` init + stored property
- [x] Pass through `buildCommand()` → `buildAgentCommand()`
- [x] Resolve persona in `AgentManager` when creating controller, pass instructions

### Phase 3: Settings UI — Persona Management
- [x] Create `PersonaSheet.swift` (name TextField + instructions TextEditor)
- [x] Create `PersonasSettingsView.swift` as dedicated settings tab
- [x] Add `personas` tab to `SettingsView` enum and TabView

### Phase 4: AgentSheet — Persona Picker
- [x] Add persona Picker to `AgentSheet` (shown when `supportsSystemPrompt` is true and personas exist)
- [x] Wire selected `personaId` through to `agentManager.addAgent()`
- [x] Dynamic sheet height adjustment for persona picker

### Phase 5: MCP Tools
- [x] Add `listPersonas` to `MCPToolName` enum
- [x] Add `PersonaInfoResponse` + `ListPersonasResponse` structs to `MCPTypes.swift`
- [x] Add `list-personas` tool definition + handler in `MCPTools.swift`
- [x] Add `personaId` param to `create-agent` tool schema
- [x] Thread `personaId` through `handleCreateAgent` → `AgentCoordinator.createAgent()` → `AgentDataProvider.addAgent()`
- [x] Update `MockAgentDataProvider` for tests

### Phase 6: Tests
- [x] Test persona CRUD in AppSettings
- [x] Test SavedAgent round-trip with personaId
- [x] Test Agent decoding migration (old format without personaId)
- [x] Test TerminalCommandBuilder with persona instructions (Claude + Codex)
- [x] Test nil persona doesn't alter prompt
- [x] Test persona ignored when MCP disabled

## Files Modified

| File | Phase |
|------|-------|
| `AppSettings.swift` | 1 |
| `Agent.swift` | 1 |
| `AgentManager.swift` | 1, 2 |
| `TerminalCommandBuilder.swift` | 2 |
| `TerminalSessionController.swift` | 2 |
| `PersonaSheet.swift` (new) | 3 |
| `PersonasSettingsView.swift` (new) | 3 |
| `SettingsView.swift` | 3 |
| `AgentSheet.swift` | 4 |
| `MCPTypes.swift` | 5 |
| `MCPTools.swift` | 5 |
| `AgentCoordinator.swift` | 5 |
| `MockAgentDataProvider.swift` | 5 |
| `AppSettingsTests.swift` | 6 |
| `TerminalCommandBuilderTests.swift` | 6 |

## Key Learnings

- Xcode project uses explicit file references (pbxproj) — new files must be added to the project manually
- The `onChange` modifier for optional types needs `Equatable` conformance on the type
- Persona instructions are appended to the skwad registration system prompt with a space separator — they compose cleanly without requiring separate CLI arguments
- The `AgentDataProvider` protocol acts as the async bridge between MCP actor and MainActor — any new param on `addAgent` must be threaded through protocol → wrapper → manager
