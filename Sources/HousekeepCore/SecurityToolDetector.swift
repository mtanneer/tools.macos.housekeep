import Foundation

public struct ToolAvailability: Sendable, Equatable {
    public let hasGitleaks: Bool
    public let hasOSVScanner: Bool

    public var allPresent: Bool { hasGitleaks && hasOSVScanner }
    public var nonePresent: Bool { !hasGitleaks && !hasOSVScanner }

    public static let installHint = "brew install gitleaks osv-scanner"

    public init(hasGitleaks: Bool, hasOSVScanner: Bool) {
        self.hasGitleaks = hasGitleaks
        self.hasOSVScanner = hasOSVScanner
    }
}

/// Shared "is gitleaks/osv-scanner installed" check, used by the CLI's graceful degradation and
/// the GUI's soft-lock banner. `pathSearch` is injectable so tests don't depend on the test
/// machine's actual install state.
public enum SecurityToolDetector {
    /// GUI apps are launched by launchd/Finder with a minimal `PATH` that doesn't include
    /// Homebrew's install dirs (unlike a login shell's `PATH`), so a `which`-style subprocess
    /// lookup silently fails there even when the tool is installed. Checking these well-known
    /// locations directly, in addition to `$PATH`, works regardless of how the process launched.
    private static let knownInstallDirs = ["/opt/homebrew/bin", "/usr/local/bin"]

    public static func check(pathSearch: (String) -> Bool = defaultPathSearch) -> ToolAvailability {
        ToolAvailability(
            hasGitleaks: pathSearch("gitleaks"),
            hasOSVScanner: pathSearch("osv-scanner")
        )
    }

    /// GUI-safe variant; same lookup logic, just spelled `async` since it's called from the
    /// main actor and doing filesystem `stat` calls there is fine (no subprocess involved).
    public static func checkAsync() async -> ToolAvailability {
        check()
    }

    public static func defaultPathSearch(_ executable: String) -> Bool {
        let searchDirs = (ProcessInfo.processInfo.environment["PATH"]?.split(separator: ":").map(String.init) ?? [])
            + knownInstallDirs
        return searchDirs.contains { dir in
            FileManager.default.isExecutableFile(atPath: dir + "/" + executable)
        }
    }
}
