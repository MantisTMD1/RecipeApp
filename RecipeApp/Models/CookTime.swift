import Foundation

/// A rough cooking-time estimate read from a recipe's instructions.
/// TheMealDB has no time field, so this adds up durations mentioned in the steps
/// ("simmer for 20 minutes", "bake 1-2 hours"), keeping hands-off waiting
/// (marinating, chilling, rising...) separate from active cooking.
struct CookTime: Equatable {
    /// Minutes of active cooking.
    let active: Int
    /// Minutes of waiting, such as marinating or chilling.
    let waiting: Int
    /// What most of the waiting is, e.g. "marinating".
    let waitingKind: String?

    /// Below this, estimates are too unreliable to show.
    static let minimumActive = 10

    var isReliable: Bool { active >= Self.minimumActive }

    init(active: Int, waiting: Int, waitingKind: String?) {
        self.active = active
        self.waiting = waiting
        self.waitingKind = waitingKind
    }

    init(instructions: String) {
        var active = 0.0
        var waitingByKind: [String: Double] = [:]

        for sentence in Self.sentences(in: instructions) {
            let minutes = Self.minutesMentioned(in: sentence)
            let lower = sentence.lowercased()
            let kind = Self.waitingKinds.first { kind in kind.keywords.contains { lower.contains($0) } }

            if let kind {
                // "Leave overnight" with no explicit duration counts as 8 hours.
                let wait = minutes > 0 ? minutes : (lower.contains("overnight") ? 480 : 0)
                waitingByKind[kind.label, default: 0] += wait
            } else {
                active += minutes
            }
        }

        let waiting = waitingByKind.values.reduce(0, +)
        self.init(active: Int(active.rounded()),
                  waiting: Int(waiting.rounded()),
                  waitingKind: waitingByKind.max { $0.value < $1.value }?.key)
    }

    // MARK: Formatting

    /// "About 45 min", "About 1 hr 15 min".
    var activeText: String { "About " + Self.format(Self.round(active)) }

    /// "+ 8 hr marinating", or nil when there's no meaningful waiting time.
    var waitingText: String? {
        guard waiting >= 15 else { return nil }
        return "+ " + Self.format(Self.round(waiting)) + " " + (waitingKind ?? "waiting")
    }

    /// Nearest 5 minutes under an hour, nearest 15 minutes above.
    static func round(_ minutes: Int) -> Int {
        let step = minutes < 60 ? 5 : 15
        return max(step, Int((Double(minutes) / Double(step)).rounded()) * step)
    }

    static func format(_ minutes: Int) -> String {
        let hours = minutes / 60, rest = minutes % 60
        switch (hours, rest) {
        case (0, _): return "\(rest) min"
        case (_, 0): return "\(hours) hr"
        default: return "\(hours) hr \(rest) min"
        }
    }

    // MARK: Parsing

    private struct WaitingKind {
        let label: String
        let keywords: [String]
    }

    private static let waitingKinds: [WaitingKind] = [
        WaitingKind(label: "marinating", keywords: ["marinat"]),
        WaitingKind(label: "rising", keywords: ["rise", "prove", "proof", "double in size"]),
        WaitingKind(label: "chilling", keywords: ["chill", "refrigerat", "fridge", "freez", "overnight"]),
        WaitingKind(label: "soaking", keywords: ["soak"]),
        WaitingKind(label: "resting", keywords: ["rest", "cool", "stand", "set aside", "sit "]),
    ]

    private static let numberWords: [String: Double] = [
        "a": 1, "an": 1, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "ten": 10, "fifteen": 15, "twenty": 20, "thirty": 30, "forty": 40,
    ]

    // "20 minutes", "1-2 hours", "1 to 1.5 hrs", "an hour", "half an hour", "45mins".
    private static let durationPattern = try! NSRegularExpression(
        pattern: #"\b(\d+(?:\.\d+)?|a|an|one|two|three|four|five|six|ten|fifteen|twenty|thirty|forty|half an?)(?:\s*(?:-|–|to|or)\s*(\d+(?:\.\d+)?))?\s*(hours?|hrs?|minutes?|mins?)\b"#,
        options: [.caseInsensitive])

    /// Durations mentioned in a piece of text, for timer buttons: "simmer for 20-25 minutes"
    /// gives one 25-minute timer labelled "25 min".
    static func timers(in text: String) -> [(label: String, seconds: Int)] {
        let range = NSRange(text.startIndex..., in: text)
        var seen = Set<Int>()
        return durationPattern.matches(in: text, range: range).compactMap { match in
            let minutes = minutesMentioned(in: (text as NSString).substring(with: match.range))
            let seconds = Int((minutes * 60).rounded())
            guard seconds >= 60, seconds <= 12 * 3600, seen.insert(seconds).inserted else { return nil }
            return (format(seconds / 60), seconds)
        }
    }

    private static func sentences(in text: String) -> [String] {
        var result: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sentence, _, _, _ in
            if let sentence { result.append(sentence) }
        }
        return result
    }

    private static func minutesMentioned(in sentence: String) -> Double {
        let range = NSRange(sentence.startIndex..., in: sentence)
        return durationPattern.matches(in: sentence, range: range).reduce(0) { total, match in
            func group(_ i: Int) -> String? {
                Range(match.range(at: i), in: sentence).map { String(sentence[$0]).lowercased() }
            }
            guard let first = group(1), let unit = group(3) else { return total }
            var value = first.hasPrefix("half") ? 0.5 : (Double(first) ?? numberWords[first] ?? 0)
            // For ranges like "1-2 hours", use the upper end so the estimate isn't optimistic.
            if let upper = group(2).flatMap(Double.init) { value = max(value, upper) }
            return total + (unit.hasPrefix("h") ? value * 60 : value)
        }
    }
}
