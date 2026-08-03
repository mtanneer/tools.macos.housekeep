import SwiftUI
import AppKit

@main
struct HousekeepApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = HousekeepStore()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(store)
                .onAppear { appDelegate.store = store }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 600)
        .commands {
            CommandGroup(replacing: .undoRedo) {}
            CommandMenu("Scan") {
                Button("Scan All") {
                    Task { await store.scanAll() }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }
    }
}

/// Guards app quit while a Trash move is in flight, mirroring purge-app's `CleaningQuitGuard`.
final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor var store: HousekeepStore?

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated {
            store?.isTrashingInFlight == true ? .terminateCancel : .terminateNow
        }
    }
}
