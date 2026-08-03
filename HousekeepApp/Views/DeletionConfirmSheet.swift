import SwiftUI
import HousekeepCore

/// Adapted from purge's `DeletionConfirmSheet`: grouped list + total size + Cancel/"Move to
/// Trash" copy (never "Clean now" — always explicit that this is Trash, not deletion). No
/// unknown-safety-tier escalation branch, since every finding here is an unambiguous, known
/// cache-dirname match — nothing housekeep finds is ever ambiguous the way purge's unknown
/// system caches are. The one friction pattern that DOES map is the git-dirty-nearby alert.
struct DeletionConfirmSheet: View {
    @EnvironmentObject private var store: HousekeepStore
    @Environment(\.dismiss) private var dismiss
    @State private var showDirtyRepoAlert = false
    @State private var isDeleting = false
    @State private var resultMessage: String?

    private var candidates: [SpaceFinding] {
        (store.spaceReport?.dirs ?? []).filter { store.selectedSpacePaths.contains($0.path) }
    }

    private var anyDirtyNearby: Bool {
        candidates.contains { store.hasDirtyRepoNearby($0.path) }
    }

    private var totalBytes: Int {
        candidates.reduce(0) { $0 + $1.sizeKB * 1024 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Move to Trash")
                .font(.title2.bold())

            List(candidates) { finding in
                HStack {
                    Text(finding.path)
                    Spacer()
                    Text(finding.sizeHuman).foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 200)

            Text("Total: \(ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file))")
                .foregroundStyle(.secondary)

            if let resultMessage {
                Text(resultMessage)
                    .foregroundStyle(AppColors.success)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Move to Trash") { confirmOrWarn() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isDeleting)
            }
        }
        .padding()
        .frame(width: 480)
        .alert("Uncommitted changes nearby", isPresented: $showDirtyRepoAlert) {
            Button("Pause", role: .cancel) {}
            Button("Move anyway") { Task { await performTrash() } }
        } message: {
            Text("One or more selected items sit inside a repo with uncommitted changes.")
        }
    }

    private func confirmOrWarn() {
        if anyDirtyNearby {
            showDirtyRepoAlert = true
        } else {
            Task { await performTrash() }
        }
    }

    private func performTrash() async {
        isDeleting = true
        let outcomes = await store.moveSelectedToTrash()
        isDeleting = false
        let succeeded = outcomes.filter(\.succeeded).count
        resultMessage = "Moved \(succeeded) item(s) to Trash"
        try? await Task.sleep(nanoseconds: 800_000_000)
        dismiss()
    }
}
