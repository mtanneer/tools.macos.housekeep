import SwiftUI
import AppKit

/// Simplified from purge's welcome→permissions→firstScan→results→cleaning→celebration wizard:
/// no permissions step exists here since this tool only ever scans directories the user
/// explicitly picks, never TCC-protected locations — no Full Disk Access is requested.
enum OnboardingStep: Equatable {
    case welcome, pickRoot, firstScan, results, celebration
}

struct OnboardingFlowView: View {
    @EnvironmentObject private var store: HousekeepStore
    @State private var step: OnboardingStep = .welcome
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 24) {
            switch step {
            case .welcome:
                welcomeStep
            case .pickRoot:
                pickRootStep
            case .firstScan:
                firstScanStep
            case .results:
                resultsStep
            case .celebration:
                celebrationStep
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reduceMotion ? nil : .default, value: step)
    }

    private var welcomeStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "internaldrive")
                .font(.system(size: 48))
            Text("Housekeep")
                .font(.largeTitle.bold())
            Text("Audits a dev folder tree for reclaimable disk space, leaked secrets, and git hygiene.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Get Started") { step = .pickRoot }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }

    private var pickRootStep: some View {
        VStack(spacing: 16) {
            Text("Pick your dev folder")
                .font(.title2.bold())
            Text("Housekeep only ever looks inside the folder you choose here — nothing else on your Mac.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Choose Folder…") { pickFolder() }
                .buttonStyle(.borderedProminent)
        }
    }

    private var firstScanStep: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Scanning your dev folder…")
                .foregroundStyle(.secondary)
        }
        .task {
            await store.scanAll()
            step = .results
        }
    }

    private var resultsStep: some View {
        VStack(spacing: 16) {
            Text("Here's what Housekeep found")
                .font(.title2.bold())
            if let report = store.spaceReport {
                Text("\(report.dirs.count) reclaimable cache/build directories")
                    .foregroundStyle(.secondary)
            }
            Button("Continue") { step = .celebration }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
    }

    private var celebrationStep: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.success)
            Text("You're all set")
                .font(.title2.bold())
            Text("Review findings any time from the sidebar.")
                .foregroundStyle(.secondary)
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.selectDevTreeRoot(url.path)
        step = .firstScan
    }
}
