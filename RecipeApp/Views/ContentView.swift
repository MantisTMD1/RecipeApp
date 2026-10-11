import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(filter: #Predicate<ShoppingItem> { !$0.isChecked }) private var toBuy: [ShoppingItem]
    @AppStorage(UserName.storageKey) private var userName = ""
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @Environment(\.scenePhase) private var scenePhase

    @State private var greeting: String?
    @State private var wasInBackground = false

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                HomeView()
            }
            Tab("Kitchen", systemImage: "refrigerator") {
                KitchenView()
            }
            Tab("List", systemImage: "cart") {
                ShoppingListView()
            }
            .badge(toBuy.count)
            Tab("Favorites", systemImage: "heart") {
                FavoritesView()
            }
            Tab(role: .search) {
                SearchView()
            }
        }
        .overlay(alignment: .top) {
            if let greeting {
                WelcomeBanner(text: greeting)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .allowsHitTesting(false)
            }
        }
        .fullScreenCover(isPresented: .constant(!hasOnboarded)) {
            NamePromptView { name in
                userName = name
                hasOnboarded = true
                if !name.isEmpty { showGreeting("Welcome, \(name)!") }
            }
        }
        // Greet on launch and whenever the app comes back from the background.
        .task { greetReturningUser() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                wasInBackground = true
            case .active where wasInBackground:
                wasInBackground = false
                greetReturningUser()
            default:
                break
            }
        }
    }

    private func greetReturningUser() {
        let name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasOnboarded, !name.isEmpty else { return }
        showGreeting("Welcome back, \(name)!")
    }

    private func showGreeting(_ text: String) {
        Task {
            // A short delay lets the screen settle so the banner's slide-in is visible.
            try? await Task.sleep(for: .milliseconds(400))
            withAnimation(.spring(duration: 0.5)) { greeting = text }
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation(.easeInOut(duration: 0.4)) {
                if greeting == text { greeting = nil }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [FavoriteMeal.self, PantryItem.self, ShoppingItem.self], inMemory: true)
}
