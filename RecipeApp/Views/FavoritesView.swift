import SwiftUI
import SwiftData

/// The "Saved" tab: the user's own recipes, then recipes they've favorited.
struct FavoritesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavoriteMeal.dateAdded, order: .reverse) private var favorites: [FavoriteMeal]
    @Query(sort: \CustomRecipe.dateModified, order: .reverse) private var myRecipes: [CustomRecipe]
    @State private var showingEditor = false

    var body: some View {
        NavigationStack {
            List {
                if !myRecipes.isEmpty {
                    Section("My Recipes") {
                        ForEach(myRecipes) { recipe in
                            NavigationLink(value: recipe.summary) {
                                MealRow(meal: recipe.summary, subtitle: subtitle(for: recipe))
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { modelContext.deleteCustomRecipe(myRecipes[index]) }
                        }
                    }
                }

                if !favorites.isEmpty {
                    Section("Favorites") {
                        ForEach(favorites) { favorite in
                            let summary = resolvedSummary(for: favorite)
                            NavigationLink(value: summary) {
                                MealRow(meal: summary)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { modelContext.delete(favorites[index]) }
                        }
                    }
                }
            }
            .overlay {
                if favorites.isEmpty && myRecipes.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing Saved Yet", systemImage: "heart")
                    } description: {
                        Text("Tap the heart on any recipe to save it here, or add your own family recipes.")
                    } actions: {
                        Button("Create a Recipe") { showingEditor = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Saved")
            .navigationDestination(for: MealSummary.self) { meal in
                MealDetailView(summary: meal)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Recipe", systemImage: "plus") { showingEditor = true }
                }
                if !favorites.isEmpty || !myRecipes.isEmpty {
                    ToolbarItem(placement: .topBarLeading) { EditButton() }
                }
            }
            .sheet(isPresented: $showingEditor) {
                RecipeEditorView(recipe: nil)
            }
        }
    }

    private func subtitle(for recipe: CustomRecipe) -> String {
        [recipe.cuisine.isEmpty ? nil : recipe.cuisine, recipe.mealType?.title]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    /// A favorited custom recipe may have a new photo or name since it was favorited.
    private func resolvedSummary(for favorite: FavoriteMeal) -> MealSummary {
        myRecipes.first { $0.recipeID == favorite.mealID }?.summary ?? favorite.summary
    }
}

#Preview {
    FavoritesView()
        .modelContainer(for: [FavoriteMeal.self, CustomRecipe.self], inMemory: true)
}
