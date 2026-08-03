import Foundation

/// Status/diff/commit/push primitives, used by the CLI's `fix` walk and the GUI's commit/push
/// sheet. Kept deliberately minimal (no file-level stage/unstage) — commit always stages
/// everything via `git add -A`, matching bash's existing `fix_git` behavior exactly.
///
/// All calls go through `ProcessRunner.runAsync`, never the blocking `run`: the GUI invokes
/// these directly from button actions on the main actor, and the blocking entry point trips its
/// own `notOnQueue(.main)` guard there. The CLI's `fix` command already runs inside `async`
/// functions, so `await`-ing here costs it nothing.
public enum GitActions {
    private static let timeout: TimeInterval = 60

    public static func status(repo: String) async -> String {
        await ProcessRunner.runAsync(
            executablePath: "/usr/bin/git",
            arguments: ["-C", repo, "status"],
            timeout: timeout
        )?.stdoutText ?? ""
    }

    public static func diff(repo: String) async -> String {
        await ProcessRunner.runAsync(
            executablePath: "/usr/bin/git",
            arguments: ["-C", repo, "diff"],
            timeout: timeout
        )?.stdoutText ?? ""
    }

    @discardableResult
    public static func commit(repo: String, message: String) async -> Bool {
        guard !message.isEmpty else { return false }
        guard await ProcessRunner.runAsync(
            executablePath: "/usr/bin/git",
            arguments: ["-C", repo, "add", "-A"],
            timeout: timeout
        )?.succeeded == true else { return false }

        return await ProcessRunner.runAsync(
            executablePath: "/usr/bin/git",
            arguments: ["-C", repo, "commit", "-m", message],
            timeout: timeout
        )?.succeeded == true
    }

    @discardableResult
    public static func push(repo: String, hasUpstream: Bool) async -> Bool {
        guard hasUpstream else { return false }
        return await ProcessRunner.runAsync(
            executablePath: "/usr/bin/git",
            arguments: ["-C", repo, "push"],
            timeout: timeout
        )?.succeeded == true
    }
}
