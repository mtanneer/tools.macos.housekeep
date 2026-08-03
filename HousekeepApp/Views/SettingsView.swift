import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case light, dark, system
    var id: String { rawValue }
}

/// v1 scope per plan: Appearance + Excluded paths only. Cleaning Schedule and
/// Developer-Projects-staleness don't map to this tool and are skipped.
struct SettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system
    @State private var excludedPaths: [String] = []

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: $appearanceMode) {
                    Text("Light").tag(AppearanceMode.light)
                    Text("Dark").tag(AppearanceMode.dark)
                    Text("System").tag(AppearanceMode.system)
                }
                .pickerStyle(.segmented)
            }

            Section("Excluded Paths") {
                if excludedPaths.isEmpty {
                    Text("No excluded paths").foregroundStyle(.secondary)
                }
                ForEach(excludedPaths, id: \.self) { path in
                    Text(path)
                }
            }
        }
        .padding()
        .frame(width: 420)
        .preferredColorScheme(colorScheme)
    }

    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}
