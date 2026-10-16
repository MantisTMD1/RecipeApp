import SwiftUI
import SwiftData

struct MealDetailView: View {
    let summary: MealSummary

    @Environment(\.modelContext) private var modelContext
    @Query private var matchingFavorites: [FavoriteMeal]
    @Query private var pantry: [PantryItem]
    @AppStorage("assumeStaples") private var assumeStaples = true
    @State private var meal: Meal?
    @State private var addedToList = false
    @State private var errorMessage: String?

    init(summary: MealSummary) {
        self.summary = summary
        let id = summary.id
        _matchingFavorites = Query(filter: #Predicate<FavoriteMeal> { $0.mealID == id })
    }

    private var isFavorite: Bool { !matchingFavorites.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AsyncImage(url: summary.thumbnailURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.secondary.opacity(0.1)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipped()

                if let meal {
                    details(for: meal)
                        .padding(.horizontal)
                } else if let errorMessage {
                    ContentUnavailableView("Couldn't Load Recipe", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
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
        }
        .task {
            guard meal == nil else { return }
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

        let matcher = IngredientMatcher(pantry: pantry.map(\.name), assumeStaples: assumeStaples)
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
            ForEach(meal.ingredients) { ingredient in
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
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }

            let toBuy = meal.ingredients.filter { !matcher.has($0.name) }
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
            ForEach(Array(steps(from: meal.instructions).enumerated()), id: \.offset) { index, step in
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

    /// Instructions arrive as one blob; split on line breaks and drop "STEP 1" style labels.
    private func steps(from instructions: String) -> [String] {
        instructions
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .filter { $0.range(of: #"^(step\s*)?\d+\.?$"#, options: [.regularExpression, .caseInsensitive]) == nil }
    }

    private func toggleFavorite() {
        if let existing = matchingFavorites.first {
            modelContext.delete(existing)
        } else {
            modelContext.insert(FavoriteMeal(mealID: summary.id, name: summary.name, thumbnailURL: summary.thumbnailURL))
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
