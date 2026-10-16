import SwiftUI
import SwiftData

struct MealDetailView: View {
    let summary: MealSummary

    @Environment(\.modelContext) private var modelContext
    @Query private var matchingFavorites: [FavoriteMeal]
    @Query private var customMatches: [CustomRecipe]
    @Environment(\.dismiss) private var dismiss
    @State private var editingRecipe = false
    @Query private var pantry: [PantryItem]
    @AppStorage("assumeStaples") private var assumeStaples = true
    @State private var meal: Meal?
    @State private var addedToList = false
    @State private var scale: RecipeScale = .single
    @State private var isCooking = false
    @State private var errorMessage: String?

    init(summary: MealSummary) {
        self.summary = summary
        let id = summary.id
        _matchingFavorites = Query(filter: #Predicate<FavoriteMeal> { $0.mealID == id })
        _customMatches = Query(filter: #Predicate<CustomRecipe> { $0.recipeID == id })
    }

    private var isCustom: Bool { CustomRecipe.isCustom(summary.id) }

    /// The user's own recipes come from the database and update live after editing.
    private var shownMeal: Meal? { customMatches.first?.asMeal ?? meal }

    private var isFavorite: Bool { !matchingFavorites.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                let photo = isCustom ? shownMeal?.thumbnailURL : summary.thumbnailURL
                if photo != nil || !isCustom {
                    AsyncImage(url: photo) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.secondary.opacity(0.1)
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipped()
                }

                if let meal = shownMeal {
                    details(for: meal)
                        .padding(.horizontal)
                        .padding(.top, photo == nil ? 8 : 0)
                } else if let errorMessage {
                    ContentUnavailableView("Couldn't Load Recipe", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                } else if isCustom {
                    ContentUnavailableView("Recipe Deleted", systemImage: "trash")
                } else {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom)
        }
        .navigationTitle(summary.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(isFavorite ? "Remove Favorite" : "Add Favorite",
                   systemImage: isFavorite ? "heart.fill" : "heart",
                   action: toggleFavorite)
            if let meal, let url = meal.sourceURL ?? meal.youtubeURL {
                ShareLink(item: url)
            }
            if isCustom, !customMatches.isEmpty {
                Button("Edit") { editingRecipe = true }
            }
        }
        .sheet(isPresented: $editingRecipe) {
            RecipeEditorView(recipe: customMatches.first) { dismiss() }
        }
        .task {
            guard meal == nil, !isCustom else { return }
            do {
                meal = try await MealDBClient.shared.meal(id: summary.id)
                if meal == nil { errorMessage = "This recipe is no longer available." }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private func details(for meal: Meal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(meal.name)
                .font(.largeTitle.bold())
            let subtitle = [meal.area, meal.category].compactMap { $0 }.joined(separator: " · ")
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            if meal.cookTime.isReliable {
                CookTimeRow(time: meal.cookTime)
                    .padding(.top, 4)
            }
            if !meal.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(meal.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.tint.opacity(0.15), in: .capsule)
                        }
                    }
                }
            }
        }

        if !meal.steps.isEmpty {
            Button {
                isCooking = true
            } label: {
                Label("Start Cooking", systemImage: "frying.pan")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .fullScreenCover(isPresented: $isCooking) {
                CookingModeView(meal: meal, scale: scale)
            }
        }

        let matcher = IngredientMatcher(pantry: pantry.map(\.name), assumeStaples: assumeStaples)
        let ingredients = meal.ingredients.map { $0.scaled(by: scale.rawValue) }
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Ingredients").font(.title2.bold())
                Spacer()
                if !pantry.isEmpty {
                    let have = meal.ingredients.filter { matcher.has($0.name) }.count
                    Text("You have \(have) of \(meal.ingredients.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("Amount")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker("Recipe amount", selection: $scale) {
                    ForEach(RecipeScale.allCases) { option in
                        Text(option.title)
                            .accessibilityLabel(option.accessibilityName)
                            .tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.bottom, 4)
            .onChange(of: scale) { addedToList = false }
            ForEach(ingredients) { ingredient in
                HStack(alignment: .firstTextBaseline) {
                    if pantry.isEmpty {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(.tint)
                    } else if matcher.has(ingredient.name) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(.tertiary)
                    }
                    Text(ingredient.name)
                    Spacer()
                    Text(ingredient.measure)
                        .foregroundStyle(scale == .single ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                        .multilineTextAlignment(.trailing)
                        .contentTransition(.numericText())
                }
            }

            let toBuy = ingredients.filter { !matcher.has($0.name) }
            if !toBuy.isEmpty {
                Button {
                    modelContext.addToShoppingList(toBuy, from: meal.name)
                    addedToList = true
                } label: {
                    Label(addedToList ? "Added to Shopping List"
                          : pantry.isEmpty ? "Add \(toBuy.count) Ingredients to Shopping List"
                          : "Add \(toBuy.count) Missing to Shopping List",
                          systemImage: addedToList ? "checkmark" : "cart.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(addedToList)
                .padding(.top, 4)
            }
        }

        VStack(alignment: .leading, spacing: 10) {
            Text("Instructions").font(.title2.bold())
            ForEach(Array(meal.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.headline)
                        .foregroundStyle(.tint)
                        .frame(minWidth: 20)
                    Text(step)
                }
            }
        }

        if let youtube = meal.youtubeURL {
            Link(destination: youtube) {
                Label("Watch on YouTube", systemImage: "play.rectangle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func toggleFavorite() {
        if let existing = matchingFavorites.first {
            modelContext.delete(existing)
        } else {
            let current = shownMeal?.summary ?? summary
            modelContext.insert(FavoriteMeal(mealID: current.id, name: current.name, thumbnailURL: current.thumbnailURL))
        }
    }
}

/// "About 45 min · + 8 hr marinating", shown under the recipe title.
private struct CookTimeRow: View {
    let time: CookTime

    var body: some View {
        HStack(spacing: 8) {
            Label(time.activeText, systemImage: "clock")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.tint.opacity(0.15), in: .capsule)
                .foregroundStyle(.tint)
            if let waiting = time.waitingText {
                Label(waiting, systemImage: "hourglass")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Estimated cooking time " + time.activeText + (time.waitingText.map { ", " + $0 } ?? ""))
    }
}
