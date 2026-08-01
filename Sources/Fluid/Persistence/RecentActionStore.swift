import Foundation

struct RecentActionEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let command: String
    let succeeded: Bool
    let context: String

    var menuTitle: String {
        "\(self.succeeded ? "✓" : "✗") \(self.command)"
    }

    var pasteText: String {
        """
        Action: \(self.command)
        Result: \(self.succeeded ? "Succeeded" : "Failed")
        Time: \(self.timestamp.formatted(date: .abbreviated, time: .standard))

        \(self.context)
        """
    }
}

@MainActor
final class RecentActionStore {
    static let shared = RecentActionStore()

    private static let defaultsKey = "RecentActionEntries"
    private static let maximumEntries = 50
    private(set) var entries: [RecentActionEntry]

    private init(defaults: UserDefaults = .standard) {
        if let data = defaults.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([RecentActionEntry].self, from: data)
        {
            self.entries = decoded
        } else {
            self.entries = []
        }
    }

    func record(command: String, succeeded: Bool, context: String) {
        self.entries.insert(
            RecentActionEntry(
                id: UUID(),
                timestamp: Date(),
                command: command,
                succeeded: succeeded,
                context: context
            ),
            at: 0
        )
        self.entries = Array(self.entries.prefix(Self.maximumEntries))
        if let data = try? JSONEncoder().encode(self.entries) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
