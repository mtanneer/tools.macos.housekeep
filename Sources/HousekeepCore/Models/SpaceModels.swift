import Foundation

public struct SpaceFinding: Codable, Sendable, Identifiable {
    public var id: String { path }
    public let path: String
    public let sizeHuman: String
    public let sizeKB: Int

    public init(path: String, sizeHuman: String, sizeKB: Int) {
        self.path = path
        self.sizeHuman = sizeHuman
        self.sizeKB = sizeKB
    }

    enum CodingKeys: String, CodingKey {
        case path
        case sizeHuman = "size"
        case sizeKB = "kb"
    }
}

public struct SpaceReport: Codable, Sendable {
    public let totalKB: Int
    public let dirs: [SpaceFinding]
    public let duplicateVenvWarnings: [String]

    public init(totalKB: Int, dirs: [SpaceFinding], duplicateVenvWarnings: [String]) {
        self.totalKB = totalKB
        self.dirs = dirs
        self.duplicateVenvWarnings = duplicateVenvWarnings
    }

    enum CodingKeys: String, CodingKey {
        case totalKB = "total_kb"
        case dirs
        case duplicateVenvWarnings = "duplicate_venv_warnings"
    }

    // The old bash script's JSON never emitted this key (it only printed the warning as table
    // text) — default to empty so this type can still decode the bash script's output for the
    // parity test suite.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalKB = try container.decode(Int.self, forKey: .totalKB)
        dirs = try container.decode([SpaceFinding].self, forKey: .dirs)
        duplicateVenvWarnings = try container.decodeIfPresent([String].self, forKey: .duplicateVenvWarnings) ?? []
    }
}
