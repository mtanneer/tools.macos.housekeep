import Foundation
import Testing
@testable import HousekeepCore

@Suite("SecurityToolDetector")
struct SecurityToolDetectorTests {
    @Test("Both tools present")
    func bothPresent() {
        let availability = SecurityToolDetector.check { _ in true }
        #expect(availability.hasGitleaks)
        #expect(availability.hasOSVScanner)
        #expect(availability.allPresent)
        #expect(!availability.nonePresent)
    }

    @Test("One tool missing")
    func oneMissing() {
        let availability = SecurityToolDetector.check { name in name == "gitleaks" }
        #expect(availability.hasGitleaks)
        #expect(!availability.hasOSVScanner)
        #expect(!availability.allPresent)
        #expect(!availability.nonePresent)
    }

    @Test("Both tools missing")
    func bothMissing() {
        let availability = SecurityToolDetector.check { _ in false }
        #expect(!availability.hasGitleaks)
        #expect(!availability.hasOSVScanner)
        #expect(availability.nonePresent)
    }

    @Test("Install hint names both tools")
    func installHint() {
        #expect(ToolAvailability.installHint == "brew install gitleaks osv-scanner")
    }
}
