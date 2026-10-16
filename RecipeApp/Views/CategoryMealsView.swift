import SwiftUI

struct CategoryMealsView: View {
    let category: MealCategory

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
            if !diet.allowsCategory(category.name) {
                ContentUnavailableView("Hidden by Your Diet",
                                       systemImage: "leaf",
                                       description: Text("\(category.name) recipes don't fit \(diet.summary). You can change this in Settings."))
            } else if let errorMessage {
                ContentUnavailableView("Couldn't Load Meals", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
            } else if !isLoaded {
                ProgressView()
            } else if meals.isEmpty {
                ContentUnavailableView("No Matching Recipes", systemImage: "leaf",
                                       description: Text("No \(category.name) recipes fit \(diet.summary)."))
            }
        }
        .searchable(text: $filter, prompt: "Filter \(category.name)")
        .navigationTitle(category.name)
        .task(id: diet) {
            guard diet.allowsCategory(category.name) else { return }
            do {
                let all = try await MealDBClient.shared.meals(inCategory: category.name)
                meals = diet.isActive ? await Self.filtered(all, by: diet) : all
                isLoaded = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Category lists only have names, so load each recipe's ingredients to check the diet.
    private static func filtered(_ summaries: [MealSummary], by diet: DietFilter) async -> [MealSummary] {
        await withTaskGroup(of: (Int, Bool).self) { group in
            for (index, summary) in summaries.enumerated() {
                group.addTask {
                    let meal = try? await MealDBClient.shared.meal(id: summary.id)
                    return (index, meal.map(diet.allows) ?? false)
                }
            }
            var keep = Set<Int>()
            for await (index, ok) in group where ok { keep.insert(index) }
            return summaries.enumerated().filter { keep.contains($0.offset) }.map(\.element)
        }
    }
}
