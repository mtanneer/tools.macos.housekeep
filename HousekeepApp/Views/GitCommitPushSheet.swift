import SwiftUI
import HousekeepCore

/// Kept deliberately basic per plan: message field + Commit (stage-all, matching bash's
/// `git add -A`) + Push. No diff viewer, no file-level stage/unstage picker.
struct GitCommitPushSheet: View {
    let repo: GitRepoStatus
    let repoPath: String
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var statusText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(repo.path).font(.title2.bold())
            Text("\(repo.dirty) uncommitted change(s) · branch \(repo.branch)")
                .foregroundStyle(.secondary)

            TextField("Commit message", text: $message)
                .textFieldStyle(.roundedBorder)

            if !statusText.isEmpty {
                Text(statusText).font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Close", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Commit") { Task { await commit() } }
                    .disabled(message.isEmpty)
                Button("Push") { Task { await push() } }
                    .disabled(repo.upstream == "NONE")
            }
        }
        .padding()
        .frame(width: 420)
    }

    private func commit() async {
        let succeeded = await GitActions.commit(repo: repoPath, message: message)
        statusText = succeeded ? "Committed." : "Commit failed."
        if succeeded { message = "" }
    }

    private func push() async {
        let succeeded = await GitActions.push(repo: repoPath, hasUpstream: repo.upstream != "NONE")
        statusText = succeeded ? "Pushed." : "Push failed."
    }
}
