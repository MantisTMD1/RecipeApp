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

    /// Ingredients grouped by first letter ("#" for anything that isn't A–Z), for browsing.
    private var sections: [(letter: String, items: [IngredientInfo])] {
        let groups = Dictionary(grouping: ingredients.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending },
                                by: { IngredientPickerView.indexLetter(for: $0.name) })
        return groups.keys
            .sorted { ($0 == "#" ? "~" : $0) < ($1 == "#" ? "~" : $1) }
            .map { ($0, groups[$0]!) }
    }

    private var isBrowsing: Bool { query.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    if isBrowsing {
                        ForEach(sections, id: \.letter) { section in
                            Section {
                                ForEach(section.items) { row($0) }
                            } header: {
                                Text(section.letter)
                                    .id(section.letter)
                            }
                        }
                    } else {
                        ForEach(filtered) { row($0) }
                    }
                }
                .scrollDismissesKeyboard(.immediately)
                .overlay(alignment: .trailing) {
                    if isBrowsing && !ingredients.isEmpty {
                        AlphabetIndex(letters: sections.map(\.letter)) { letter in
                            proxy.scrollTo(letter, anchor: .top)
                        }
                        .padding(.trailing, 2)
                    }
                }
            }
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

    private func row(_ ingredient: IngredientInfo) -> some View {
        let selected = pantryNames.contains(ingredient.name.lowercased())
        return Button {
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
        // Leave room for the A–Z index on the right.
        .padding(.trailing, isBrowsing ? 8 : 0)
    }

    /// "A"–"Z" for names starting with a letter (accents ignored), otherwise "#".
    static func indexLetter(for name: String) -> String {
        let first = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased().first.map(String.init) ?? "#"
        return ("A"..."Z").contains(first) && first.count == 1 ? first : "#"
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

/// A Contacts-style A–Z strip: tap a letter or drag along it to jump through the list.
private struct AlphabetIndex: View {
    let letters: [String]
    let onSelect: (String) -> Void

    @State private var current: String?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(letters, id: \.self) { letter in
                Text(letter)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 18)
                    .frame(maxHeight: 16)
            }
        }
        .padding(.vertical, 6)
        .background(current == nil ? AnyShapeStyle(.clear) : AnyShapeStyle(.background.secondary), in: .capsule)
        .contentShape(.rect)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in select(atY: value.location.y) }
                .onEnded { _ in withAnimation(.easeOut(duration: 0.2)) { current = nil } }
        )
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .overlay(alignment: .leading) {
            // Large letter bubble while dragging, like Contacts.
            if let current {
                Text(current)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(.tint, in: .circle)
                    .offset(x: -84)
                    .transition(.scale.combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .sensoryFeedback(.selection, trigger: current)
        .accessibilityElement()
        .accessibilityLabel("Alphabet index")
        .accessibilityAdjustableAction { direction in
            let index = letters.firstIndex(of: current ?? letters[0]) ?? 0
            let next = direction == .increment ? min(index + 1, letters.count - 1) : max(index - 1, 0)
            current = letters[next]
            onSelect(letters[next])
        }
    }

    @State private var height: CGFloat = 1

    private func select(atY y: CGFloat) {
        guard !letters.isEmpty else { return }
        let usable = max(height - 12, 1)
        let index = min(max(Int((y - 6) / usable * CGFloat(letters.count)), 0), letters.count - 1)
        let letter = letters[index]
        guard letter != current else { return }
        withAnimation(.snappy(duration: 0.15)) { current = letter }
        onSelect(letter)
    }
}
