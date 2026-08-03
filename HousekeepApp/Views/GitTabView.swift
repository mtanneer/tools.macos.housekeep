import SwiftUI
import HousekeepCore

struct GitTabView: View {
    @EnvironmentObject private var store: HousekeepStore
    @State private var selectedRepo: GitRepoStatus?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .sheet(item: $selectedRepo) { repo in
            GitCommitPushSheet(repo: repo, repoPath: absolutePath(for: repo))
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Git").font(.title2.bold())
                if let report = store.gitReport {
                    Text("\(report.repos.count) repositories")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Rescan") {
                Task { if let root = store.devTreeRoot { await store.scanGit(root: root) } }
            }
        }
        .padding()
    }

    @ViewBuilder
    private var content: some View {
        switch store.gitPhase {
        case .notYetScanned:
            EmptyStateView(systemImage: "arrow.triangle.branch", title: "Not yet scanned", subtitle: "Scanning starts automatically.")
        case .scanning:
            SkeletonList()
        case .completed:
            if let report = store.gitReport, !report.repos.isEmpty {
                List(report.repos) { repo in
                    GitRow(repo: repo) { selectedRepo = repo }
                }
            } else {
                EmptyStateView(systemImage: "checkmark.circle", title: "No repositories found", subtitle: "Nothing to report.")
            }
        }
    }

    private func absolutePath(for repo: GitRepoStatus) -> String {
        guard let root = store.devTreeRoot else { return repo.path }
        return repo.path == "." ? root : root + "/" + repo.path
    }
}

private struct GitRow: View {
    let repo: GitRepoStatus
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading) {
                    Text(repo.path)
                    Text(repo.branch.isEmpty ? "(detached)" : repo.branch)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if repo.dirty > 0 {
                    Label("\(repo.dirty)", systemImage: "pencil.circle")
                        .foregroundStyle(AppColors.warning)
                }
                if repo.hasUnpushedCommits {
                    Label("\(repo.unpushed)", systemImage: "arrow.up.circle")
                        .foregroundStyle(.blue)
                }
                if repo.upstream == "NONE" {
                    Label("no remote", systemImage: "xmark.circle")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
