# Design: Detachable Workspace Windows

## Feature Summary

Allow workspaces to be "detached" from the main window into their own dedicated window. The workspace disappears from the main window's workspace bar and lives in its own standalone window. When the detached window is closed, the user gets a choice: re-attach (move back to main window) or close (delete the workspace and its agents). One workspace per detached window.

## Decisions

- **Terminal state on detach**: Terminals are recreated (same as restart). A confirmation dialog warns the user before detaching, with a "Don't ask again" checkbox.
- **Cmd+W in detached window**: Closes the focused agent (same behavior as main window).
- **Window close button**: Shows re-attach/close dialog.
- **Persist across restart**: Yes — detached workspaces auto-reopen in their own windows on next launch.
- **One workspace per detached window**: Yes, no workspace bar in detached windows.

## Current Architecture Analysis

### How the app is structured today:
- **Single `WindowGroup`** in `SkwadApp.body` — one main window
- `ContentView` renders the full UI: workspace bar + sidebar + terminal ZStack
- `AgentManager` is a singleton `@Observable` passed via `.environment()`
- Agents are kept alive in a `ForEach` ZStack with opacity toggle — **terminals are never recreated** when switching agents, only shown/hidden
- `AppDelegate` intercepts close (Cmd+W) and window close button to manage lifecycle
- Workspaces own an ordered list of agent IDs and per-workspace layout state

### Key constraints:
1. **Terminal NSView reparenting**: Ghostty creates an `NSView` backed by a GPU surface. Moving an `NSView` between windows is technically possible but Ghostty's libghostty C API may hold references to the window/surface — too fragile
2. **Single AgentManager**: The manager is `@MainActor` and singleton — multiple windows observing it is fine, but we need to partition which window renders which workspaces
3. **AppDelegate** currently assumes a single main window (`mainWindow` reference, close button hijacking)

## Proposed Design

### Approach: `WindowGroup(for: UUID.self)` for detached workspaces

Use SwiftUI's value-based `WindowGroup` to open a new window per detached workspace ID. The main window filters out detached workspaces from its workspace bar, and the detached window shows only its workspace.

### Data Model Changes

**`Workspace` struct** — add one property:
```swift
var isDetached: Bool = false  // (persisted via CodingKeys)
```

**`AppSettings`** — add one property:
```swift
@AppStorage("suppressDetachWarning") var suppressDetachWarning: Bool = false
```

### Scene Changes (`SkwadApp.swift`)

Add a second `WindowGroup` for detached workspaces:

```swift
var body: some Scene {
    // Main window — shows non-detached workspaces
    WindowGroup {
        ContentView(...)
            .environment(agentManager)
    }
    .windowStyle(.hiddenTitleBar)

    // Detached workspace windows — one per workspace
    WindowGroup("Workspace", for: UUID.self) { $workspaceId in
        if let workspaceId {
            DetachedWorkspaceView(workspaceId: workspaceId)
                .environment(agentManager)
        }
    }
    .windowStyle(.hiddenTitleBar)
    .defaultSize(width: 1000, height: 700)
}
```

On app launch, iterate `agentManager.workspaces.filter(\.isDetached)` and call `openWindow(id:value:)` for each to restore detached windows.

### New View: `DetachedWorkspaceView`

A simplified version of `ContentView` that shows only one workspace:
- Sidebar with agents from this workspace only
- Terminal ZStack for this workspace's agents
- No workspace bar (single workspace)
- Title bar area shows workspace name + color indicator + "Re-attach" button
- Cmd+W closes the focused agent (same as main window)

This view shares the same `AgentManager` — it just filters to show only agents belonging to this workspace.

### Terminal Lifecycle

Terminals are **recreated** on detach/reattach (same as restart):
- When detaching: mark workspace as `isDetached = true` → bump `restartToken` for all agents in the workspace → main window stops rendering them → detached window picks them up via `onAppear` → controllers recreated
- When reattaching: mark workspace as `isDetached = false` → bump `restartToken` again → detached window disappears → main window picks them up

Before detaching, show a confirmation dialog (unless suppressed):
```
┌─────────────────────────────────────────────┐
│          Detach Workspace?                  │
│                                             │
│  All agents in "MyWorkspace" will be        │
│  restarted.                                 │
│                                             │
│  ☐ Don't ask again                          │
│                                             │
│        [Cancel]  [Detach]                   │
└─────────────────────────────────────────────┘
```

### Window Close Handling

When the detached window's close button is clicked:

```
┌─────────────────────────────────────────────┐
│       Close "MyWorkspace"?                  │
│                                             │
│  [Re-attach]  [Close Workspace]  [Cancel]   │
└─────────────────────────────────────────────┘
```

- **Re-attach**: Set `isDetached = false`, bump `restartToken` for all agents → main window picks them up
- **Close Workspace**: Call `agentManager.removeWorkspace()` — kills all agents
- **Cancel**: Do nothing

Implementation: Use `NSWindowDelegate.windowShouldClose()` on the detached window to intercept and show the dialog.

### Main Window Filtering

`ContentView` and `WorkspaceBarView` filter out detached workspaces:

```swift
// In AgentManager
var attachedWorkspaces: [Workspace] {
    workspaces.filter { !$0.isDetached }
}
```

The workspace bar, dashboard, cycling, and Cmd+1-9 shortcuts use `attachedWorkspaces` instead of `workspaces`.

### AgentManager New Methods

```swift
/// Detach a workspace to its own window
func detachWorkspace(_ workspace: Workspace) {
    // Set isDetached = true
    // Bump restartToken for all agents
    // Switch main window to next attached workspace
    // Save
}

/// Reattach a detached workspace back to main window
func reattachWorkspace(_ workspace: Workspace) {
    // Set isDetached = false
    // Bump restartToken for all agents
    // Switch main window to this workspace
    // Save
}
```

### Entry Points

1. **Context menu on workspace** in workspace bar: "Detach to Window"
2. **Menu bar**: "Window > Detach Workspace" (acts on current workspace)
3. **Re-attach button** in detached window header
4. **Keyboard shortcut**: TBD (maybe Cmd+Shift+D?)

### AppDelegate Changes

- `setupKeyEventMonitor()`: Cmd+W must also work in detached windows (close agent, not window)
- Close button interception: needs to work for detached windows too (not just `mainWindow`)
- `applicationShouldTerminateAfterLastWindowClosed`: must return `false` when detached windows exist (closing main window shouldn't quit if detached windows are open)

## Implementation Phases

### Phase 1: Data model + filtering
- Add `isDetached` to `Workspace` (with Codable backwards-compat)
- Add `suppressDetachWarning` to `AppSettings`
- Add `attachedWorkspaces` computed property to `AgentManager`
- Add `detachWorkspace()` and `reattachWorkspace()` methods to `AgentManager`
- Update workspace bar, cycling, dashboard, and Cmd+1-9 to use `attachedWorkspaces`
- Tests for the new properties, filtering, detach/reattach logic
- **Commit**: `feat: add workspace detach/reattach model support`

### Phase 2: Detached window scene + view
- Add `WindowGroup(for: UUID.self)` scene in `SkwadApp`
- Create `DetachedWorkspaceView` (sidebar + terminal area, no workspace bar)
- Wire up `openWindow(id:value:)` to open detached workspace
- Add detach confirmation dialog with "Don't ask again" checkbox
- Terminal recreation via `restartToken` bump on detach
- Auto-reopen detached workspaces on app launch
- **Commit**: `feat: add detached workspace window`

### Phase 3: Close handling + re-attach
- Implement window close interception with re-attach/close/cancel dialog
- Add "Re-attach" button in detached window header
- Cmd+W in detached window closes agent
- Handle app quit with detached windows (terminate all)
- Handle `applicationShouldTerminateAfterLastWindowClosed` with detached windows
- **Commit**: `feat: handle detached window close with reattach option`

### Phase 4: UI entry points
- Add "Detach to Window" to workspace context menu in workspace bar
- Add "Window > Detach Workspace" menu item
- Add keyboard shortcut
- **Commit**: `feat: add detach workspace UI entry points`

### Phase 5: Polish + edge cases
- Detached window title shows workspace name (updates on rename)
- Handle last attached workspace being detached → main window empty state
- Handle workspace with 0 agents in detached window
- Menu bar mode compatibility
- **Commit**: `fix: polish detached workspace edge cases`
