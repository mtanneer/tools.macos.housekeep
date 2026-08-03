import Foundation

/// Per-finding gitleaks remediation, used by the CLI's `fix` walk and the GUI's remediation view.
/// Replaces bash's `fix_security` `[o]pen`/`[g]itignore`/`[s]kip` loop.
public enum SecurityRemediation {
    private static let gitleaksTimeout: TimeInterval = 120

    /// Runs gitleaks against `proj` and returns the individual findings (rule, file, line),
    /// decoded natively instead of via bash's `python3 -c` parsing.
    public static func findings(in proj: String) async -> [GitleaksFinding] {
        let reportPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("housekeep_gitleaks_\(UUID().uuidString).json").path
        defer { try? FileManager.default.removeItem(atPath: reportPath) }

        _ = await ProcessRunner.runAsync(
            executablePath: "/usr/bin/env",
            arguments: ["gitleaks", "detect", "--source", proj, "--no-git", "--report-format", "json", "--report-path", reportPath],
            timeout: gitleaksTimeout
        )

        guard let data = FileManager.default.contents(atPath: reportPath), !data.isEmpty else { return [] }
        return (try? JSONDecoder().decode([GitleaksFinding].self, from: data)) ?? []
    }

    /// Appends `file` (relative to `proj`) to `.gitignore` and untracks it via `git rm --cached`.
    public static func gitignoreAndUntrack(file: String, in proj: String) {
        let gitignorePath = proj + "/.gitignore"
        let line = file + "\n"
        if let handle = FileHandle(forWritingAtPath: gitignorePath) {
            handle.seekToEndOfFile()
            handle.write(line.data(using: .utf8) ?? Data())
            handle.closeFile()
        } else {
            FileManager.default.createFile(atPath: gitignorePath, contents: line.data(using: .utf8))
        }

        _ = ProcessRunner.run(
            executablePath: "/usr/bin/git",
            arguments: ["-C", proj, "rm", "--cached", file],
            timeout: 30
        )
    }
}
