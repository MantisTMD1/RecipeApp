import SwiftUI

enum Appearance: String, CaseIterable, Identifiable {
    case dark, light, system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: "Dark"
        case .light: "Light"
        case .system: "System"
        }
    }

    /// nil lets the app follow the device setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appearance") private var appearance: Appearance = .dark
    @AppStorage("assumeStaples") private var assumeStaples = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section {
                    Toggle("Assume Pantry Staples", isOn: $assumeStaples)
                } header: {
                    Text("Recipe Ideas")
                } footer: {
                    Text("Treat salt, pepper, oil, flour, sugar, butter and water as always on hand.")
                }

                Section {
                    Link("Recipe data from TheMealDB", destination: URL(string: "https://www.themealdb.com")!)
                } footer: {
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
