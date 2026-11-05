import Foundation
import SwiftData

/// A recipe the user plans to cook on a given day.
@Model
final class PlannedMeal {
    /// Identifies this entry when it's dragged to another day.
    var planID: String = ""
    var mealID: String = ""
    var name: String = ""
    /// Empty for the user's own recipes, whose photos are files local to each device.
    var thumbnailURL: URL?
    /// The calendar day as "2026-11-05". A plain date stays on the same day when the
    /// user changes time zone or syncs to a device set to another one.
    var dayKey: String = ""
    var dateAdded: Date = Date.now

    init(summary: MealSummary, day: Date) {
        planID = UUID().uuidString
        mealID = summary.id
        name = summary.name
        thumbnailURL = summary.thumbnailURL.flatMap { $0.isFileURL ? nil : $0 }
        dayKey = PlanCalendar.key(for: day)
    }

    var summary: MealSummary {
        MealSummary(id: mealID, name: name, thumbnailURL: thumbnailURL)
    }
}

/// Day and week arithmetic for the meal plan.
enum PlanCalendar {
    private static var calendar: Calendar { .current }

    static func key(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func startOfWeek(containing date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    static func days(ofWeekStarting start: Date) -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func week(after start: Date, by weeks: Int) -> Date {
        calendar.date(byAdding: .weekOfYear, value: weeks, to: start) ?? start
    }

    /// Today and the six days after it.
    static var nextSevenDays: [Date] {
        let today = calendar.startOfDay(for: .now)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }

    /// "Today", "Tomorrow", or "Saturday, Nov 7".
    static func title(for date: Date) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    /// "This Week", "Next Week", "Last Week", or "Nov 16 – 22".
    static func title(forWeekStarting start: Date) -> String {
        let current = startOfWeek(containing: .now)
        switch calendar.dateComponents([.weekOfYear], from: current, to: start).weekOfYear {
        case 0: return "This Week"
        case 1: return "Next Week"
        case -1: return "Last Week"
        default:
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            return (start..<end).formatted(.interval.month(.abbreviated).day())
        }
    }
}
