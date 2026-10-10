import SwiftUI

/// Home screen: a featured random recipe, a category row, and a grid of more random picks.
struct HomeView: View {
    /// How many random recipes to show. The free API returns one per request.
    private static let pickCount = 11

    @State private var meals: [Meal] = []
    @State private var categories: [MealCategory] = []
    @State private var errorMessage: String?
    @State private var isShuffling = false
    @State private var showingSettings = false

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if let featured = meals.first {
                        NavigationLink(value: featured.summary) {
                            FeaturedCard(meal: featured)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }

                    if !categories.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Categories")
                                .font(.title2.bold())
                                .padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(categories) { category in
                                        NavigationLink(value: category) {
                                            CategoryChip(category: category)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }

                    if meals.count > 1 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("More to Try")
                                .font(.title2.bold())
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(meals.dropFirst()) { meal in
                                    NavigationLink(value: meal.summary) {
                                        RecipeCard(meal: meal)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .opacity(isShuffling ? 0.4 : 1)
                .animation(.easeInOut(duration: 0.25), value: isShuffling)
            }
            .overlay {
                if let errorMessage, meals.isEmpty {
                    ContentUnavailableView {
                        Label("Couldn't Load Recipes", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Try Again") { Task { await load() } }
                    }
                } else if meals.isEmpty {
                    ProgressView()
                }
            }
            .navigationTitle("Discover")
            .navigationDestination(for: MealCategory.self) { category in
                CategoryMealsView(category: category)
            }
            .navigationDestination(for: MealSummary.self) { meal in
                MealDetailView(summary: meal)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Shuffle", systemImage: "shuffle") {
                        Task { await shuffle() }
                    }
                    .disabled(isShuffling)
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .task { if meals.isEmpty { await load() } }
            .refreshable { await shuffle() }
        }
    }

    private func load() async {
        async let picks = Self.randomMeals(count: Self.pickCount)
        if categories.isEmpty {
            categories = (try? await MealDBClient.shared.categories()) ?? []
        }
        let result = await picks
        if result.isEmpty {
            errorMessage = "Check your connection and try again."
        } else {
            meals = result
            errorMessage = nil
        }
    }

    private func shuffle() async {
        isShuffling = true
        defer { isShuffling = false }
        let result = await Self.randomMeals(count: Self.pickCount)
        if !result.isEmpty {
            withAnimation { meals = result }
        }
    }

    /// Fetches random recipes in parallel and drops duplicates.
    private static func randomMeals(count: Int) async -> [Meal] {
        await withTaskGroup(of: Meal?.self) { group in
            for _ in 0..<count {
                group.addTask { try? await MealDBClient.shared.randomMeal() }
            }
            var seen = Set<String>()
            var meals: [Meal] = []
            for await meal in group {
                if let meal, seen.insert(meal.id).inserted { meals.append(meal) }
            }
            return meals
        }
    }
}

private struct FeaturedCard: View {
    let meal: Meal

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.secondary.opacity(0.15)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    AsyncImage(url: meal.thumbnailURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                }
                .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 4) {
                Text("FEATURED")
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.tint, in: .capsule)
                    .padding(.bottom, 2)
                Text(meal.name)
                    .font(.title.bold())
                    .lineLimit(2)
                let subtitle = [meal.area, meal.category].compactMap { $0 }.joined(separator: " · ")
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .opacity(0.8)
                }
            }
            .foregroundStyle(.white)
            .padding(20)
        }
        .clipShape(.rect(cornerRadius: 24))
        .contentShape(.rect(cornerRadius: 24))
    }
}

private struct RecipeCard: View {
    let meal: Meal

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Color.secondary.opacity(0.15)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    AsyncImage(url: meal.thumbnailURL.map { $0.appending(path: "medium") }) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                }
                .clipShape(.rect(cornerRadius: 16))

            Text(meal.name)
                .font(.headline)
                .lineLimit(2, reservesSpace: true)
            if let area = meal.area {
                Text(area)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(.rect)
    }
}

private struct CategoryChip: View {
    let category: MealCategory

    var body: some View {
        HStack(spacing: 8) {
            AsyncImage(url: category.thumbnailURL) { image in
                image.resizable().scaledToFit()
            } placeholder: {
                Color.clear
            }
            .frame(width: 36, height: 28)
            Text(category.name)
                .font(.subheadline.weight(.medium))
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .padding(.vertical, 8)
        .background(.background.secondary, in: .capsule)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [FavoriteMeal.self, PantryItem.self, ShoppingItem.self], inMemory: true)
}
