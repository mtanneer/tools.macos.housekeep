import Foundation
import HousekeepCore

enum SecurityCommand {
    static func run(root: String, json: Bool) async {
        let availability = SecurityToolDetector.check()

        if availability.nonePresent {
            FileHandle.standardError.write("housekeep: missing security tools. Install with:\n".data(using: .utf8)!)
            FileHandle.standardError.write("  \(ToolAvailability.installHint)\n".data(using: .utf8)!)
            if !json {
                exit(1)
            }
        }

        let report = await SecurityScanner.scan(root: root, availability: availability)
        if json {
            JSONRenderer.render(report)
        } else {
            TableRenderer.renderSecurity(report)
        }
    }
}
