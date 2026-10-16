import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.selectTab) private var selectTab
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingItem.dateAdded) private var items: [ShoppingItem]
    @Query private var pantry: [PantryItem]

    @State private var newItem = ""
    @FocusState private var isAdding: Bool

    private var toBuy: [ShoppingItem] { items.filter { !$0.isChecked } }
    private var checked: [ShoppingItem] { items.filter(\.isChecked) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.tint)
                            .font(.title3)
                        TextField("Add an item", text: $newItem)
                            .focused($isAdding)
                            .submitLabel(.done)
                            .onSubmit(addManualItem)
                    }
                }

                if items.isEmpty {
                    Section {
                        EmptyStateView(systemImage: "cart.fill",
                                       accents: ["basket.fill", "carrot.fill", "leaf.fill"],
                                       title: "Your List Is Empty",
                                       message: "Add missing ingredients from any recipe with one tap, or type an item above.") {
                            Button {
                                selectTab(.kitchen)
                            } label: {
                                Label("Find Recipe Ideas", systemImage: "sparkles")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                        .scrollDisabled(true)
                        .frame(height: 440)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                if !toBuy.isEmpty {
                    Section("To Buy (\(toBuy.count))") {
                        ForEach(toBuy) { ShoppingRow(item: $0) }
                            .onDelete { delete(toBuy, at: $0) }
                    }
                }

                if !checked.isEmpty {
                    Section {
                        ForEach(checked) { ShoppingRow(item: $0) }
                            .onDelete { delete(checked, at: $0) }
                    } header: {
                        Text("In Cart (\(checked.count))")
                    } footer: {
                        Text("“Move to Kitchen” adds checked items to your kitchen and removes them from this list.")
                    }
                }
            }
            .animation(.default, value: items.map(\.isChecked))
            .navigationTitle("Shopping List")
            .toolbar {
                if !checked.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Menu("Checked Items", systemImage: "ellipsis") {
                            Button("Move to Kitchen", systemImage: "refrigerator", action: moveCheckedToKitchen)
                            Button("Remove Checked", systemImage: "trash", role: .destructive) {
                                checked.forEach(modelContext.delete)
                            }
                        }
                    }
                }
                if !items.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        ShareLink(item: shareText) {
                            Label("Share List", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    private var shareText: String {
        toBuy.map { item in
            item.measure.isEmpty ? "• \(item.name)" : "• \(item.name) (\(item.measure))"
        }.joined(separator: "\n")
    }

    private func addManualItem() {
        let name = newItem.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        modelContext.addToShoppingList([Ingredient(name: name, measure: "")], from: nil)
        newItem = ""
        isAdding = true
    }

    private func delete(_ list: [ShoppingItem], at offsets: IndexSet) {
        for index in offsets { modelContext.delete(list[index]) }
    }

    private func moveCheckedToKitchen() {
        let have = Set(pantry.map { IngredientMatcher.normalize($0.name) })
        for item in checked {
            if !have.contains(IngredientMatcher.normalize(item.name)) {
                modelContext.insert(PantryItem(name: item.name))
            }
            modelContext.delete(item)
        }
    }
}

private struct ShoppingRow: View {
    @Bindable var item: ShoppingItem

    var body: some View {
        Button {
            item.isChecked.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isChecked ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.name)
                            .strikethrough(item.isChecked)
                            .foregroundStyle(item.isChecked ? .secondary : .primary)
                        Spacer()
                        if !item.measure.isEmpty {
                            Text(item.measure)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !item.recipes.isEmpty {
                        Text("For " + item.recipes.joined(separator: ", "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ShoppingListView()
        .modelContainer(for: [ShoppingItem.self, PantryItem.self], inMemory: true)
}
