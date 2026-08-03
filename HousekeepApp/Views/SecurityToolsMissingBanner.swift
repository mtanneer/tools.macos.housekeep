import SwiftUI
import AppKit
import HousekeepCore

/// Soft-locks (doesn't hide) the Security tab's actions when gitleaks/osv-scanner are missing,
/// with the literal install command in a copyable monospace block — precise over vague, matching
/// purge's empty-state philosophy.
struct SecurityToolsMissingBanner: View {
    let availability: ToolAvailability

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Missing security tools", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(AppColors.warning)
                .font(.headline)

            if !availability.hasGitleaks { Text("• gitleaks not found") }
            if !availability.hasOSVScanner { Text("• osv-scanner not found") }

            HStack {
                Text(ToolAvailability.installHint)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(AppColors.cardBackground)
                    .cornerRadius(6)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(ToolAvailability.installHint, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help("Copy command")
            }
        }
        .padding()
        .background(AppColors.cardBackground.opacity(0.5))
        .cornerRadius(10)
        .padding()
    }
}
