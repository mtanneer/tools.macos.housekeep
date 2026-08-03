import Foundation

/// Runs gitleaks + osv-scanner across every git repo under a root. Replaces bash's `run_security`.
/// Decodes gitleaks's JSON report natively via `Codable` instead of shelling to `python3 -c`.
public enum SecurityScanner {
    private static let gitleaksTimeout: TimeInterval = 120
    private static let osvTimeout: TimeInterval = 120
    private static let findTimeout: TimeInterval = 30

    public static func scan(root: String, availability: ToolAvailability) async -> SecurityReport {
        guard !availability.nonePresent else {
            return SecurityReport(hasGitleaks: false, hasOSVScanner: false, findings: [])
        }

        let repoRoots = await GitRepoFinder.findRepoRoots(root: root)
        var findings: [SecurityFinding] = []

        for proj in repoRoots {
            let name = relativeName(proj, root: root)
            var secretsFound = false
            var vulnFound = false
            var detail: [String] = []

            if availability.hasGitleaks {
                let count = await gitleaksFindingCount(proj: proj)
                if count > 0 {
                    secretsFound = true
                    detail.append("gitleaks: secrets found — run: gitleaks detect --source \(proj) --no-git -v")
                }
            }

            if availability.hasOSVScanner {
                if await osvHasVulnerabilities(proj: proj) {
                    vulnFound = true
                    detail.append("osv-scanner: vulnerable dependencies found — run: osv-scanner scan source \(proj)")
                }
            }

            if secretsFound || vulnFound {
                findings.append(SecurityFinding(
                    repoPath: name,
                    secretsFound: secretsFound,
                    vulnerableDepsFound: vulnFound,
                    detail: detail
                ))
            }
        }

        return SecurityReport(
            hasGitleaks: availability.hasGitleaks,
            hasOSVScanner: availability.hasOSVScanner,
            findings: findings
        )
    }

    private static func relativeName(_ proj: String, root: String) -> String {
        let rootPrefix = root.hasSuffix("/") ? root : root + "/"
        if proj == root { return "." }
        if proj.hasPrefix(rootPrefix) { return String(proj.dropFirst(rootPrefix.count)) }
        return proj
    }

    private static func gitleaksFindingCount(proj: String) async -> Int {
        let reportPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("housekeep_gitleaks_\(UUID().uuidString).json").path
        defer { try? FileManager.default.removeItem(atPath: reportPath) }

        _ = await ProcessRunner.runAsync(
            executablePath: "/usr/bin/env",
            arguments: ["gitleaks", "detect", "--source", proj, "--no-git", "--report-format", "json", "--report-path", reportPath],
            timeout: gitleaksTimeout
        )

        guard let data = FileManager.default.contents(atPath: reportPath), !data.isEmpty else { return 0 }
        guard let findings = try? JSONDecoder().decode([GitleaksFinding].self, from: data) else { return 0 }
        return findings.count
    }

    private static func osvHasVulnerabilities(proj: String) async -> Bool {
        guard let output = await ProcessRunner.runAsync(
            executablePath: "/usr/bin/env",
            arguments: ["osv-scanner", "scan", "source", proj],
            timeout: osvTimeout
        ) else { return false }
        return output.stdoutText.lowercased().contains("vulnerabilit")
    }
}

/// Shared `.git` directory discovery used by security and git scanners (dedupes the identical
/// `find ... -iname .git` loop that appeared in bash's `run_security`/`run_git`/`fix_git`/`fix_security`).
public enum GitRepoFinder {
    public static func findRepoRoots(root: String) async -> [String] {
        guard let output = await ProcessRunner.runAsync(
            executablePath: "/usr/bin/find",
            arguments: [root, "-mindepth", "1", "-maxdepth", String(HousekeepConfig.maxDepth),
                        "-type", "d", "-iname", ".git", "-not", "-path", "*/node_modules/*"],
            timeout: 30
        ), output.succeeded else { return [] }

        return output.stdoutText
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }
            .map { $0.hasSuffix("/.git") ? String($0.dropLast(5)) : $0 }
    }
}
