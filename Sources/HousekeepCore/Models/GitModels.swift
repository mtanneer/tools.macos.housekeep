import Foundation

public struct GitRepoStatus: Codable, Sendable, Identifiable {
    public var id: String { path }
    public let path: String
    public let dirty: Int
    public let branch: String
    public let upstream: String
    public let unpushed: Int

    public init(path: String, dirty: Int, branch: String, upstream: String, unpushed: Int) {
        self.path = path
        self.dirty = dirty
        self.branch = branch
        self.upstream = upstream
        self.unpushed = unpushed
    }

    /// Matches bash's "dirty, no remote" flag.
    public var isDirtyWithNoRemote: Bool { dirty > 0 && upstream == "NONE" }
    /// Matches bash's "unpushed commits" flag.
    public var hasUnpushedCommits: Bool { unpushed > 0 }
}

public struct GitReport: Codable, Sendable {
    public let repos: [GitRepoStatus]

    public init(repos: [GitRepoStatus]) {
        self.repos = repos
    }
}
