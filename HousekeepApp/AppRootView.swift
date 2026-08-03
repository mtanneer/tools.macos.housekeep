import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var store: HousekeepStore

    var body: some View {
        Group {
            if store.devTreeRoot == nil {
                OnboardingFlowView()
            } else {
                ContentView()
            }
        }
    }
}
