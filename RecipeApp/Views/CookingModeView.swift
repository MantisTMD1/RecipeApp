import SwiftUI
import AudioToolbox
import UserNotifications

/// Full-screen, one step at a time, with the screen kept awake and tap-to-start timers
/// for any time a step mentions.
struct CookingModeView: View {
    let meal: Meal
    let scale: RecipeScale

    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var timers = CookingTimers()
    @State private var showingIngredients = false

    private var steps: [String] { meal.steps }
    private var isLastStep: Bool { step == steps.count - 1 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressHeader

                TabView(selection: $step) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, text in
                        StepPage(number: index + 1, text: text, timers: timers)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.snappy, value: step)

                if !timers.items.isEmpty {
                    RunningTimersBar(timers: timers)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                navigationButtons
            }
            .animation(.snappy, value: timers.items.map(\.id))
            .navigationTitle(meal.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Ingredients", systemImage: "list.bullet") { showingIngredients = true }
                }
            }
            .sheet(isPresented: $showingIngredients) {
                IngredientsSheet(ingredients: meal.ingredients.map { $0.scaled(by: scale.rawValue) }, scale: scale)
                    .presentationDetents([.medium, .large])
            }
        }
        .sensoryFeedback(.selection, trigger: step)
        .sensoryFeedback(.success, trigger: timers.finishedCount)
        // Keep the screen on while cooking.
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Step \(step + 1) of \(steps.count)")
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.numericText())
                Spacer()
                if scale != .single {
                    Text("\(scale.title) amounts")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            ProgressView(value: Double(step + 1), total: Double(max(steps.count, 1)))
                .tint(.accentColor)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            Button {
                step -= 1
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(step == 0)

            Button {
                if isLastStep { dismiss() } else { step += 1 }
            } label: {
                Label(isLastStep ? "Done" : "Next", systemImage: isLastStep ? "checkmark" : "chevron.right")
                    .labelStyle(TrailingIconLabelStyle(trailing: !isLastStep))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .font(.headline)
        .controlSize(.large)
        .padding()
    }
}

/// One instruction, large enough to read from across the kitchen.
private struct StepPage: View {
    let number: Int
    let text: String
    let timers: CookingTimers

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(text)
                    .font(.title2)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)

                let found = CookTime.timers(in: text)
                if !found.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(found, id: \.seconds) { timer in
                            Button {
                                timers.start(label: timer.label, seconds: timer.seconds, step: number)
                            } label: {
                                Label("Start \(timer.label) timer", systemImage: "timer")
                                    .font(.headline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(.tint.opacity(0.15), in: .capsule)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tint)
                        }
                    }
                }
            }
            .padding(24)
        }
    }
}

/// Countdown chips for every running timer; finished timers turn red until dismissed.
private struct RunningTimersBar: View {
    let timers: CookingTimers

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(timers.items) { timer in
                        let remaining = timer.remaining(at: context.date)
                        HStack(spacing: 8) {
                            Image(systemName: remaining > 0 ? "timer" : "bell.fill")
                                .symbolEffect(.wiggle, isActive: remaining == 0)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(remaining > 0 ? CookingTimers.clock(remaining) : "Done!")
                                    .font(.headline.monospacedDigit())
                                Text("Step \(timer.step) · \(timer.label)")
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                            Button("Stop timer", systemImage: "xmark.circle.fill") {
                                timers.cancel(timer)
                            }
                            .labelStyle(.iconOnly)
                            .font(.title3)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundStyle(remaining > 0 ? AnyShapeStyle(.primary) : AnyShapeStyle(.white))
                        .background(remaining > 0 ? AnyShapeStyle(.background.secondary) : AnyShapeStyle(.red),
                                    in: .capsule)
                    }
                }
                .padding(.horizontal)
            }
            .onChange(of: context.date) { _, now in timers.checkFinished(at: now) }
        }
        .padding(.top, 8)
    }
}

private struct IngredientsSheet: View {
    let ingredients: [Ingredient]
    let scale: RecipeScale
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(ingredients) { ingredient in
                HStack(alignment: .firstTextBaseline) {
                    Text(ingredient.name)
                    Spacer()
                    Text(ingredient.measure)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            .navigationTitle(scale == .single ? "Ingredients" : "Ingredients (\(scale.title))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct TrailingIconLabelStyle: LabelStyle {
    var trailing: Bool
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            if trailing {
                configuration.title
                configuration.icon
            } else {
                configuration.icon
                configuration.title
            }
        }
    }
}

// MARK: - Timers

/// Kitchen timers for one cooking session. Each also schedules a local notification so it
/// still alerts if the phone is locked or the app is in the background.
@Observable
final class CookingTimers {
    struct Item: Identifiable {
        let id = UUID()
        let label: String
        let step: Int
        let end: Date
        var hasAlerted = false

        func remaining(at date: Date) -> Int { max(0, Int(end.timeIntervalSince(date).rounded(.up))) }
    }

    private(set) var items: [Item] = []
    /// Bumped whenever a timer finishes, to trigger haptics.
    private(set) var finishedCount = 0

    func start(label: String, seconds: Int, step: Int) {
        let item = Item(label: label, step: step, end: .now.addingTimeInterval(TimeInterval(seconds)))
        items.append(item)
        Task { await Self.scheduleNotification(for: item, seconds: seconds) }
    }

    func cancel(_ item: Item) {
        items.removeAll { $0.id == item.id }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [item.id.uuidString])
    }

    func checkFinished(at date: Date) {
        for index in items.indices where !items[index].hasAlerted && items[index].remaining(at: date) == 0 {
            items[index].hasAlerted = true
            finishedCount += 1
            AudioServicesPlaySystemSound(1005)
        }
    }

    static func clock(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    private static func scheduleNotification(for item: Item, seconds: Int) async {
        let center = UNUserNotificationCenter.current()
        // Asks only the first time a timer is started; the timer still works in the app if declined.
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        let content = UNMutableNotificationContent()
        content.title = "Timer done"
        content.body = "Step \(item.step): your \(item.label) timer is up."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        try? await center.add(UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger))
    }
}
