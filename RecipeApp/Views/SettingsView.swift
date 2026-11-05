import SwiftUI
import CloudKit

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
    @AppStorage(UserName.storageKey) private var userName = ""
    @AppStorage(DietFilter.storageKey) private var diet = DietFilter()
    @State private var iCloudStatus: CKAccountStatus?

    private var iCloudFootnote: String {
        switch iCloudStatus {
        case .available, nil:
            "Your kitchen, saved recipes, shopping list and meal plan stay up to date on devices signed in to your iCloud account. Settings stay on each device."
        case .restricted:
            "iCloud is restricted on this device. Your data is still saved here."
        case .temporarilyUnavailable:
            "iCloud isn't available right now. Your data is still saved here and will sync when it's back."
        default:
            "Sign in to iCloud in the Settings app to keep your data up to date across your devices. Your data is still saved here."
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Your name", text: $userName)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .onChange(of: userName) { _, newValue in
                            if newValue.count > UserName.maxLength { userName = String(newValue.prefix(UserName.maxLength)) }
                        }
                } header: {
                    Text("Your Name")
                } footer: {
                    Text("Used for your welcome message. Leave it blank to turn the greeting off. It never leaves this device.")
                }

                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section {
                    Toggle("Vegetarian", isOn: $diet.vegetarian)
                    Toggle("Vegan", isOn: $diet.vegan)
                    Toggle("Gluten-free", isOn: $diet.glutenFree)
                    Toggle("Dairy-free", isOn: $diet.dairyFree)
                } header: {
                    Text("Diet")
                } footer: {
                    Text("Hides recipes that don't fit, based on their ingredient lists. Always check labels if you have an allergy.")
                }

                Section {
                    Toggle("Assume Pantry Staples", isOn: $assumeStaples)
                } header: {
                    Text("Recipe Ideas")
                } footer: {
                    Text("Treat salt, pepper, oil, flour, sugar, butter and water as always on hand.")
                }

                Section {
                    LabeledContent("Sync", value: iCloudStatus == .available ? "On" : iCloudStatus == nil ? "Checking…" : "Off")
                } header: {
                    Text("iCloud")
                } footer: {
                    Text(iCloudFootnote)
                }

                Section {
                    Link("Recipe data from TheMealDB", destination: URL(string: "https://www.themealdb.com")!)
                } footer: {
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                }
            }
            .task {
                iCloudStatus = (try? await CKContainer(identifier: RecipeStore.cloudContainerID).accountStatus()) ?? .couldNotDetermine
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
