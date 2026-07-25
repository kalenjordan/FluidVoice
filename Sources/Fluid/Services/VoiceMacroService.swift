import AppKit
import Carbon.HIToolbox
import Foundation

enum VoiceMacroService {
    struct HerdrWorkspace: Decodable, Equatable {
        let label: String
        let workspaceID: String

        enum CodingKeys: String, CodingKey {
            case label
            case workspaceID = "workspace_id"
        }
    }

    private struct HerdrWorkspaceListResponse: Decodable {
        struct Result: Decodable {
            let workspaces: [HerdrWorkspace]
        }

        let result: Result
    }

    private static let herdrBundleIDs = ["com.mitchellh.ghostty"]
    private static let herdrAppNames = ["ghostty", "herdr"]
    private static let chromeBundleIDs = ["com.google.chrome"]

    // Add observed speech-to-text variants here when fuzzy matching is not sufficient.
    private static let workspaceAliases: [String: [String]] = [
        "comms": ["coms", "comms workspace"],
        "fluidvoice": ["fluid voice", "fluid boys"],
        "commerce-land": ["commerce land"],
        "commerce-leak": ["commerce leak"],
    ]

    static func herdrWorkspaceQuery(
        transcript: String,
        appName: String,
        bundleID: String,
        windowTitle: String
    ) -> String? {
        guard self.isHerdr(appName: appName, bundleID: bundleID, windowTitle: windowTitle) else {
            return nil
        }
        return self.commandArgument(transcript, command: "open")
    }

    static func chromeFindQuery(transcript: String, bundleID: String) -> String? {
        guard self.chromeBundleIDs.contains(bundleID.lowercased()) else { return nil }
        return self.commandArgument(transcript, command: "find")
    }

    static func resolveWorkspace(query: String, workspaces: [HerdrWorkspace]) -> HerdrWorkspace? {
        let normalizedQuery = self.normalizedPhrase(query)
        guard !normalizedQuery.isEmpty else { return nil }

        if let exact = workspaces.first(where: { self.normalizedPhrase($0.label) == normalizedQuery }) {
            return exact
        }

        let aliasMatches = workspaces.filter { workspace in
            let aliases = self.workspaceAliases[workspace.label.lowercased()] ?? []
            return aliases.contains { self.normalizedPhrase($0) == normalizedQuery }
        }
        if aliasMatches.count == 1 {
            return aliasMatches[0]
        }

        let scored = workspaces.map {
            ($0, self.editDistance(normalizedQuery, self.normalizedPhrase($0.label)))
        }.sorted { $0.1 < $1.1 }
        guard let best = scored.first else { return nil }

        let maximumDistance = max(1, min(3, normalizedQuery.count / 4))
        guard best.1 <= maximumDistance else { return nil }
        guard scored.count == 1 || scored[1].1 > best.1 else { return nil }
        return best.0
    }

    static func openHerdrWorkspace(query: String) async -> Bool {
        guard let executable = self.herdrExecutableURL() else { return false }
        let listResult = await self.runProcess(executable, arguments: ["workspace", "list"])
        guard listResult.status == 0,
              let response = try? JSONDecoder().decode(
                  HerdrWorkspaceListResponse.self,
                  from: listResult.output
              ),
              let workspace = self.resolveWorkspace(
                  query: query,
                  workspaces: response.result.workspaces
              )
        else {
            return false
        }

        let focusResult = await self.runProcess(
            executable,
            arguments: ["workspace", "focus", workspace.workspaceID]
        )
        return focusResult.status == 0
    }

    @MainActor
    static func runChromeFind(query: String, targetPID: pid_t) async -> Bool {
        guard self.isTargetFrontmost(targetPID) else { return false }
        guard self.postKey(CGKeyCode(kVK_ANSI_F), flags: .maskCommand, to: targetPID) else {
            return false
        }

        try? await Task.sleep(nanoseconds: 150_000_000)
        guard self.isTargetFrontmost(targetPID) else { return false }
        return self.postText(query, to: targetPID)
    }

    private static func isHerdr(appName: String, bundleID: String, windowTitle: String) -> Bool {
        let normalizedAppName = appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedBundleID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedWindowTitle = windowTitle.lowercased()

        return self.herdrBundleIDs.contains(normalizedBundleID)
            || self.herdrAppNames.contains(normalizedAppName)
            || normalizedWindowTitle.contains("herdr")
    }

    private static func commandArgument(_ transcript: String, command: String) -> String? {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let commandRange = trimmed.range(
            of: #"^\#(command)\s+"#,
            options: [.regularExpression, .caseInsensitive]
        ) else {
            return nil
        }

        let argument = trimmed[commandRange.upperBound...]
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return argument.isEmpty ? nil : argument
    }

    private static func normalizedPhrase(_ text: String) -> String {
        let words = text.lowercased().split {
            $0.isWhitespace || $0.isPunctuation
        }
        return words.joined(separator: " ")
    }

    private static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)
        var previous = Array(0 ... right.count)

        for (leftIndex, leftCharacter) in left.enumerated() {
            var current = [leftIndex + 1]
            for (rightIndex, rightCharacter) in right.enumerated() {
                current.append(min(
                    current[rightIndex] + 1,
                    previous[rightIndex + 1] + 1,
                    previous[rightIndex] + (leftCharacter == rightCharacter ? 0 : 1)
                ))
            }
            previous = current
        }
        return previous[right.count]
    }

    private static func herdrExecutableURL() -> URL? {
        let candidates = [
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".local/bin/herdr"),
            URL(fileURLWithPath: "/opt/homebrew/bin/herdr"),
            URL(fileURLWithPath: "/usr/local/bin/herdr"),
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private static func runProcess(
        _ executable: URL,
        arguments: [String]
    ) async -> (status: Int32, output: Data) {
        await Task.detached {
            let process = Process()
            let outputPipe = Pipe()
            process.executableURL = executable
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = Pipe()

            do {
                try process.run()
                process.waitUntilExit()
                return (process.terminationStatus, outputPipe.fileHandleForReading.readDataToEndOfFile())
            } catch {
                return (-1, Data())
            }
        }.value
    }

    @MainActor
    private static func isTargetFrontmost(_ targetPID: pid_t) -> Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier == targetPID
    }

    private static func postKey(
        _ keyCode: CGKeyCode,
        flags: CGEventFlags = [],
        to targetPID: pid_t
    ) -> Bool {
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        else {
            return false
        }

        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.postToPid(targetPID)
        keyUp.postToPid(targetPID)
        return true
    }

    private static func postText(_ text: String, to targetPID: pid_t) -> Bool {
        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
        else {
            return false
        }

        let characters = Array(text.utf16)
        keyDown.keyboardSetUnicodeString(stringLength: characters.count, unicodeString: characters)
        keyUp.keyboardSetUnicodeString(stringLength: 0, unicodeString: nil)
        keyDown.postToPid(targetPID)
        keyUp.postToPid(targetPID)
        return true
    }
}
