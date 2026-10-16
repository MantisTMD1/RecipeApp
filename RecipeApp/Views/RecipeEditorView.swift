import SwiftUI
import SwiftData
import PhotosUI

/// Create or edit one of the user's own recipes.
struct RecipeEditorView: View {
    /// nil to create a new recipe.
    let recipe: CustomRecipe?
    /// Called after the recipe is deleted, so the screen showing it can close too.
    var onDelete: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var mealType: MealType?
    @State private var cuisine = ""
    @State private var ingredients: [EditableIngredient] = []
    @State private var instructions = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var photoChanged = false
    @State private var confirmingDelete = false
    @State private var confirmingDiscard = false
    @State private var didLoad = false
    @FocusState private var focusedIngredient: UUID?

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var hasChanges: Bool {
        guard let recipe else {
            return !trimmedName.isEmpty || photoData != nil || ingredients.contains { !$0.name.isEmpty }
                || !instructions.isEmpty || !cuisine.isEmpty
        }
        return name != recipe.name || mealType != recipe.mealType || cuisine != recipe.cuisine
            || instructions != recipe.instructions || photoChanged
            || ingredients.map(\.value) != recipe.ingredients
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    photoSection
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                Section {
                    TextField("Recipe name", text: $name)
                        .font(.title3.weight(.semibold))
                        .textInputAutocapitalization(.words)
                    Picker("Meal", selection: $mealType) {
                        Text("None").tag(MealType?.none)
                        ForEach(MealType.allCases) { Text($0.title).tag(MealType?.some($0)) }
                    }
                    TextField("Cuisine (optional)", text: $cuisine)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    ForEach($ingredients) { $ingredient in
                        HStack {
                            TextField("Ingredient", text: $ingredient.name)
                                .focused($focusedIngredient, equals: ingredient.id)
                                .textInputAutocapitalization(.words)
                            TextField("Amount", text: $ingredient.measure)
                                .multilineTextAlignment(.trailing)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: 120)
                        }
                    }
                    .onDelete { ingredients.remove(atOffsets: $0) }
                    .onMove { ingredients.move(fromOffsets: $0, toOffset: $1) }

                    Button("Add Ingredient", systemImage: "plus.circle.fill") {
                        let new = EditableIngredient()
                        ingredients.append(new)
                        focusedIngredient = new.id
                    }
                } header: {
                    Text("Ingredients")
                } footer: {
                    Text("Amounts like “2 cups” or “250g” scale when you change the recipe size.")
                }

                Section {
                    // TextEditor so Return starts a new line (a new step) instead of ending editing.
                    TextEditor(text: $instructions)
                        .frame(minHeight: 160)
                        .scrollContentBackground(.hidden)
                        .overlay(alignment: .topLeading) {
                            if instructions.isEmpty {
                                Text("Write each step on its own line.")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                } header: {
                    Text("Steps")
                } footer: {
                    Text("Each line becomes a step in cooking mode. Times like “bake for 20 minutes” get a timer.")
                }

                if recipe != nil {
                    Section {
                        Button("Delete Recipe", role: .destructive) { confirmingDelete = true }
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(recipe == nil ? "New Recipe" : "Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges { confirmingDiscard = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .interactiveDismissDisabled(hasChanges)
            .confirmationDialog("Discard your changes?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Discard Changes", role: .destructive) { dismiss() }
            }
            .confirmationDialog("Delete this recipe?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete Recipe", role: .destructive, action: delete)
            } message: {
                Text("This can't be undone.")
            }
            .onChange(of: photoItem) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        photoData = data
                        photoChanged = true
                    }
                }
            }
            .onAppear(perform: load)
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.background.secondary)
                if let photoData, let image = UIImage(data: photoData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 40))
                            .foregroundStyle(.tint)
                        Text("Add a Photo")
                            .font(.headline)
                    }
                }
            }
            .frame(height: 220)
            .clipShape(.rect(cornerRadius: 20))
            .overlay {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Color.clear.contentShape(.rect)
                }
                .accessibilityLabel(photoData == nil ? "Add a photo" : "Change photo")
            }

            if photoData != nil {
                Button("Remove Photo", role: .destructive) {
                    photoData = nil
                    photoItem = nil
                    photoChanged = true
                }
                .font(.subheadline)
            }
        }
        .padding(.vertical, 8)
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let recipe else {
            ingredients = [EditableIngredient(), EditableIngredient(), EditableIngredient()]
            return
        }
        name = recipe.name
        mealType = recipe.mealType
        cuisine = recipe.cuisine
        instructions = recipe.instructions
        ingredients = recipe.ingredients.map { EditableIngredient(value: $0) }
        if let url = recipe.photoURL { photoData = try? Data(contentsOf: url) }
    }

    private func save() {
        let target = recipe ?? {
            let new = CustomRecipe(name: trimmedName)
            modelContext.insert(new)
            return new
        }()
        target.name = trimmedName
        target.mealType = mealType
        target.cuisine = cuisine.trimmingCharacters(in: .whitespacesAndNewlines)
        target.instructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        target.ingredients = ingredients
            .map(\.value)
            .map { RecipeIngredient(name: $0.name.trimmingCharacters(in: .whitespaces),
                                    measure: $0.measure.trimmingCharacters(in: .whitespaces)) }
            .filter { !$0.name.isEmpty }
        if photoChanged || recipe == nil { target.setPhoto(photoData) }
        target.dateModified = .now
        try? modelContext.save()
        dismiss()
    }

    private func delete() {
        guard let recipe else { return }
        modelContext.deleteCustomRecipe(recipe)
        try? modelContext.save()
        dismiss()
        onDelete()
    }
}

private struct EditableIngredient: Identifiable {
    let id = UUID()
    var name = ""
    var measure = ""

    init() {}
    init(value: RecipeIngredient) {
        name = value.name
        measure = value.measure
    }

    var value: RecipeIngredient { RecipeIngredient(name: name, measure: measure) }
}

#Preview {
    RecipeEditorView(recipe: nil)
        .modelContainer(for: [CustomRecipe.self, FavoriteMeal.self], inMemory: true)
}
