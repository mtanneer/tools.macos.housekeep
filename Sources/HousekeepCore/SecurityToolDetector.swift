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
    /// Blocking — safe for the CLI's single-threaded execution and for tests (which inject a
    /// non-blocking closure), but never call this from the main actor: use ``checkAsync()``
    /// from GUI code, since the default search blocks on `ProcessRunner.run`.
    public static func check(pathSearch: (String) -> Bool = defaultPathSearch) -> ToolAvailability {
        ToolAvailability(
            hasGitleaks: pathSearch("gitleaks"),
            hasOSVScanner: pathSearch("osv-scanner")
        )
    }

    /// GUI-safe variant: runs the same lookup off the calling thread via `ProcessRunner.runAsync`.
    public static func checkAsync() async -> ToolAvailability {
        async let gitleaks = asyncPathSearch("gitleaks")
        async let osv = asyncPathSearch("osv-scanner")
        return await ToolAvailability(hasGitleaks: gitleaks, hasOSVScanner: osv)
    }

    public static func defaultPathSearch(_ executable: String) -> Bool {
        guard let output = ProcessRunner.run(
            executablePath: "/usr/bin/which",
            arguments: [executable],
            timeout: 5
        ) else { return false }
        return output.succeeded
    }

    private static func asyncPathSearch(_ executable: String) async -> Bool {
        guard let output = await ProcessRunner.runAsync(
            executablePath: "/usr/bin/which",
            arguments: [executable],
            timeout: 5
        ) else { return false }
        return output.succeeded
    }
}
