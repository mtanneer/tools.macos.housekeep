import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: HousekeepStore

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
                .frame(width: 220)
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { await store.scanAll() }
        .alert("Something went wrong", isPresented: .constant(store.errorMessage != nil), presenting: store.errorMessage) { _ in
            Button("OK") { store.errorMessage = nil }
        } message: { message in
            Text(message)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch store.selectedTab {
        case .space: SpaceTabView()
        case .security: SecurityTabView()
        case .git: GitTabView()
        }
    }
}

private struct Sidebar: View {
    @EnvironmentObject private var store: HousekeepStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Housekeep")
                .font(.headline)
                .padding()

            ForEach(HousekeepTab.allCases) { tab in
                NavRow(tab: tab, isSelected: store.selectedTab == tab) {
                    store.selectedTab = tab
                }
                .keyboardShortcut(shortcutKey(for: tab), modifiers: .command)
            }

            Spacer()

            ReclaimableCard()
                .padding()
        }
        .background(AppColors.sidebarBackground)
    }

    private func shortcutKey(for tab: HousekeepTab) -> KeyEquivalent {
        switch tab {
        case .space: return "1"
        case .security: return "2"
        case .git: return "3"
        }
    }
}

private struct NavRow: View {
    let tab: HousekeepTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: tab.systemImage)
                Text(tab.rawValue)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
}

/// Only the "Reclaimable" hero card, per plan: purge's "Storage" used/free disk-capacity card
/// doesn't apply here — this tool cares about project-tree bytes, not overall disk capacity.
private struct ReclaimableCard: View {
    @EnvironmentObject private var store: HousekeepStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reclaimable")
                .font(.caption)
                .foregroundStyle(.secondary)

            switch store.spacePhase {
            case .notYetScanned:
                Text("Not yet scanned")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            case .scanning:
                ProgressView()
            case .completed:
                Text(byteCountFormatted(store.spaceReport?.totalKB ?? 0))
                    .font(.title2.bold())
            }

            if !store.selectedSpacePaths.isEmpty {
                Button("Move \(store.selectedSpacePaths.count) to Trash (\(byteCountFormatted(store.reclaimableBytes / 1024)))") {
                    store.selectedTab = .space
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(10)
    }

    private func byteCountFormatted(_ kb: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(kb) * 1024, countStyle: .file)
    }
}
