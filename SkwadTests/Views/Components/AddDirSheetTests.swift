import XCTest
@testable import Skwad

final class AddDirSheetTests: XCTestCase {

    // MARK: - command(for:)

    func testCommandFormat() {
        XCTAssertEqual(
            AddDirUtils.command(for: "/Users/me/src/project"),
            "/add-dir /Users/me/src/project"
        )
    }

    func testCommandWithSpacesInPath() {
        XCTAssertEqual(
            AddDirUtils.command(for: "/Users/me/My Projects/app"),
            "/add-dir /Users/me/My Projects/app"
        )
    }

    // MARK: - matchRepo(folder:repos:)

    func testMatchRepoFindsExactWorktree() {
        let wt = WorktreeInfo(name: "main", path: "/src/myrepo")
        let repo = RepoInfo(name: "myrepo", worktrees: [wt])

        let result = AddDirUtils.matchRepo(folder: "/src/myrepo", repos: [repo])
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.repo.name, "myrepo")
        XCTAssertEqual(result?.worktree.path, "/src/myrepo")
    }

    func testMatchRepoMatchesSecondWorktree() {
        let wt1 = WorktreeInfo(name: "main", path: "/src/myrepo")
        let wt2 = WorktreeInfo(name: "feature", path: "/src/myrepo-feature")
        let repo = RepoInfo(name: "myrepo", worktrees: [wt1, wt2])

        let result = AddDirUtils.matchRepo(folder: "/src/myrepo-feature", repos: [repo])
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.worktree.name, "feature")
    }

    func testMatchRepoReturnsNilWhenNoMatch() {
        let wt = WorktreeInfo(name: "main", path: "/src/other")
        let repo = RepoInfo(name: "other", worktrees: [wt])

        let result = AddDirUtils.matchRepo(folder: "/src/unknown", repos: [repo])
        XCTAssertNil(result)
    }

    func testMatchRepoReturnsNilForEmptyRepos() {
        let result = AddDirUtils.matchRepo(folder: "/src/project", repos: [])
        XCTAssertNil(result)
    }

    func testMatchRepoPicksFirstRepoWithMatch() {
        let wt1 = WorktreeInfo(name: "main", path: "/src/shared")
        let repo1 = RepoInfo(name: "repo1", worktrees: [wt1])
        let wt2 = WorktreeInfo(name: "main", path: "/src/shared")
        let repo2 = RepoInfo(name: "repo2", worktrees: [wt2])

        let result = AddDirUtils.matchRepo(folder: "/src/shared", repos: [repo1, repo2])
        XCTAssertEqual(result?.repo.name, "repo1")
    }

    // MARK: - defaultWorktree(for:)

    func testDefaultWorktreeReturnsFirst() {
        let wt1 = WorktreeInfo(name: "main", path: "/src/repo")
        let wt2 = WorktreeInfo(name: "feature", path: "/src/repo-feature")
        let repo = RepoInfo(name: "repo", worktrees: [wt1, wt2])

        let result = AddDirUtils.defaultWorktree(for: repo)
        XCTAssertEqual(result?.name, "main")
        XCTAssertEqual(result?.path, "/src/repo")
    }

    func testDefaultWorktreeReturnsNilForEmptyWorktrees() {
        let repo = RepoInfo(name: "empty", worktrees: [])
        XCTAssertNil(AddDirUtils.defaultWorktree(for: repo))
    }
}
