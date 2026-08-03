import SwiftUI
import HousekeepCore

struct SpaceTabView: View {
    @EnvironmentObject private var store: HousekeepStore
    @State private var showConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .sheet(isPresented: $showConfirm) {
            DeletionConfirmSheet()
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Space").font(.title2.bold())
                if let report = store.spaceReport {
                    Text("\(report.dirs.count) directories · \(byteCountFormatted(report.totalKB))")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Rescan") {
                Task { if let root = store.devTreeRoot { await store.scanSpace(root: root) } }
            }
            if !store.selectedSpacePaths.isEmpty {
                Button("Move \(store.selectedSpacePaths.count) to Trash") { showConfirm = true }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var content: some View {
        switch store.spacePhase {
        case .notYetScanned:
            EmptyStateView(systemImage: "internaldrive", title: "Not yet scanned", subtitle: "Scanning starts automatically.")
        case .scanning:
            SkeletonList()
        case .completed:
            if let report = store.spaceReport, !report.dirs.isEmpty {
                List(report.dirs) { finding in
                    SpaceRow(finding: finding)
                }
                if !report.duplicateVenvWarnings.isEmpty {
                    ForEach(report.duplicateVenvWarnings, id: \.self) { warning in
                        Label(warning, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(AppColors.warning)
                            .padding(.horizontal)
                    }
                }
            } else {
                EmptyStateView(systemImage: "checkmark.circle", title: "Nothing to clean up", subtitle: "No reclaimable cache or build directories found.")
            }
        }
    }

    private func byteCountFormatted(_ kb: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(kb) * 1024, countStyle: .file)
    }
}

private struct SpaceRow: View {
    let finding: SpaceFinding
    @EnvironmentObject private var store: HousekeepStore

    private var isSelected: Bool { store.selectedSpacePaths.contains(finding.path) }

    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { newValue in
                    if newValue { store.selectedSpacePaths.insert(finding.path) }
                    else { store.selectedSpacePaths.remove(finding.path) }
                }
            ))
            .labelsHidden()

            VStack(alignment: .leading) {
                Text(displayPath)
                if store.hasDirtyRepoNearby(finding.path) {
                    Label("Uncommitted changes nearby", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(AppColors.warning)
                }
            }
            Spacer()
            Text(finding.sizeHuman)
                .foregroundStyle(.secondary)
        }
    }

    private var displayPath: String {
        guard let root = store.devTreeRoot else { return finding.path }
        return finding.path.hasPrefix(root + "/") ? String(finding.path.dropFirst(root.count + 1)) : finding.path
    }
}

struct SkeletonList: View {
    var body: some View {
        VStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 6)
                    .fill(AppColors.cardBackground)
                    .frame(height: 32)
                    .redacted(reason: .placeholder)
            }
        }
        .padding()
    }
}

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
