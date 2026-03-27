import SwiftUI

// MARK: - Utility for testable logic

enum AddDirUtils {

    /// Build the command string to inject
    static func command(for folder: String) -> String {
        "/add-dir \(folder)"
    }

    /// Find the repo and worktree matching an agent's working folder
    static func matchRepo(folder: String, repos: [RepoInfo]) -> (repo: RepoInfo, worktree: WorktreeInfo)? {
        for repo in repos {
            if let match = repo.worktrees.first(where: { $0.path == folder }) {
                return (repo, match)
            }
        }
        return nil
    }

    /// Pick the default worktree when a repo is selected
    static func defaultWorktree(for repo: RepoInfo) -> WorktreeInfo? {
        repo.worktrees.first
    }
}

// MARK: - View

struct AddDirSheet: View {
    @Environment(AgentManager.self) var agentManager
    @Environment(\.dismiss) private var dismiss
    @State private var repoDiscovery = RepoDiscoveryService.shared

    let agent: Agent

    @State private var selectedRepo: RepoInfo?
    @State private var selectedWorktree: WorktreeInfo?
    @State private var selectedFolder: String = ""

    private var canConfirm: Bool { !selectedFolder.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 4) {
                Text("Add Directory")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Grant access to a directory")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 12)

            Form {
                Section {
                    // Repository picker
                    LabeledContent("Repository") {
                        Menu {
                            ForEach(repoDiscovery.repos) { repo in
                                Button {
                                    selectRepo(repo)
                                } label: {
                                    Text(repo.name)
                                }
                            }

                            Divider()

                            Button {
                                browseForFolder()
                            } label: {
                                Label("Browse Other...", systemImage: "folder")
                            }
                        } label: {
                            HStack {
                                Text(selectedRepo?.name ?? "Select repository")
                                    .foregroundColor(selectedRepo == nil ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .menuStyle(.borderlessButton)
                    }

                    // Worktree picker (only shown when repo is selected)
                    if let repo = selectedRepo {
                        LabeledContent("Worktree") {
                            Menu {
                                ForEach(repo.worktrees, id: \.path) { worktree in
                                    Button {
                                        selectWorktree(worktree)
                                    } label: {
                                        Text(worktree.name)
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedWorktree?.name ?? "Select worktree")
                                        .foregroundColor(selectedWorktree == nil ? .secondary : .primary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                            }
                            .menuStyle(.borderlessButton)
                        }
                    }

                    // Show selected folder path
                    if !selectedFolder.isEmpty {
                        LabeledContent("Folder") {
                            Text(PathUtils.shortened(selectedFolder))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 450, height: selectedRepo != nil ? 300 : 260)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    addDir()
                }
                .disabled(!canConfirm)
            }
        }
        .onAppear {
            initializeFromAgent()
        }
    }

    // MARK: - Actions

    private func initializeFromAgent() {
        let folder = agent.workingFolder
        if let match = AddDirUtils.matchRepo(folder: folder, repos: repoDiscovery.repos) {
            selectedRepo = match.repo
            selectedWorktree = match.worktree
            selectedFolder = match.worktree.path
        } else {
            selectedFolder = folder
        }
    }

    private func selectRepo(_ repo: RepoInfo) {
        selectedRepo = repo
        if let worktree = AddDirUtils.defaultWorktree(for: repo) {
            selectWorktree(worktree)
        } else {
            selectedWorktree = nil
            selectedFolder = ""
        }
    }

    private func selectWorktree(_ worktree: WorktreeInfo) {
        selectedWorktree = worktree
        selectedFolder = worktree.path
    }

    private func browseForFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.message = "Select a directory to add"
        panel.prompt = "Select"

        if panel.runModal() == .OK, let url = panel.url {
            selectedFolder = url.path
            selectedRepo = nil
            selectedWorktree = nil
        }
    }

    private func addDir() {
        guard !selectedFolder.isEmpty else { return }
        let agentId = agent.id
        agentManager.injectText(AddDirUtils.command(for: selectedFolder), for: agentId)
        // Send a second Return after 500ms to confirm the prompt
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            agentManager.sendReturn(for: agentId)
        }
        dismiss()
    }
}
