import SwiftUI
import SwiftData

enum MealPlanRoute: Hashable {
    case week
}

/// A week of planned meals, one section per day.
struct MealPlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlannedMeal.dateAdded) private var plans: [PlannedMeal]
    @Query private var myRecipes: [CustomRecipe]
    @Query private var pantry: [PantryItem]
    @AppStorage("assumeStaples") private var assumeStaples = true

    @State private var weekStart = PlanCalendar.startOfWeek(containing: .now)
    @State private var dayBeingFilled: PlanDay?
    @State private var isAddingToList = false
    @State private var listMessage: String?
    @State private var hasScrolledToToday = false

    private var days: [Date] { PlanCalendar.days(ofWeekStarting: weekStart) }

    private var plansByDay: [String: [PlannedMeal]] { Dictionary(grouping: plans, by: \.dayKey) }

    /// What's left to shop for: days already gone don't need ingredients.
    private var mealsToShopFor: [PlannedMeal] {
        let todayKey = PlanCalendar.key(for: .now)
        let keys = Set(days.map(PlanCalendar.key(for:)).filter { $0 >= todayKey })
        return plans.filter { keys.contains($0.dayKey) }
    }

    var body: some View {
        let byDay = plansByDay
        ScrollViewReader { proxy in
        List {
            ForEach(days, id: \.self) { day in
                let key = PlanCalendar.key(for: day)
                Section {
                    ForEach(byDay[key] ?? []) { plan in
                        row(for: plan, on: key)
                    }
                    .onDelete { offsets in
                        let dayPlans = byDay[key] ?? []
                        for index in offsets { modelContext.delete(dayPlans[index]) }
                    }

                    Button {
                        dayBeingFilled = PlanDay(date: day)
                    } label: {
                        Label("Add a Meal", systemImage: "plus")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(.rect)
                    }
                    .dropDestination(for: String.self) { ids, _ in
                        move(ids, to: key)
                    }
                } header: {
                    Text(PlanCalendar.title(for: day))
                        .foregroundStyle(Calendar.current.isDateInToday(day) ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                }
                .id(key)
            }
        }
        // Days already gone would otherwise push today off the screen.
        .onAppear {
            guard !hasScrolledToToday else { return }
            hasScrolledToToday = true
            proxy.scrollTo(PlanCalendar.key(for: .now), anchor: .top)
        }
        }
        .navigationTitle("Meal Plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { weekPicker }
        }
        .safeAreaInset(edge: .bottom) {
            if !mealsToShopFor.isEmpty || listMessage != nil {
                shoppingBar
            }
        }
        .sensoryFeedback(.selection, trigger: plans.map(\.dayKey))
        .sheet(item: $dayBeingFilled) { day in
            AddPlannedMealView(day: day.date)
        }
        .onChange(of: weekStart) { listMessage = nil }
        .onChange(of: plans.map(\.dayKey)) { listMessage = nil }
    }

    private var weekPicker: some View {
        HStack(spacing: 12) {
            Button("Previous Week", systemImage: "chevron.left") { changeWeek(by: -1) }
            Text(PlanCalendar.title(forWeekStarting: weekStart))
                .font(.headline)
                .frame(minWidth: 110)
            Button("Next Week", systemImage: "chevron.right") { changeWeek(by: 1) }
        }
        .labelStyle(.iconOnly)
    }

    private var shoppingBar: some View {
        VStack(spacing: 8) {
            if let listMessage {
                Text(listMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if !mealsToShopFor.isEmpty {
                Button {
                    // Runs on its own so a screen update can't cancel the requests partway through.
                    Task { await addMissingToShoppingList() }
                } label: {
                    Label(isAddingToList ? "Adding…" : "Add Missing to Shopping List", systemImage: "cart.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isAddingToList)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private func row(for plan: PlannedMeal, on key: String) -> some View {
        let summary = myRecipes.first { $0.recipeID == plan.mealID }?.summary ?? plan.summary
        return NavigationLink(value: summary) {
            MealRow(meal: summary)
        }
        .draggable(plan.planID)
        .dropDestination(for: String.self) { ids, _ in
            move(ids, to: key)
        }
        .contextMenu {
            Menu("Move To", systemImage: "calendar") {
                ForEach(days, id: \.self) { day in
                    Button(PlanCalendar.title(for: day)) {
                        move([plan.planID], to: PlanCalendar.key(for: day))
                    }
                    .disabled(PlanCalendar.key(for: day) == key)
                }
            }
            Button("Remove", systemImage: "trash", role: .destructive) {
                modelContext.delete(plan)
            }
        }
    }

    private func changeWeek(by weeks: Int) {
        withAnimation { weekStart = PlanCalendar.week(after: weekStart, by: weeks) }
    }

    @discardableResult
    private func move(_ ids: [String], to key: String) -> Bool {
        let moving = plans.filter { ids.contains($0.planID) }
        withAnimation {
            for plan in moving {
                plan.dayKey = key
                // Puts it last on its new day.
                plan.dateAdded = .now
            }
        }
        return !moving.isEmpty
    }

    private func addMissingToShoppingList() async {
        isAddingToList = true
        defer { isAddingToList = false }

        // A recipe planned twice needs twice the ingredients.
        var timesPlanned: [String: Int] = [:]
        var summaries: [MealSummary] = []
        for plan in mealsToShopFor {
            if timesPlanned[plan.mealID] == nil { summaries.append(plan.summary) }
            timesPlanned[plan.mealID, default: 0] += 1
        }

        let (meals, failures) = await loadMeals(summaries)
        let matcher = IngredientMatcher(pantry: pantry.map(\.name), assumeStaples: assumeStaples)
        var added = 0
        for meal in meals {
            let factor = Double(timesPlanned[meal.id] ?? 1)
            let missing = meal.ingredients
                .filter { !matcher.has($0.name) }
                .map { factor == 1 ? $0 : $0.scaled(by: factor) }
            added += modelContext.addToShoppingList(missing, from: meal.name)
        }

        var message = switch added {
        case 0: "Nothing new to add. You have everything or it's already on your list."
        case 1: "Added 1 new item to your shopping list."
        default: "Added \(added) new items to your shopping list."
        }
        if failures > 0 {
            message += " Couldn't load \(failures) \(failures == 1 ? "recipe" : "recipes"). Check your connection and try again."
        }
        listMessage = message
    }

    private func loadMeals(_ summaries: [MealSummary]) async -> (meals: [Meal], failures: Int) {
        var meals: [Meal] = []
        var remote: [MealSummary] = []
        for summary in summaries {
            if let own = myRecipes.first(where: { $0.recipeID == summary.id }) {
                meals.append(own.asMeal)
            } else if !CustomRecipe.isCustom(summary.id) {
                remote.append(summary)
            }
        }
        let fetched = await withTaskGroup(of: Meal?.self) { group in
            for summary in remote {
                group.addTask { try? await MealDBClient.shared.meal(id: summary.id) }
            }
            var results: [Meal] = []
            for await meal in group { if let meal { results.append(meal) } }
            return results
        }
        return (meals + fetched, remote.count - fetched.count)
    }
}

/// Lets a date drive a sheet.
private struct PlanDay: Identifiable {
    let date: Date
    var id: Date { date }
}

/// Top of the Home screen: what's for dinner, and the way into the week's plan.
struct ThisWeekCard: View {
    @Query private var plans: [PlannedMeal]

    private var tonight: [PlannedMeal] {
        let key = PlanCalendar.key(for: .now)
        return plans.filter { $0.dayKey == key }.sorted { $0.dateAdded < $1.dateAdded }
    }

    private var subtitle: String {
        if !tonight.isEmpty {
            return "Today: " + tonight.map(\.name).joined(separator: ", ")
        }
        let keys = Set(PlanCalendar.nextSevenDays.map(PlanCalendar.key(for:)))
        let upcoming = plans.filter { keys.contains($0.dayKey) }.count
        if upcoming > 0 {
            return "Nothing today · \(upcoming) coming up"
        }
        return "Plan your week's cooking"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("Meal Plan")
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(.background.secondary, in: .rect(cornerRadius: 16))
        .contentShape(.rect(cornerRadius: 16))
    }
}

/// On a recipe: choose a day in the coming week to cook it.
struct AddToPlanMenu: View {
    let meal: Meal
    /// This recipe's existing plan entries.
    let plans: [PlannedMeal]

    @Environment(\.modelContext) private var modelContext

    private var nextPlannedDay: Date? {
        let keys = PlanCalendar.nextSevenDays
        return keys.first { day in plans.contains { $0.dayKey == PlanCalendar.key(for: day) } }
    }

    var body: some View {
        Menu {
            Section("Add To") {
                ForEach(PlanCalendar.nextSevenDays, id: \.self) { day in
                    Button(PlanCalendar.title(for: day)) {
                        modelContext.insert(PlannedMeal(summary: summary, day: day))
                    }
                }
            }
        } label: {
            Label(nextPlannedDay.map { "Planned: " + PlanCalendar.title(for: $0) } ?? "Add to Meal Plan",
                  systemImage: nextPlannedDay == nil ? "calendar.badge.plus" : "calendar.badge.checkmark")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .sensoryFeedback(.success, trigger: plans.count) { old, new in new > old }
    }

    private var summary: MealSummary { meal.summary }
}

/// Choose a recipe for a day: the user's own and saved recipes, or anything from search.
struct AddPlannedMealView: View {
    let day: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomRecipe.dateModified, order: .reverse) private var myRecipes: [CustomRecipe]
    @Query(sort: \FavoriteMeal.dateAdded, order: .reverse) private var favorites: [FavoriteMeal]
    @AppStorage(DietFilter.storageKey) private var diet = DietFilter()

    @State private var query = ""
    @State private var results: [Meal] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    private var term: String { query.trimmingCharacters(in: .whitespaces) }

    private func matches(_ name: String) -> Bool {
        term.isEmpty || name.localizedCaseInsensitiveContains(term)
    }

    private var shownRecipes: [MealSummary] {
        myRecipes.filter { matches($0.name) }.map(\.summary)
    }

    private var shownFavorites: [MealSummary] {
        let ownIDs = Set(myRecipes.map(\.recipeID))
        return favorites.filter { !ownIDs.contains($0.mealID) && matches($0.name) }.map(\.summary)
    }

    /// Search results that aren't already listed above them.
    private var shownResults: [MealSummary] {
        let listed = Set((shownRecipes + shownFavorites).map(\.id))
        return results.map(\.summary).filter { !listed.contains($0.id) }
    }

    private var isEmpty: Bool {
        shownRecipes.isEmpty && shownFavorites.isEmpty && shownResults.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                section("My Recipes", shownRecipes)
                section("Favorites", shownFavorites)
                section("Search Results", shownResults)
            }
            .overlay {
                if isEmpty {
                    if isSearching {
                        ProgressView()
                    } else if let errorMessage {
                        ContentUnavailableView("Search Failed", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                    } else if term.isEmpty {
                        ContentUnavailableView("Find a Recipe", systemImage: "magnifyingglass",
                                               description: Text("Search for a recipe to add. Recipes you save will show up here too."))
                    } else {
                        ContentUnavailableView.search(text: term)
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search recipes")
            .navigationTitle(PlanCalendar.title(for: day))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .task(id: "\(term)|\(diet.rawValue)") {
                guard !term.isEmpty else {
                    results = []
                    errorMessage = nil
                    return
                }
                // Debounce typing; the task is cancelled when the text changes.
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                isSearching = true
                defer { isSearching = false }
                do {
                    let found = try await MealDBClient.shared.search(term)
                    guard !Task.isCancelled else { return }
                    results = found.filter(diet.allows)
                    errorMessage = nil
                } catch is CancellationError {
                } catch let error as URLError where error.code == .cancelled {
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ meals: [MealSummary]) -> some View {
        if !meals.isEmpty {
            Section(title) {
                ForEach(meals) { meal in
                    Button {
                        modelContext.insert(PlannedMeal(summary: meal, day: day))
                        dismiss()
                    } label: {
                        MealRow(meal: meal)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { MealPlanView() }
        .modelContainer(for: [PlannedMeal.self, CustomRecipe.self, PantryItem.self, ShoppingItem.self, FavoriteMeal.self], inMemory: true)
}
