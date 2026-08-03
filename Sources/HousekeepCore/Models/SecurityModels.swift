import Foundation

public struct SecurityFinding: Codable, Sendable, Identifiable {
    public var id: String { repoPath }
    public let repoPath: String
    public let secretsFound: Bool
    public let vulnerableDepsFound: Bool
    public let detail: [String]

    public init(repoPath: String, secretsFound: Bool, vulnerableDepsFound: Bool, detail: [String]) {
        self.repoPath = repoPath
        self.secretsFound = secretsFound
        self.vulnerableDepsFound = vulnerableDepsFound
        self.detail = detail
    }

    enum CodingKeys: String, CodingKey {
        case repoPath = "path"
        case secretsFound = "secrets_found"
        case vulnerableDepsFound = "vulnerable_deps_found"
        case detail
    }
}

public struct SecurityReport: Codable, Sendable {
    public let hasGitleaks: Bool
    public let hasOSVScanner: Bool
    public let findings: [SecurityFinding]

    public init(hasGitleaks: Bool, hasOSVScanner: Bool, findings: [SecurityFinding]) {
        self.hasGitleaks = hasGitleaks
        self.hasOSVScanner = hasOSVScanner
        self.findings = findings
    }

    enum CodingKeys: String, CodingKey {
        case hasGitleaks = "has_gitleaks"
        case hasOSVScanner = "has_osv_scanner"
        case findings
    }
}

/// One entry from a gitleaks `--report-format json` report. Field names match gitleaks's own
/// schema so this decodes its output directly, replacing bash's `python3 -c` parsing.
public struct GitleaksFinding: Codable, Sendable {
    public let ruleID: String
    public let file: String
    public let startLine: Int?

    enum CodingKeys: String, CodingKey {
        case ruleID = "RuleID"
        case file = "File"
        case startLine = "StartLine"
    }
}
