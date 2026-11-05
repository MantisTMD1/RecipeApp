import Foundation
import SwiftData
import CoreData

/// The app's database, kept in the user's private iCloud account when one is available.
enum RecipeStore {
    static let cloudContainerID = "iCloud.com.mantistmd1.recipes"

    static let modelTypes: [any PersistentModel.Type] = [
        FavoriteMeal.self, PantryItem.self, ShoppingItem.self, CustomRecipe.self, PlannedMeal.self,
    ]

    static let container: ModelContainer = {
        let schema = Schema(modelTypes)
        #if DEBUG
        // CloudKit only learns about fields it has seen, so this publishes the whole schema to
        // the development environment. Run once with this launch argument after a model change.
        if CommandLine.arguments.contains("-InitCloudKitSchema") { initializeCloudKitSchema() }
        #endif
        do {
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .private(cloudContainerID))
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            // Keep the app usable on this device if iCloud can't be set up.
            let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("Couldn't open the recipe database: \(error)")
            }
        }
    }()

    #if DEBUG
    private static func initializeCloudKitSchema() {
        guard let model = NSManagedObjectModel.makeManagedObjectModel(for: modelTypes) else { return }
        let url = URL.temporaryDirectory.appending(path: "cloudkit-schema.store")
        let description = NSPersistentStoreDescription(url: url)
        description.shouldAddStoreAsynchronously = false
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: cloudContainerID)
        let container = NSPersistentCloudKitContainer(name: "SchemaSetup", managedObjectModel: model)
        container.persistentStoreDescriptions = [description]
        container.loadPersistentStores { _, error in
            if let error { print("CloudKit schema: couldn't open store: \(error)") }
        }
        do {
            try container.initializeCloudKitSchema()
            print("CloudKit schema: initialized")
        } catch {
            print("CloudKit schema: failed: \(error)")
        }
        for store in container.persistentStoreCoordinator.persistentStores {
            try? container.persistentStoreCoordinator.remove(store)
        }
    }
    #endif
}

extension ModelContext {
    /// Tidies up after a sync. CloudKit can't enforce unique values, so two devices can each add
    /// "Eggs" and end up with both. Every device must keep the same copy, or each could delete
    /// the one the other kept, so the winner is chosen only from values that sync.
    func reconcileSyncedData() {
        mergeDuplicates(of: PantryItem.self,
                        key: { IngredientMatcher.normalize($0.name) },
                        keepFirst: { ($0.dateAdded, $0.name) < ($1.dateAdded, $1.name) })

        mergeDuplicates(of: FavoriteMeal.self,
                        key: \.mealID,
                        keepFirst: { ($0.dateAdded, $0.name) < ($1.dateAdded, $1.name) })

        mergeDuplicates(of: ShoppingItem.self,
                        key: { IngredientMatcher.normalize($0.name) },
                        keepFirst: { ($0.dateAdded, $0.name, $0.measure) < ($1.dateAdded, $1.name, $1.measure) },
                        combine: { kept, duplicate in
                            kept.isChecked = kept.isChecked && duplicate.isChecked
                            kept.recipes += duplicate.recipes.filter { !kept.recipes.contains($0) }
                            kept.recipes.sort()
                        })

        mergeDuplicates(of: CustomRecipe.self,
                        key: \.recipeID,
                        keepFirst: { ($1.dateModified, $1.dateCreated) < ($0.dateModified, $0.dateCreated) })

        syncRecipePhotos()

        if hasChanges { try? save() }
    }

    private func mergeDuplicates<Item: PersistentModel>(
        of type: Item.Type,
        key: (Item) -> String,
        keepFirst: (Item, Item) -> Bool,
        combine: (Item, Item) -> Void = { _, _ in }
    ) {
        let items = (try? fetch(FetchDescriptor<Item>())) ?? []
        for group in Dictionary(grouping: items, by: key).values where group.count > 1 {
            let sorted = group.sorted(by: keepFirst)
            for duplicate in sorted.dropFirst() {
                combine(sorted[0], duplicate)
                delete(duplicate)
            }
        }
    }

    /// Photos live in the database so they sync, with a file on each device for showing them.
    private func syncRecipePhotos() {
        // A failed read must not look like "no recipes", or every photo file would be cleared out.
        guard let recipes = try? fetch(FetchDescriptor<CustomRecipe>()) else { return }
        for recipe in recipes {
            recipe.reconcilePhoto()
        }
        CustomRecipe.removeUnusedPhotoFiles(keeping: Set(recipes.compactMap(\.photoFilename)))
    }
}
