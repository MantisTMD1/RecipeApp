import SwiftUI

/// A friendlier empty screen: a small illustration built from SF Symbols, a headline,
/// a message, and whatever actions the screen needs.
struct EmptyStateView<Actions: View>: View {
    let systemImage: String
    /// Small icons that float around the main one.
    var accents: [String] = ["leaf.fill", "carrot.fill", "fork.knife"]
    let title: String
    let message: String
    @ViewBuilder var actions: Actions

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                EmptyStateIllustration(systemImage: systemImage, accents: accents)
                    .padding(.top, 40)

                VStack(spacing: 8) {
                    Text(title)
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    actions
                }
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 40)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct EmptyStateIllustration: View {
    let systemImage: String
    let accents: [String]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var floating = false

    // Where each accent icon sits around the main one.
    private let positions: [CGSize] = [.init(width: -78, height: -46), .init(width: 82, height: -24), .init(width: -64, height: 58)]

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.05)],
                                     center: .center, startRadius: 10, endRadius: 90))
                .frame(width: 168, height: 168)

            Image(systemName: systemImage)
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)

            ForEach(Array(accents.prefix(positions.count).enumerated()), id: \.offset) { index, symbol in
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.tint.opacity(0.8))
                    .padding(10)
                    .background(.background.secondary, in: .circle)
                    .offset(positions[index])
                    .offset(y: floating ? (index.isMultiple(of: 2) ? -5 : 5) : 0)
            }
        }
        .frame(height: 190)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { floating = true }
        }
    }
}

/// Buttons for "Add Eggs", "Add Milk"…, so a new user can fill their kitchen in a few taps.
struct QuickAddChips: View {
    let items: [String]
    let isAdded: (String) -> Bool
    let toggle: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(items, id: \.self) { item in
                let added = isAdded(item)
                Button {
                    withAnimation(.snappy) { toggle(item) }
                } label: {
                    HStack(spacing: 4) {
                        AsyncImage(url: IngredientInfo(id: "", name: item).thumbnailURL) { image in
                            image.resizable().scaledToFit()
                        } placeholder: {
                            Color.clear
                        }
                        .frame(width: 22, height: 22)
                        Text(item)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        if added {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(added ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                    .background(added ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(.tertiarySystemFill)), in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(added ? "\(item), added" : "Add \(item)")
            }
        }
        .sensoryFeedback(.selection, trigger: items.filter(isAdded).count)
    }
}

extension EnvironmentValues {
    /// Lets a screen send the user to another tab, e.g. "Browse Recipes" from an empty list.
    @Entry var selectTab: (AppTab) -> Void = { _ in }
}
