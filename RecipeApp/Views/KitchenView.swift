import SwiftUI
import SwiftData

/// Screens pushed from the Kitchen tab. Value-based so pushed screens keep their state
/// when SwiftData changes cause the kitchen list to re-render.
enum KitchenRoute: Hashable {
    case suggestions
}

struct KitchenView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PantryItem.name) private var pantry: [PantryItem]
    @State private var showingPicker = false

    var body: some View {
        NavigationStack {
            List {
                if !pantry.isEmpty {
                    Section {
                        NavigationLink(value: KitchenRoute.suggestions) {
                            Label("What Can I Make?", systemImage: "sparkles")
                                .font(.headline)
                                .foregroundStyle(.tint)
                        }
                    }
                }

                Section(pantry.isEmpty ? "" : "In My Kitchen (\(pantry.count))") {
                    ForEach(pantry) { item in
                        HStack(spacing: 12) {
                            AsyncImage(url: IngredientInfo(id: "", name: item.name).thumbnailURL) { image in
                                image.resizable().scaledToFit()
                            } placeholder: {
                                Color.clear
                            }
                            .frame(width: 32, height: 32)
                            Text(item.name)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { modelContext.delete(pantry[index]) }
                    }
                }
            }
            .overlay {
                if pantry.isEmpty {
                    ContentUnavailableView {
                        Label("Your Kitchen Is Empty", systemImage: "refrigerator")
                    } description: {
                        Text("Add the ingredients you have, and we'll suggest recipes you can make.")
                    } actions: {
                        Button("Add Ingredients") { showingPicker = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("My Kitchen")
            .navigationDestination(for: KitchenRoute.self) { _ in
                SuggestionsView()
            }
            .navigationDestination(for: MealSummary.self) { meal in
                MealDetailView(summary: meal)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Ingredients", systemImage: "plus") { showingPicker = true }
                }
                if !pantry.isEmpty {
                    ToolbarItem(placement: .topBarLeading) { EditButton() }
                }
            }
            .sheet(isPresented: $showingPicker) {
                IngredientPickerView()
            }
        }
    }
}

/// Searchable list of TheMealDB's ingredients; tap to add or remove from the kitchen.
struct IngredientPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var pantry: [PantryItem]

    @State private var ingredients: [IngredientInfo] = []
    @State private var query = ""
    @State private var errorMessage: String?
    @FocusState private var isSearching: Bool

    private var pantryNames: Set<String> { Set(pantry.map { $0.name.lowercased() }) }

    private var filtered: [IngredientInfo] {
        let term = query.trimmingCharacters(in: .whitespaces)
        let list = term.isEmpty ? ingredients : ingredients.filter { $0.name.localizedCaseInsensitiveContains(term) }
        // Prefix matches first, so "egg" shows "Egg" before "Aubergine".
        return list.sorted {
            let a = $0.name.lowercased().hasPrefix(term.lowercased())
            let b = $1.name.lowercased().hasPrefix(term.lowercased())
            return a != b ? a : $0.name < $1.name
        }
    }

    var body: some View {
        NavigationStack {
            List(filtered) { ingredient in
                let selected = pantryNames.contains(ingredient.name.lowercased())
                Button {
                    toggle(ingredient)
                } label: {
                    HStack(spacing: 12) {
                        AsyncImage(url: ingredient.thumbnailURL) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Color.clear
                        }
                        .frame(width: 32, height: 32)
                        Text(ingredient.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                            .font(.title3)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            .scrollDismissesKeyboard(.immediately)
            .overlay {
                if let errorMessage {
                    ContentUnavailableView("Couldn't Load Ingredients", systemImage: "wifi.exclamationmark", description: Text(errorMessage))
                } else if ingredients.isEmpty {
                    ProgressView()
                } else if filtered.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            // A custom field instead of .searchable: the system search bar hides the
            // navigation bar (and its Done button) while the user is typing.
            .safeAreaInset(edge: .top) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search ingredients", text: $query)
                        .focused($isSearching)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                    if !query.isEmpty {
                        Button("Clear Search", systemImage: "xmark.circle.fill") { query = "" }
                            .labelStyle(.iconOnly)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.background.secondary, in: .capsule)
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .navigationTitle("Add Ingredients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                guard ingredients.isEmpty else { return }
                do {
                    ingredients = try await MealDBClient.shared.allIngredients()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func toggle(_ ingredient: IngredientInfo) {
        if let existing = pantry.first(where: { $0.name.caseInsensitiveCompare(ingredient.name) == .orderedSame }) {
            modelContext.delete(existing)
        } else {
            modelContext.insert(PantryItem(name: ingredient.name))
        }
    }
}

#Preview {
    KitchenView()
        .modelContainer(for: PantryItem.self, inMemory: true)
}
