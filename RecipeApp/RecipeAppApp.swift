import SwiftUI
import SwiftData

@main
struct RecipeAppApp: App {
    @AppStorage("appearance") private var appearance: Appearance = .dark

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(RecipeStore.container)
    }
}
