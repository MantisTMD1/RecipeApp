import SwiftUI

struct SearchView: View {
    @State private var query = ""
    @State private var results: [Meal] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

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
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle("Search")
            .navigationDestination(for: MealSummary.self) { meal in
                MealDetailView(summary: meal)
            }
            .searchable(text: $query, prompt: "Recipes")
            .task(id: query) {
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
                    let found = try await MealDBClient.shared.search(term)
                    guard !Task.isCancelled else { return }
                    results = found
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
