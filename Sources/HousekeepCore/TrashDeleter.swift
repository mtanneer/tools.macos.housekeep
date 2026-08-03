import Foundation

/// Moves reclaimable dirs to the Trash instead of `rm -rf`. `FileManager.trashItem` is Foundation
/// (not AppKit), so this works identically from the bare CLI and the GUI with no extra linking.
public enum TrashDeleter {
    public struct DeletionOutcome: Sendable {
        public let path: String
        public let succeeded: Bool
        public let error: String?
    }

    /// Moves each path to the Trash, one at a time. Never permanently deletes.
    public static func moveToTrash(paths: [String]) -> [DeletionOutcome] {
        paths.map { path in
            let url = URL(fileURLWithPath: path)
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                return DeletionOutcome(path: path, succeeded: true, error: nil)
            } catch {
                return DeletionOutcome(path: path, succeeded: false, error: error.localizedDescription)
            }
        }
    }
}
