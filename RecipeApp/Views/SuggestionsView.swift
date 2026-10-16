import SwiftUI
import SwiftData

/// Recipes ranked by how few ingredients the user is missing.
struct SuggestionsView: View {
    @Query private var pantry: [PantryItem]
    @Query private var myRecipes: [CustomRecipe]
    @Environment(\.modelContext) private var modelContext
    @AppStorage("assumeStaples") private var assumeStaples = true
    @AppStorage(DietFilter.storageKey) private var diet = DietFilter()
    @State private var suggestions: [RecipeSuggestion] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var pantryNames: [String] { pantry.map(\.name).sorted() }

    private var readyToCook: [RecipeSuggestion] { suggestions.filter { $0.missing.isEmpty } }
    private var almostThere: [RecipeSuggestion] { suggestions.filter { (1...3).contains($0.missing.count) } }
    private var needMore: [RecipeSuggestion] { suggestions.filter { $0.missing.count > 3 } }

    var body: some View {
        List {
            section("Ready to Cook", systemImage: "checkmark.seal.fill", items: readyToCook)
            section("Missing 1–3 Ingredients", systemImage: "cart", items: almostThere)
            section("Need a Few More", systemImage: "basket", items: needMore)
        }
        .overlay {
            if isLoading {
                ProgressView("Finding recipes…")
            } else if let errorMessage {
                ContentUnavailableView("Couldn't Find Recipes", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
            } else if suggestions.isEmpty {
                ContentUnavailableView("No Matches", systemImage: "fork.knife", description: Text("Try adding a main ingredient like chicken, beef, rice, or pasta."))
            }
        }
        .navigationTitle("Recipe Ideas")
        .toolbar {
            Menu("Options", systemImage: "slider.horizontal.3") {
                Toggle("Assume Pantry Staples", isOn: $assumeStaples)
                Text("Salt, pepper, oil, flour, sugar, butter and water")
            }
        }
        .task(id: "\(assumeStaples)|\(pantryNames)|\(diet.rawValue)|\(myRecipes.map(\.dateModified))") { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private func section(_ title: String, systemImage: String, items: [RecipeSuggestion]) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { suggestion in
                    NavigationLink(value: suggestion.meal.summary) {
                        SuggestionRow(suggestion: suggestion)
                    }
                    .swipeActions(edge: .trailing) {
                        if !suggestion.missing.isEmpty {
                            Button("Add Missing", systemImage: "cart.badge.plus") {
                                modelContext.addToShoppingList(suggestion.missing, from: suggestion.meal.name)
                            }
                            .tint(.accentColor)
                        }
                    }
                }
            } header: {
                Label(title, systemImage: systemImage)
            }
        }
    }

    private func load() async {
        isLoading = suggestions.isEmpty
        defer { isLoading = false }
        do {
            suggestions = try await RecipeMatcher.suggestions(for: pantryNames, assumeStaples: assumeStaples,
                                                              ownRecipes: myRecipes.map(\.asMeal))
                .filter { diet.allows($0.meal) }
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct SuggestionRow: View {
    let suggestion: RecipeSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MealRow(meal: suggestion.meal.summary,
                    subtitle: "You have \(suggestion.have.count) of \(suggestion.have.count + suggestion.missing.count)")
            ProgressView(value: suggestion.coverage)
                .tint(suggestion.missing.isEmpty ? .green : .accentColor)
            if !suggestion.missing.isEmpty {
                Text("Missing: " + suggestion.missing.map(\.name).joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}
