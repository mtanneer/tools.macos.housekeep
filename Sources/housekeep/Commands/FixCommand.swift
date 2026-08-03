import Foundation
import HousekeepCore

/// Interactive terminal walk through every finding, one at a time. CLI-only (readLine-based) —
/// the GUI's per-tab UIs (space multi-select+Trash, git commit/push sheet, security remediation
/// view) are its answer to this flow, not a literal port.
enum FixCommand {
    static func run(root: String) async {
        print("== fix: space ==")
        await fixSpace(root: root)
        print("")
        print("== fix: git ==")
        await fixGit(root: root)
        print("")
        print("== fix: security ==")
        await fixSecurity(root: root)
    }

    private static func fixSpace(root: String) async {
        let report = await SpaceScanner.scan(root: root)
        TableRenderer.renderSpace(report, root: root)
        print("")
        for finding in report.dirs {
            print("Move \(finding.path) (\(finding.sizeHuman)) to Trash? [y/N] ", terminator: "")
            guard let answer = readLine()?.lowercased(), answer == "y" || answer == "yes" else { continue }
            let outcomes = TrashDeleter.moveToTrash(paths: [finding.path])
            if let outcome = outcomes.first, outcome.succeeded {
                print("moved \(finding.path) to Trash")
            } else {
                print("failed to move \(finding.path): \(outcomes.first?.error ?? "unknown error")")
            }
        }
    }

    private static func fixGit(root: String) async {
        let repoRoots = await GitRepoFinder.findRepoRoots(root: root)
        for proj in repoRoots {
            let status = await GitStatusScanner.status(of: proj, root: root)
            guard status.dirty > 0 || status.unpushed > 0 else { continue }

            print("")
            print("-- \(status.path) --")
            if status.dirty > 0 { print("  \(status.dirty) uncommitted change(s)") }
            if status.unpushed > 0 { print("  \(status.unpushed) unpushed commit(s)") }
            if status.upstream == "NONE" { print("  no upstream remote") }
            print("  [s]tatus  [d]iff  [c]ommit  [p]ush  [i]gnore/skip  [n]ext")
            print("  action> ", terminator: "")
            guard let action = readLine()?.lowercased() else { continue }

            switch action {
            case "s":
                print(GitActions.status(repo: proj))
            case "d":
                print(GitActions.diff(repo: proj))
            case "c":
                print("  commit message: ", terminator: "")
                if let message = readLine(), !message.isEmpty {
                    _ = GitActions.commit(repo: proj, message: message)
                }
            case "p":
                if status.upstream == "NONE" {
                    print("  no upstream configured, skipping push")
                } else {
                    _ = GitActions.push(repo: proj, hasUpstream: true)
                }
            default:
                break
            }
        }
    }

    private static func fixSecurity(root: String) async {
        let availability = SecurityToolDetector.check()
        guard availability.hasGitleaks else {
            FileHandle.standardError.write("gitleaks not installed, skipping security fix pass\n".data(using: .utf8)!)
            return
        }

        let editor = ProcessInfo.processInfo.environment["EDITOR"] ?? "open"
        let repoRoots = await GitRepoFinder.findRepoRoots(root: root)

        for proj in repoRoots {
            let name = GitStatusScanner.relativeName(proj, root: root)
            let findings = await SecurityRemediation.findings(in: proj)
            guard !findings.isEmpty else { continue }

            for finding in findings {
                let relFile = finding.file.hasPrefix(proj) ? String(finding.file.dropFirst(proj.count + 1)) : finding.file
                print("")
                print("-- \(name): \(finding.ruleID) in \(relFile) line \(finding.startLine.map(String.init) ?? "?") --")
                print("  [o]pen  [g]itignore this file  [s]kip")
                print("  action> ", terminator: "")
                guard let action = readLine()?.lowercased() else { continue }

                switch action {
                case "o":
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    process.arguments = [editor, finding.file]
                    try? process.run()
                    process.waitUntilExit()
                case "g":
                    SecurityRemediation.gitignoreAndUntrack(file: relFile, in: proj)
                    print("  added to .gitignore, untracked from git")
                default:
                    break
                }
            }
        }
    }
}
