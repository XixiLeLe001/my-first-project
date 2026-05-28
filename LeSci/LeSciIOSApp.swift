import SwiftUI

@main
struct LeSciIOSApp: App {
    @StateObject private var store = AccountStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task {
                    await store.startupRefresh()
                }
        }
    }
}
