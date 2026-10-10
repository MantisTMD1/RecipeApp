import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavoriteMeal.dateAdded, order: .reverse) private var favorites: [FavoriteMeal]

    var body: some View {
        NavigationStack {
            List {
                ForEach(favorites) { favorite in
                    NavigationLink(value: favorite.summary) {
                        MealRow(meal: favorite.summary)
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        modelContext.delete(favorites[index])
                    }
                }
            }
            .overlay {
                if favorites.isEmpty {
                    ContentUnavailableView("No Favorites Yet", systemImage: "heart", description: Text("Tap the heart on any recipe to save it here."))
                }
            }
            .navigationTitle("Favorites")
            .navigationDestination(for: MealSummary.self) { meal in
                MealDetailView(summary: meal)
            }
            .toolbar {
                if !favorites.isEmpty { EditButton() }
            }
        }
    }
}

#Preview {
    FavoritesView()
        .modelContainer(for: FavoriteMeal.self, inMemory: true)
}
