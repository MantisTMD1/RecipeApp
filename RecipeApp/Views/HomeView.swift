import SwiftUI

/// Home screen: a featured random recipe, categories, the newest recipes, and more random picks.
struct HomeView: View {
    @State private var meals: [Meal] = []
    @State private var latest: [Meal] = []
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

                    if !latest.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("New Recipes")
                                .font(.title2.bold())
                                .padding(.horizontal)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 16) {
                                    ForEach(latest) { meal in
                                        NavigationLink(value: meal.summary) {
                                            RecipeCard(meal: meal)
                                                .frame(width: 160)
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
        async let picks = Self.randomMeals()
        async let newest = try? MealDBClient.shared.latestMeals()
        if categories.isEmpty {
            categories = (try? await MealDBClient.shared.categories()) ?? []
        }
        latest = await newest ?? []
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
        let result = await Self.randomMeals()
        if !result.isEmpty {
            withAnimation { meals = result }
        }
    }

    /// One featured recipe plus an even number for the two-column grid. Each random selection
    /// returns ten recipes, so two run in parallel and duplicates are dropped.
    private static func randomMeals() async -> [Meal] {
        async let first = try? MealDBClient.shared.randomSelection()
        async let second = try? MealDBClient.shared.randomSelection()
        var seen = Set<String>()
        let unique = ((await first ?? []) + (await second ?? [])).filter { seen.insert($0.id).inserted }
        return Array(unique.prefix(11))
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
            // Always reserve the line so cards without a cuisine stay aligned in the grid.
            Text(meal.area ?? " ")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
