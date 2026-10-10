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
        .modelContainer(for: [FavoriteMeal.self, PantryItem.self, ShoppingItem.self])
    }
}
