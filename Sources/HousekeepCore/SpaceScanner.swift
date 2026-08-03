import Foundation

/// Finds reclaimable cache/build directories under a root. Replaces bash's `run_space` (scan half
/// only — deletion lives in `TrashDeleter`). Modeled on purge-app's `FolderSizing`/`CacheScanner`
/// approach of shelling out to `find`/`du` rather than reimplementing traversal semantics natively.
public enum SpaceScanner {
    private static let findTimeout: TimeInterval = 30
    private static let duTimeout: TimeInterval = 30

    public static func scan(root: String) async -> SpaceReport {
        let hits = await findCacheDirs(root: root)

        var findings: [SpaceFinding] = []
        var totalKB = 0
        for hit in hits {
            guard let kb = await sizeKB(of: hit) else { continue }
            let human = await sizeHuman(of: hit) ?? "\(kb)K"
            totalKB += kb
            findings.append(SpaceFinding(path: hit, sizeHuman: human, sizeKB: kb))
        }
        findings.sort { $0.sizeKB > $1.sizeKB }

        let warnings = await duplicateVenvWarnings(root: root)
        return SpaceReport(totalKB: totalKB, dirs: findings, duplicateVenvWarnings: warnings)
    }

    /// `find $ROOT -mindepth 1 -maxdepth 4 \( -iname node_modules -o ... \) -not -path '*/node_modules/*'`
    private static func findCacheDirs(root: String) async -> [String] {
        var args = [root, "-mindepth", "1", "-maxdepth", String(HousekeepConfig.maxDepth), "("]
        for (index, pattern) in HousekeepConfig.cachePatterns.enumerated() {
            if index > 0 { args.append("-o") }
            args.append("-iname")
            args.append(pattern)
        }
        args.append(")")
        args.append(contentsOf: ["-not", "-path", "*/node_modules/*"])

        guard let output = await ProcessRunner.runAsync(
            executablePath: "/usr/bin/find",
            arguments: args,
            timeout: findTimeout
        ), output.succeeded else { return [] }

        return output.stdoutText
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func sizeKB(of path: String) async -> Int? {
        guard let output = await ProcessRunner.runAsync(
            executablePath: "/usr/bin/du",
            arguments: ["-sk", path],
            timeout: duTimeout
        ), output.succeeded else { return nil }
        let field = output.stdoutText.split(separator: "\t").first ?? output.stdoutText.split(separator: " ").first ?? ""
        return Int(field.trimmingCharacters(in: .whitespaces))
    }

    private static func sizeHuman(of path: String) async -> String? {
        guard let output = await ProcessRunner.runAsync(
            executablePath: "/usr/bin/du",
            arguments: ["-sh", path],
            timeout: duTimeout
        ), output.succeeded else { return nil }
        let field = output.stdoutText.split(separator: "\t").first ?? output.stdoutText.split(separator: " ").first ?? ""
        return String(field).trimmingCharacters(in: .whitespaces)
    }

    /// `find $ROOT -mindepth 1 -maxdepth 3 -type d -iname .venv`, warn if a sibling `venv` exists.
    private static func duplicateVenvWarnings(root: String) async -> [String] {
        guard let output = await ProcessRunner.runAsync(
            executablePath: "/usr/bin/find",
            arguments: [root, "-mindepth", "1", "-maxdepth", "3", "-type", "d", "-iname", ".venv"],
            timeout: findTimeout
        ), output.succeeded else { return [] }

        let rootPrefix = root.hasSuffix("/") ? root : root + "/"
        var warnings: [String] = []
        for dotVenv in output.stdoutText.split(separator: "\n").map(String.init) where !dotVenv.isEmpty {
            let parent = (dotVenv as NSString).deletingLastPathComponent
            let siblingVenv = parent + "/venv"
            if FileManager.default.fileExists(atPath: siblingVenv) {
                let relative = parent.hasPrefix(rootPrefix) ? String(parent.dropFirst(rootPrefix.count)) : parent
                warnings.append("duplicate venv+.venv in \(relative)")
            }
        }
        return warnings
    }
}
