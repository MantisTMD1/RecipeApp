import SwiftUI

struct CategoryMealsView: View {
    let category: MealCategory

    @State private var meals: [MealSummary] = []
    @State private var errorMessage: String?
    @State private var filter = ""

    private var filteredMeals: [MealSummary] {
        filter.isEmpty ? meals : meals.filter { $0.name.localizedCaseInsensitiveContains(filter) }
    }

    var body: some View {
        List(filteredMeals) { meal in
            NavigationLink(value: meal) {
                MealRow(meal: meal)
            }
        }
        .overlay {
            if let errorMessage {
                ContentUnavailableView("Couldn't Load Meals", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
            } else if meals.isEmpty {
                ProgressView()
            }
        }
        .searchable(text: $filter, prompt: "Filter \(category.name)")
        .navigationTitle(category.name)
        .task {
            guard meals.isEmpty else { return }
            do {
                meals = try await MealDBClient.shared.meals(inCategory: category.name)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
