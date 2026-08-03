import Foundation
import Testing
@testable import HousekeepCore

@Suite("SpaceScanner")
struct SpaceScannerTests {
    @Test("Finds a known cache dir and sizes it")
    func findsNodeModules() async throws {
        let fixture = try FixtureTree.makeDevTree()
        defer { FixtureTree.cleanup(fixture) }

        let report = await SpaceScanner.scan(root: fixture.root)

        #expect(report.dirs.contains { $0.path == fixture.root + "/node_modules" })
        #expect(report.totalKB > 0)
    }

    @Test("Duplicate .venv/venv siblings produce a warning")
    func duplicateVenvWarning() async throws {
        let fixture = try FixtureTree.makeDevTree()
        defer { FixtureTree.cleanup(fixture) }

        try FileManager.default.createDirectory(atPath: fixture.root + "/.venv", withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: fixture.root + "/venv", withIntermediateDirectories: true)

        let report = await SpaceScanner.scan(root: fixture.root)
        #expect(!report.duplicateVenvWarnings.isEmpty)
    }

    @Test("An empty tree reports zero findings")
    func emptyTree() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("housekeep-empty-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: root) }

        let report = await SpaceScanner.scan(root: root)
        #expect(report.dirs.isEmpty)
        #expect(report.totalKB == 0)
    }
}
