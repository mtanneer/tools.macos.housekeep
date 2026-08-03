import Foundation

/// Top-level `{"space":..., "security":..., "git":...}` shape used by `housekeep --json` (no
/// subcommand). Replaces bash's hand-glued printf string concatenation with real JSON composition.
public struct HousekeepReport: Codable, Sendable {
    public let space: SpaceReport
    public let security: SecurityReport
    public let git: GitReport

    public init(space: SpaceReport, security: SecurityReport, git: GitReport) {
        self.space = space
        self.security = security
        self.git = git
    }
}
