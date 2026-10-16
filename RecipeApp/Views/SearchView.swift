import SwiftUI
import SwiftData

struct SearchView: View {
    /// Leaves the Search tab (it hides the tab bar, so it needs its own way out).
    var onClose: () -> Void = {}

    @State private var query = ""
    @State private var results: [Meal] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var hiddenCount = 0
    @AppStorage(DietFilter.storageKey) private var diet = DietFilter()
    @Query private var myRecipes: [CustomRecipe]

    var body: some View {
        NavigationStack {
            List(results) { meal in
                NavigationLink(value: meal.summary) {
                    MealRow(meal: meal.summary, subtitle: [meal.area, meal.category].compactMap { $0 }.joined(separator: " · "))
                }
            }
            .overlay {
                if isSearching {
                    ProgressView()
                } else if let errorMessage {
                    ContentUnavailableView("Search Failed", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                } else if query.isEmpty {
                    ContentUnavailableView("Search Recipes", systemImage: "magnifyingglass", description: Text("Try “chicken”, “pasta”, or “cake”."))
                } else if results.isEmpty && hiddenCount > 0 {
                    ContentUnavailableView("No \(diet.summary) Results", systemImage: "leaf",
                                           description: Text("\(hiddenCount) recipes for “\(query)” don't fit your diet settings."))
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle("Search")
            .navigationDestination(for: MealSummary.self) { meal in
                MealDetailView(summary: meal)
                    .recipeZoomDestination(id: meal.id)
            }
            .searchable(text: $query, prompt: "Recipes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close Search", systemImage: "xmark", action: onClose)
                }
            }
            .task(id: "\(query)|\(diet.rawValue)") {
                // Debounce typing; the task is cancelled when the query changes.
                let term = query.trimmingCharacters(in: .whitespaces)
                guard !term.isEmpty else {
                    results = []
                    errorMessage = nil
                    return
                }
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                isSearching = true
                defer { isSearching = false }
                do {
                    let own = myRecipes.map(\.asMeal).filter { $0.name.localizedCaseInsensitiveContains(term) }
                    let found = own + (try await MealDBClient.shared.search(term))
                    guard !Task.isCancelled else { return }
                    results = found.filter(diet.allows)
                    hiddenCount = found.count - results.count
                    errorMessage = nil
                } catch is CancellationError {
                } catch let error as URLError where error.code == .cancelled {
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    SearchView()
}
