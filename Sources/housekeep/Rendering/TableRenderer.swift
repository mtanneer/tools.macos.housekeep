import Foundation
import HousekeepCore

/// Replicates bash's exact `printf` column widths for terminal-output continuity.
enum TableRenderer {
    static func renderSpace(_ report: SpaceReport, root: String) {
        print("== space ==")
        print(pad("SIZE", 10) + "  " + "PATH")
        for finding in report.dirs {
            print(pad(finding.sizeHuman, 10) + "  " + relative(finding.path, root: root))
        }
        let totalHuman = humanKB(report.totalKB)
        print("total: \(totalHuman) reclaimable across \(report.dirs.count) dirs")
        for warning in report.duplicateVenvWarnings {
            print("WARNING: \(warning)")
        }
    }

    static func renderSecurity(_ report: SecurityReport) {
        print("== security ==")
        if !report.hasGitleaks || !report.hasOSVScanner {
            FileHandle.standardError.write("housekeep: missing security tools. Install with:\n".data(using: .utf8)!)
            FileHandle.standardError.write("  \(ToolAvailability.installHint)\n".data(using: .utf8)!)
        }
        for finding in report.findings {
            for line in finding.detail {
                print("[\(finding.repoPath)] \(line)")
            }
        }
    }

    static func renderGit(_ report: GitReport) {
        print("== git ==")
        print(pad("PATH", 45) + " " + pad("DIRTY", 6, leftAlign: false) + "  " + pad("BRANCH", 25) + " " + pad("UPSTREAM", 20) + " " + "UNPUSHED")
        for repo in report.repos {
            var flag = ""
            if repo.isDirtyWithNoRemote { flag += " <-- dirty, no remote" }
            if repo.hasUnpushedCommits { flag += " <-- unpushed commits" }
            let line = pad(repo.path, 45) + " " + pad(String(repo.dirty), 6, leftAlign: false) + "  "
                + pad(repo.branch, 25) + " " + pad(repo.upstream, 20) + " " + String(repo.unpushed) + flag
            print(line)
        }
    }

    private static func relative(_ path: String, root: String) -> String {
        let prefix = root.hasSuffix("/") ? root : root + "/"
        return path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : path
    }

    private static func humanKB(_ kb: Int) -> String {
        let bytes = Double(kb) * 1024
        let units = ["B", "K", "M", "G", "T"]
        var value = bytes
        var unitIndex = 0
        while value >= 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        return unitIndex == 0 ? "\(kb)K" : String(format: "%.1f%@", value, units[unitIndex])
    }

    private static func pad(_ text: String, _ width: Int, leftAlign: Bool = true) -> String {
        guard text.count < width else { return text }
        let padding = String(repeating: " ", count: width - text.count)
        return leftAlign ? text + padding : padding + text
    }
}
