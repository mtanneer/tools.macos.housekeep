import Foundation

/// Status/diff/commit/push primitives, used by the CLI's `fix` walk and the GUI's commit/push
/// sheet. Kept deliberately minimal (no file-level stage/unstage) — commit always stages
/// everything via `git add -A`, matching bash's existing `fix_git` behavior exactly.
public enum GitActions {
    private static let timeout: TimeInterval = 60

    public static func status(repo: String) -> String {
        ProcessRunner.run(
            executablePath: "/usr/bin/git",
            arguments: ["-C", repo, "status"],
            timeout: timeout
        )?.stdoutText ?? ""
    }

    public static func diff(repo: String) -> String {
        ProcessRunner.run(
            executablePath: "/usr/bin/git",
            arguments: ["-C", repo, "diff"],
            timeout: timeout
        )?.stdoutText ?? ""
    }

    @discardableResult
    public static func commit(repo: String, message: String) -> Bool {
        guard !message.isEmpty else { return false }
        guard ProcessRunner.run(
            executablePath: "/usr/bin/git",
            arguments: ["-C", repo, "add", "-A"],
            timeout: timeout
        )?.succeeded == true else { return false }

        return ProcessRunner.run(
            executablePath: "/usr/bin/git",
            arguments: ["-C", repo, "commit", "-m", message],
            timeout: timeout
        )?.succeeded == true
    }

    @discardableResult
    public static func push(repo: String, hasUpstream: Bool) -> Bool {
        guard hasUpstream else { return false }
        return ProcessRunner.run(
            executablePath: "/usr/bin/git",
            arguments: ["-C", repo, "push"],
            timeout: timeout
        )?.succeeded == true
    }
}
