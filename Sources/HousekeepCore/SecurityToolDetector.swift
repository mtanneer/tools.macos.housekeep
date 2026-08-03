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
    public static func check(pathSearch: (String) -> Bool = defaultPathSearch) -> ToolAvailability {
        ToolAvailability(
            hasGitleaks: pathSearch("gitleaks"),
            hasOSVScanner: pathSearch("osv-scanner")
        )
    }

    public static func defaultPathSearch(_ executable: String) -> Bool {
        guard let output = ProcessRunner.run(
            executablePath: "/usr/bin/which",
            arguments: [executable],
            timeout: 5
        ) else { return false }
        return output.succeeded
    }
}
