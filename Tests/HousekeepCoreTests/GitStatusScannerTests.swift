import Foundation
import Testing
@testable import HousekeepCore

@Suite("GitStatusScanner")
struct GitStatusScannerTests {
    @Test("Reports dirty count, branch, no-upstream, zero unpushed")
    func detectsDirtyRepoWithNoUpstream() async throws {
        let fixture = try FixtureTree.makeDevTree()
        defer { FixtureTree.cleanup(fixture) }

        let report = await GitStatusScanner.scan(root: fixture.root)
        let repo = try #require(report.repos.first { $0.path == "repo" })

        #expect(repo.dirty == 1)
        #expect(repo.branch == "main")
        #expect(repo.upstream == "NONE")
        #expect(repo.unpushed == 0)
        #expect(repo.isDirtyWithNoRemote)
        #expect(!repo.hasUnpushedCommits)
    }

    @Test("A clean repo reports zero dirty files")
    func cleanRepo() async throws {
        let fixture = try FixtureTree.makeDevTree()
        defer { FixtureTree.cleanup(fixture) }

        let status = await GitStatusScanner.status(of: fixture.repoPath, root: fixture.root)
        // fixture has one dirty file by default; commit it to simulate a clean repo.
        _ = GitActions.commit(repo: fixture.repoPath, message: "commit the dirty file")
        let cleanStatus = await GitStatusScanner.status(of: fixture.repoPath, root: fixture.root)

        #expect(status.dirty == 1)
        #expect(cleanStatus.dirty == 0)
        #expect(!cleanStatus.isDirtyWithNoRemote)
    }
}
