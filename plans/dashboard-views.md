# Dashboard Views (Global & Workspace)

## Vision

Shift Skwad's focus from individual agent management toward **team coordination**. Two dashboard modes provide bird's-eye views of agent activity, enabling quick understanding and interaction without diving into terminals.

## Two Dashboards

1. **Global Dashboard** — all workspaces + all agents at a glance
2. **Workspace Dashboard** — all agents in current workspace as a card grid

Both take over sidebar + content area. Both share the same `AgentCardView` component.

## UX Design

### Agent Card (shared component — `AgentCardView`)
- Avatar + name + status dot (color-coded, pulsing when working)
- Terminal title (what they're working on) — 1 line, truncated
- Working folder + branch indicator
- Git stats (insertions/deletions) — compact colored indicators
- Persona badge (if assigned)
- **Quick prompt field** at bottom of card:
  - Disabled when agent is working (status == .running)
  - Enter → send prompt to agent
  - Cmd+Enter → send prompt AND switch to agent terminal
  - Placeholder: "Send prompt..." (or "Working..." when disabled)
- **Click card** (outside prompt field) → navigate to agent terminal

### Workspace Dashboard
- **Trigger**: button/icon in the sidebar header (e.g. grid icon). Workspace bar remains visible.
- **Takes over**: sidebar + content area (full width right of workspace bar)
- **Layout**: card grid with adaptive columns
- **Header top-left**: back button (e.g. `chevron.left` + workspace name) to return to normal sidebar+content
- **Header**: status summary bar: "3 Working · 1 Idle · 1 Needs Input"
- Cards show all agents (no filtering for v1)

### Global Dashboard
- **Trigger**: compass/safari-style icon at TOP of workspace bar, above all workspace circles. Always visible.
- **Takes over**: sidebar + content area (full width right of workspace bar). Workspace bar remains visible.
- **Layout**: sections per workspace (workspace color bar + name header → agent cards grid)
- Click card → switch to that workspace + select agent terminal
- When global dashboard is active, no workspace is "selected" in the bar (or all are dimmed)

### Status Summary (`StatusSummaryView`)
- Compact pill-style counts: colored dots + count for each active status
- Only shows statuses with count > 0

## Data Model Changes

### Agent: add `lastStatusChange`
- New runtime property: `var lastStatusChange: Date = Date()` (not persisted)
- Updated whenever `status` changes in AgentManager
- Enables future sorting (recently-went-idle first) — not used in v1 beyond being tracked

## Architecture

### Shared components (maximize code reuse)
- `AgentCardView` — core card, used by both dashboards
- `StatusSummaryView` — status counts bar
- `QuickPromptField` — inline text input with send/switch behavior

### File structure
```
Views/Dashboard/
├── AgentCardView.swift          # Shared agent card
├── StatusSummaryView.swift      # Status counts
├── QuickPromptField.swift       # Inline prompt input
├── WorkspaceDashboardView.swift # Workspace-level dashboard
└── GlobalDashboardView.swift    # All-workspaces dashboard
```

### Integration points
- `ContentView` — when dashboard mode active, render dashboard instead of sidebar+terminals
- `WorkspaceBarView` — add global dashboard icon at top
- `SidebarView` — add workspace dashboard button in header
- `AgentManager` — update `lastStatusChange` on status transitions
- `Workspace` — add `showDashboard: Bool` to persist workspace dashboard state

## Implementation Phases

### Phase 1: Data Model + Shared Components
- [x] Add `lastStatusChange: Date` to Agent model (runtime only)
- [x] Update AgentManager to set `lastStatusChange` on status changes
- [x] Create `QuickPromptField` view
- [x] Create `StatusSummaryView` view
- [x] Create `AgentCardView` view
- [x] Add SwiftUI previews for all components
- **Commit**: `feat: add dashboard shared components`

### Phase 2: Workspace Dashboard
- [x] Add `showDashboard: Bool` to Workspace model (persisted)
- [x] Create `WorkspaceDashboardView` with card grid layout
- [x] Add dashboard toggle to SidebarView header
- [x] Wire into ContentView — dashboard replaces sidebar+content when active
- [x] Add "back to workspace" navigation in dashboard header
- [x] Add previews
- **Commit**: `feat: workspace dashboard view`

### Phase 3: Global Dashboard
- [x] Add global dashboard icon to WorkspaceBarView (above workspace circles)
- [x] Add `showGlobalDashboard: Bool` state to AgentManager
- [x] Create `GlobalDashboardView` with workspace sections
- [x] Wire into ContentView — global dashboard takes over everything
- [x] Click-to-navigate: switch workspace + select agent
- [x] Add previews
- **Commit**: `feat: global dashboard view`

### Phase 4: Polish & Testing
- [x] Card hover effects and transitions (done in Phase 1 — hover scale/shadow on AgentCardView)
- [x] Smooth dashboard open/close animations (done — .easeInOut transitions)
- [x] Keyboard shortcut for dashboard toggle (Cmd+Shift+D)
- [x] Tests for dashboard state (lastStatusChange, showDashboard, showGlobalDashboard, migration)
- [x] Final preview polish
- **Commit**: `chore: dashboard polish and tests`

## Key Learnings
- Extracting the dashboard/sidebar section into a `@ViewBuilder` computed property was necessary to help Swift's type checker with ContentView's body complexity
- Using `Bool?` for `showDashboard` on Workspace handles Codable migration gracefully (nil decodes to false via `isDashboardVisible`)
- The `isAnyDashboardVisible` helper on ContentView avoids repeating the compound condition everywhere
- Shared `AgentCardView` + `StatusSummaryView` + `QuickPromptField` components make the global and workspace dashboards nearly identical in code structure
