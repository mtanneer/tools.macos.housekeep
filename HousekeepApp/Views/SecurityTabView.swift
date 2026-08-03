import SwiftUI

struct SecurityTabView: View {
    @EnvironmentObject private var store: HousekeepStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()

            if let availability = store.toolAvailability, !availability.allPresent {
                SecurityToolsMissingBanner(availability: availability)
            }

            content
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Security").font(.title2.bold())
                if let report = store.securityReport {
                    Text("\(report.findings.count) repo(s) with findings")
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Rescan") {
                Task { if let root = store.devTreeRoot { await store.scanSecurity(root: root) } }
            }
            .disabled(store.toolAvailability?.nonePresent == true)
        }
        .padding()
    }

    @ViewBuilder
    private var content: some View {
        switch store.securityPhase {
        case .notYetScanned:
            EmptyStateView(systemImage: "lock.shield", title: "Not yet scanned", subtitle: "Scanning starts automatically.")
        case .scanning:
            SkeletonList()
        case .completed:
            if let report = store.securityReport, !report.findings.isEmpty {
                List(report.findings) { finding in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(finding.repoPath).font(.headline)
                        ForEach(finding.detail, id: \.self) { line in
                            Text(line).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                EmptyStateView(systemImage: "checkmark.shield", title: "Nothing found", subtitle: "No secrets or vulnerable dependencies detected.")
            }
        }
    }
}
