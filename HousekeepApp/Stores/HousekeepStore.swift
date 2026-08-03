import Foundation
import SwiftUI
import HousekeepCore

enum ScanPhase: Equatable {
    case notYetScanned
    case scanning
    case completed
}

enum HousekeepTab: String, CaseIterable, Identifiable {
    case space = "Space"
    case security = "Security"
    case git = "Git"

    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .space: return "internaldrive"
        case .security: return "lock.shield"
        case .git: return "arrow.triangle.branch"
        }
    }
}

/// Central app state, mirroring purge-app's `PurgeStore` pattern: one `@MainActor` observable
/// object owns scan results and drives every tab.
@MainActor
final class HousekeepStore: ObservableObject {
    @Published var selectedTab: HousekeepTab = .space
    @Published var devTreeRoot: String?

    @Published var spacePhase: ScanPhase = .notYetScanned
    @Published var spaceReport: SpaceReport?
    @Published var selectedSpacePaths: Set<String> = []

    @Published var securityPhase: ScanPhase = .notYetScanned
    @Published var securityReport: SecurityReport?
    @Published var toolAvailability: ToolAvailability?

    @Published var gitPhase: ScanPhase = .notYetScanned
    @Published var gitReport: GitReport?

    @Published var errorMessage: String?
    @Published var isTrashingInFlight = false

    /// Cache of repo dirty-state by containing path, used to power the "uncommitted changes
    /// nearby" friction alert before Trashing a cache dir (adapted from purge's git-dirty gate).
    private var gitStatusByRepoPath: [String: GitRepoStatus] = [:]

    var reclaimableBytes: Int {
        (spaceReport?.dirs ?? [])
            .filter { selectedSpacePaths.contains($0.path) }
            .reduce(0) { $0 + $1.sizeKB * 1024 }
    }

    func selectDevTreeRoot(_ path: String) {
        devTreeRoot = path
    }

    func scanAll() async {
        guard let root = devTreeRoot else { return }
        async let space: Void = scanSpace(root: root)
        async let security: Void = scanSecurity(root: root)
        async let git: Void = scanGit(root: root)
        _ = await (space, security, git)
    }

    func scanSpace(root: String) async {
        spacePhase = .scanning
        let report = await SpaceScanner.scan(root: root)
        spaceReport = report
        spacePhase = .completed
    }

    func scanSecurity(root: String) async {
        securityPhase = .scanning
        let availability = await SecurityToolDetector.checkAsync()
        toolAvailability = availability
        let report = await SecurityScanner.scan(root: root, availability: availability)
        securityReport = report
        securityPhase = .completed
    }

    func scanGit(root: String) async {
        gitPhase = .scanning
        let report = await GitStatusScanner.scan(root: root)
        gitReport = report
        gitStatusByRepoPath = Dictionary(uniqueKeysWithValues: report.repos.map { ($0.path, $0) })
        gitPhase = .completed
    }

    /// True if `spaceFindingPath` sits inside a repo with uncommitted changes — powers the
    /// git-dirty-nearby friction alert in `DeletionConfirmSheet`.
    func hasDirtyRepoNearby(_ spaceFindingPath: String) -> Bool {
        guard let root = devTreeRoot else { return false }
        let relative = spaceFindingPath.hasPrefix(root) ? String(spaceFindingPath.dropFirst(root.count + 1)) : spaceFindingPath
        return gitStatusByRepoPath.contains { path, status in
            relative.hasPrefix(path) && status.dirty > 0
        }
    }

    func moveSelectedToTrash() async -> [TrashDeleter.DeletionOutcome] {
        isTrashingInFlight = true
        defer { isTrashingInFlight = false }

        let paths = Array(selectedSpacePaths)
        let outcomes = TrashDeleter.moveToTrash(paths: paths)
        selectedSpacePaths.removeAll()
        if let root = devTreeRoot {
            await scanSpace(root: root)
        }
        return outcomes
    }
}
