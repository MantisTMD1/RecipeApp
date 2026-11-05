import SwiftUI

struct CuisineMealsView: View {
    let cuisine: Cuisine

    @State private var meals: [MealSummary] = []
    @State private var errorMessage: String?
    @State private var filter = ""
    @State private var isLoaded = false
    @AppStorage(DietFilter.storageKey) private var diet = DietFilter()

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
            } else if !isLoaded {
                ProgressView()
            } else if meals.isEmpty {
                ContentUnavailableView("No Matching Recipes", systemImage: "leaf",
                                       description: Text("No \(cuisine.title) recipes fit \(diet.summary)."))
            }
        }
        .searchable(text: $filter, prompt: "Filter \(cuisine.title)")
        .navigationTitle(cuisine.title)
        .task(id: diet) {
            do {
                let all = try await MealDBClient.shared.meals(inCuisine: cuisine)
                meals = diet.isActive ? await MealDBClient.shared.meals(all, fitting: diet) : all
                errorMessage = nil
                isLoaded = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
