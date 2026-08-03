import Foundation

/// Read-only git status gathering across every repo under a root. Replaces bash's `run_git` and
/// the read-only half of `fix_git` — those were two near-identical find+status loops in bash
/// (lines 149-185 vs 192-238); this collapses them into one scanner used by both.
/// Modeled on purge-app's `GitStatusChecker.swift`.
public enum GitStatusScanner {
    private static let gitTimeout: TimeInterval = 60

    public static func scan(root: String) async -> GitReport {
        let repoRoots = await GitRepoFinder.findRepoRoots(root: root)
        var statuses: [GitRepoStatus] = []
        for proj in repoRoots {
            statuses.append(await status(of: proj, root: root))
        }
        return GitReport(repos: statuses)
    }

    public static func status(of proj: String, root: String) async -> GitRepoStatus {
        let name = relativeName(proj, root: root)

        let dirtyOutput = await ProcessRunner.runAsync(
            executablePath: "/usr/bin/git",
            arguments: ["-C", proj, "status", "--porcelain"],
            timeout: gitTimeout
        )
        let dirty = dirtyOutput?.stdoutText
            .split(separator: "\n", omittingEmptySubsequences: true)
            .count ?? 0

        let branchOutput = await ProcessRunner.runAsync(
            executablePath: "/usr/bin/git",
            arguments: ["-C", proj, "branch", "--show-current"],
            timeout: gitTimeout
        )
        let branch = branchOutput?.stdoutText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let upstreamOutput = await ProcessRunner.runAsync(
            executablePath: "/usr/bin/git",
            arguments: ["-C", proj, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}"],
            timeout: gitTimeout
        )
        let upstreamRaw = upstreamOutput?.stdoutText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let upstream = upstreamRaw.isEmpty ? "NONE" : upstreamRaw

        let aheadOutput = await ProcessRunner.runAsync(
            executablePath: "/usr/bin/git",
            arguments: ["-C", proj, "log", "@{u}..", "--oneline"],
            timeout: gitTimeout
        )
        let ahead = aheadOutput?.stdoutText
            .split(separator: "\n", omittingEmptySubsequences: true)
            .count ?? 0

        return GitRepoStatus(path: name, dirty: dirty, branch: branch, upstream: upstream, unpushed: ahead)
    }

    public static func relativeName(_ proj: String, root: String) -> String {
        let rootPrefix = root.hasSuffix("/") ? root : root + "/"
        if proj == root { return "." }
        if proj.hasPrefix(rootPrefix) { return String(proj.dropFirst(rootPrefix.count)) }
        return proj
    }
}
