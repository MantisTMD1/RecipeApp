import SwiftUI

/// Shown once, on first launch, to ask for the user's name.
struct NamePromptView: View {
    /// Called with the entered name, or an empty string if the user skips.
    let onFinish: (String) -> Void

    @State private var name = ""
    @FocusState private var isFocused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "hand.wave.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            VStack(spacing: 8) {
                Text("Welcome to Recipe Rescue")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("What's your name?")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            TextField("Your name", text: $name)
                .font(.title2)
                .multilineTextAlignment(.center)
                .textContentType(.name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused($isFocused)
                .onSubmit(finish)
                .padding(.vertical, 14)
                .background(.background.secondary, in: .rect(cornerRadius: 14))
                .onChange(of: name) { _, newValue in
                    if newValue.count > UserName.maxLength { name = String(newValue.prefix(UserName.maxLength)) }
                }

            Text("Your name is only used to greet you and never leaves this device.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button(action: finish) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(trimmed.isEmpty)

            Button("Skip") { onFinish("") }
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .onAppear { isFocused = true }
    }

    private func finish() {
        guard !trimmed.isEmpty else { return }
        onFinish(trimmed)
    }
}

/// The small "Welcome back" banner that slides in from the top.
struct WelcomeBanner: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "hand.wave.fill")
            .font(.headline)
            .labelStyle(BannerLabelStyle())
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: .capsule)
            .shadow(color: .black.opacity(0.2), radius: 12, y: 4)
            .padding(.top, 8)
            .padding(.horizontal)
            .accessibilityAddTraits(.isStaticText)
    }

    private struct BannerLabelStyle: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 8) {
                configuration.icon.foregroundStyle(.tint)
                configuration.title
            }
        }
    }
}

enum UserName {
    static let storageKey = "userName"
    static let maxLength = 30
}

#Preview("Name prompt") {
    NamePromptView { _ in }
}

#Preview("Banner") {
    WelcomeBanner(text: "Welcome back, Evan!")
}
