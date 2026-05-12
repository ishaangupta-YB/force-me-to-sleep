import Foundation

/// Loads the bundled quotes.json once. Returns a random quote per mood while
/// avoiding the most recent few repeats so the user feels variety.
final class QuoteLibrary: QuoteProviding {
    static let shared = QuoteLibrary()

    private struct Bank: Decodable {
        let sleep: [Quote]
        let wake: [Quote]
        let windDown: [Quote]
    }

    private let bank: Bank
    private var recentHistory: [Mood: [String]] = [:]
    private let lock = NSLock()

    private init() {
        self.bank = Self.loadBundle()
    }

    func random(_ mood: Mood) -> Quote {
        lock.lock(); defer { lock.unlock() }
        let pool = pool(for: mood)
        guard !pool.isEmpty else {
            return Quote(text: "Rest now. Tomorrow is a new beginning.", author: nil)
        }

        let recent = Set(recentHistory[mood] ?? [])
        let fresh = pool.filter { !recent.contains($0.text) }
        let chosen = (fresh.isEmpty ? pool : fresh).randomElement() ?? pool[0]

        var history = recentHistory[mood] ?? []
        history.append(chosen.text)
        if history.count > min(20, pool.count - 1) {
            history.removeFirst(history.count - min(20, pool.count - 1))
        }
        recentHistory[mood] = history

        return chosen
    }

    private func pool(for mood: Mood) -> [Quote] {
        switch mood {
        case .sleep:    return bank.sleep
        case .wake:     return bank.wake
        case .windDown: return bank.windDown
        }
    }

    // MARK: - Loading

    private static func loadBundle() -> Bank {
        let candidates: [Bundle?] = [Bundle.module, Bundle.main]
        for bundle in candidates.compactMap({ $0 }) {
            if let url = bundle.url(forResource: "quotes", withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode(Bank.self, from: data) {
                return decoded
            }
        }
        return Bank(
            sleep: [
                Quote(text: "Let go of the day. Sleep is a soft return to yourself.", author: nil),
                Quote(text: "The breath comes, the breath goes. Rest in the spaces between.", author: nil)
            ],
            wake: [
                Quote(text: "You did not wake up today to be mediocre.", author: nil),
                Quote(text: "Discipline is choosing what you want most over what you want now.", author: nil)
            ],
            windDown: [
                Quote(text: "Dim the lights. Let your nervous system know the day is closing.", author: nil)
            ]
        )
    }
}
