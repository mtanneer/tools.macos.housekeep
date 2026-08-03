import Foundation

/// Builds a throwaway dev-tree in a temp directory for scanner tests: a fake cache dir and a
/// real git repo with one commit plus a dirty file. Built at test-run time (not a committed
/// resource) since a `.git` directory can't round-trip cleanly through SPM resource copying.
enum FixtureTree {
    struct Handle {
        let root: String
        let repoPath: String
    }

    static func makeDevTree() throws -> Handle {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("housekeep-fixture-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)

        // Fake node_modules cache dir.
        let nodeModules = root + "/node_modules"
        try FileManager.default.createDirectory(atPath: nodeModules, withIntermediateDirectories: true)
        try "junk".write(toFile: nodeModules + "/junk.txt", atomically: true, encoding: .utf8)

        // Real git repo: one commit, then one dirty (uncommitted) file.
        let repoPath = root + "/repo"
        try FileManager.default.createDirectory(atPath: repoPath, withIntermediateDirectories: true)
        try run("/usr/bin/git", ["init", "-q", "-b", "main"], cwd: repoPath)
        try run("/usr/bin/git", ["config", "user.email", "test@example.com"], cwd: repoPath)
        try run("/usr/bin/git", ["config", "user.name", "Test"], cwd: repoPath)
        try "hello".write(toFile: repoPath + "/README.md", atomically: true, encoding: .utf8)
        try run("/usr/bin/git", ["add", "-A"], cwd: repoPath)
        try run("/usr/bin/git", ["commit", "-q", "-m", "initial"], cwd: repoPath)
        try "dirty".write(toFile: repoPath + "/scratch.txt", atomically: true, encoding: .utf8)

        return Handle(root: root, repoPath: repoPath)
    }

    static func cleanup(_ handle: Handle) {
        try? FileManager.default.removeItem(atPath: handle.root)
    }

    private static func run(_ path: String, _ args: [String], cwd: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
    }
}
