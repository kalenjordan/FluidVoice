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

    var troubleshootingClipboardText: String {
        """
        Voice Action Troubleshooting Context

        Action: \(self.command)
        Result: \(self.succeeded ? "Succeeded" : "Failed")
        Time: \(self.timestamp.formatted(date: .abbreviated, time: .standard))

        \(self.context)
        """
    }
}

struct CopyableResult: Equatable {
    enum Kind: Equatable {
        case transcription
        case action
    }

    let timestamp: Date
    let text: String
    let kind: Kind

    static func latest(
        transcriptions: [TranscriptionHistoryEntry],
        actions: [RecentActionEntry]
    ) -> CopyableResult? {
        let transcription = transcriptions.first(where: { $0.troubleshootingClipboardText != nil }).flatMap { entry in
            entry.troubleshootingClipboardText.map {
                CopyableResult(timestamp: entry.timestamp, text: $0, kind: .transcription)
            }
        }
        let action = actions.first.map {
            CopyableResult(
                timestamp: $0.timestamp,
                text: $0.troubleshootingClipboardText,
                kind: .action
            )
        }

        switch (transcription, action) {
        case let (transcription?, action?):
            return action.timestamp > transcription.timestamp ? action : transcription
        case let (transcription?, nil):
            return transcription
        case let (nil, action?):
            return action
        case (nil, nil):
            return nil
        }
    }

    @MainActor
    static var latest: CopyableResult? {
        self.latest(
            transcriptions: TranscriptionHistoryStore.shared.entries,
            actions: RecentActionStore.shared.entries
        )
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
