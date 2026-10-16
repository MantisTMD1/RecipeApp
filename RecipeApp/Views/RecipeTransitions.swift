import SwiftUI

// Opening a recipe zooms it out of the card or row that was tapped, and closing it
// shrinks it back. Each tab's NavigationStack provides a namespace through the environment;
// cards mark themselves as the source and the recipe screen as the destination.

extension EnvironmentValues {
    @Entry var recipeZoomNamespace: Namespace.ID?
}

extension View {
    /// Marks a card or row as where the recipe zooms from.
    func recipeZoomSource(id: String) -> some View {
        modifier(RecipeZoomSource(id: id))
    }

    /// The recipe screen that zooms out of its source.
    func recipeZoomDestination(id: String) -> some View {
        modifier(RecipeZoomDestination(id: id))
    }
}

private struct RecipeZoomSource: ViewModifier {
    let id: String
    @Environment(\.recipeZoomNamespace) private var namespace

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(id: id, in: namespace) { source in
                source.clipShape(.rect(cornerRadius: 16))
            }
        } else {
            content
        }
    }
}

private struct RecipeZoomDestination: ViewModifier {
    let id: String
    @Environment(\.recipeZoomNamespace) private var namespace

    func body(content: Content) -> some View {
        if let namespace {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}

/// Gives a tab's NavigationStack its own zoom namespace.
struct RecipeZoomScope: ViewModifier {
    @Namespace private var namespace

    func body(content: Content) -> some View {
        content.environment(\.recipeZoomNamespace, namespace)
    }
}

extension View {
    func recipeZoomScope() -> some View { modifier(RecipeZoomScope()) }
}
