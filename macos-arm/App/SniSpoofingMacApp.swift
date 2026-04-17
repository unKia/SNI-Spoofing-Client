import SwiftUI

@main
struct SniSpoofingMacApp: App {
    @StateObject private var languageStore = AppLanguageStore.shared
    @StateObject private var tunnelController = TunnelController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .environmentObject(languageStore)
                .environmentObject(tunnelController)
                .environment(\.locale, languageStore.selectedLanguage.locale)
                .environment(\.layoutDirection, languageStore.selectedLanguage.isRTL ? .rightToLeft : .leftToRight)
        }
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
    }
}
