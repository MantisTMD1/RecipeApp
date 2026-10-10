import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(filter: #Predicate<ShoppingItem> { !$0.isChecked }) private var toBuy: [ShoppingItem]

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView()
            }
            Tab("Kitchen", systemImage: "refrigerator") {
                KitchenView()
            }
            Tab("List", systemImage: "cart") {
                ShoppingListView()
            }
            .badge(toBuy.count)
            Tab("Favorites", systemImage: "heart") {
                FavoritesView()
            }
            Tab(role: .search) {
                SearchView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [FavoriteMeal.self, PantryItem.self, ShoppingItem.self], inMemory: true)
}
