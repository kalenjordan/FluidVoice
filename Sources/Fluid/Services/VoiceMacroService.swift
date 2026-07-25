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

    struct HerdrWorkspaceInvocation: Equatable {
        let workspace: HerdrWorkspace
        let trailingText: String?
    }

    struct CodexWeeklyStatus: Equatable {
        let usedPercent: Double
        let windowDurationMinutes: Double
        let resetsAt: Date

        func summary(now: Date = Date()) -> String {
            let windowStart = self.resetsAt.addingTimeInterval(-self.windowDurationMinutes * 60)
            let windowDays = max(1, Int(ceil(self.windowDurationMinutes / (24 * 60))))
            let elapsedDays = max(
                1,
                min(windowDays, Int(ceil(now.timeIntervalSince(windowStart) / (24 * 60 * 60))))
            )
            let allowedPercent = Double(elapsedDays) / Double(windowDays) * 100
            let pace = self.usedPercent <= allowedPercent ? "On pace" : "Behind pace"
            let remainingPercent = max(0, 100 - self.usedPercent)

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "EEE 'at' h:mm a"
            return "Codex weekly: \(Int(remainingPercent.rounded()))% remaining\n"
                + "\(pace) · day \(elapsedDays) of \(windowDays)\n"
                + "Resets \(formatter.string(from: self.resetsAt))"
        }
    }

    private struct HerdrWorkspaceListResponse: Decodable {
        struct Result: Decodable {
            let workspaces: [HerdrWorkspace]
        }

        let result: Result
    }

    private static let herdrBundleIDs = ["com.mitchellh.ghostty"]
    private static let chromeBundleIDs = ["com.google.chrome"]
    private static let chatGPTBundleIDs = ["com.openai.chat"]
    private static let finderBundleIDs = ["com.apple.finder"]
    private static let codexBundleIDs = [
        "com.mitchellh.ghostty",
        "com.openai.codex",
    ]
    private static let installedApplicationURLs: [URL] = {
        let fileManager = FileManager.default
        let roots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications", isDirectory: true),
        ]
        var applications: [URL] = []

        for root in roots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let url as URL in enumerator where url.pathExtension.lowercased() == "app" {
                applications.append(url)
            }
        }
        return applications
    }()

    // Add observed speech-to-text variants here when fuzzy matching is not sufficient.
    private static let workspaceAliases: [String: [String]] = [
        "comms": ["coms", "comms workspace"],
        "fluidvoice": ["fluid voice", "fluid boys"],
        "commerce-land": ["commerce land"],
        "commerce-leak": ["commerce leak"],
        "ordellan": ["or dell in", "or dallin", "or dall in"],
    ]
    private static let applicationAliases: [String: String] = [
        "chatgpt": "chatgptclassic",
    ]

    static func herdrWorkspaceQuery(transcript: String) -> String? {
        self.commandArgument(transcript, command: "herder", preserveTerminalPunctuation: true)
            ?? self.commandArgument(transcript, command: "herdr", preserveTerminalPunctuation: true)
            ?? self.commandArgument(transcript, command: "herter", preserveTerminalPunctuation: true)
    }

    static func applicationLaunchQuery(transcript: String) -> String? {
        if let applicationName = self.commandArgument(transcript, command: "launch") {
            return applicationName
        }

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let expression = try? NSRegularExpression(
            pattern: #"^open\s+(?:the\s+)?(.+?)\s+(?:app|application)$"#,
            options: .caseInsensitive
        ) else {
            return nil
        }

        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = expression.firstMatch(in: trimmed, range: range),
              let nameRange = Range(match.range(at: 1), in: trimmed)
        else {
            return nil
        }

        let applicationName = trimmed[nameRange].trimmingCharacters(in: .whitespacesAndNewlines)
        return applicationName.isEmpty ? nil : applicationName
    }

    static func chromeFindQuery(transcript: String, bundleID: String) -> String? {
        guard self.chromeBundleIDs.contains(bundleID.lowercased()) else { return nil }
        return self.commandArgument(transcript, command: "find")
    }

    static func chatGPTSearchQuery(transcript: String, bundleID: String) -> String? {
        guard self.chatGPTBundleIDs.contains(bundleID.lowercased()) else { return nil }
        return self.commandArgument(transcript, command: "search")
    }

    static func isChatGPTSidebarCommand(transcript: String, bundleID: String) -> Bool {
        self.chatGPTBundleIDs.contains(bundleID.lowercased())
            && self.normalizedPhrase(transcript) == "sidebar"
    }

    static func outboundDashURL(transcript: String) -> URL? {
        guard self.normalizedPhrase(transcript) == "outbound dash" else { return nil }
        return URL(string: "http://outbound-dash.localhost:8764")
    }

    static func chromeURL(transcript: String, bundleID: String) -> String? {
        guard self.chromeBundleIDs.contains(bundleID.lowercased()) else { return nil }
        let phrase = self.normalizedPhrase(transcript)
        guard phrase.hasPrefix("open "),
              phrase.hasSuffix(" dash")
        else {
            return nil
        }

        let clientName = phrase
            .dropFirst("open ".count)
            .dropLast(" dash".count)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientName.isEmpty else { return nil }

        let slug = clientName.replacingOccurrences(of: " ", with: "-")
        return "http://outbound-dash.localhost:8764/clients/\(slug)"
    }

    static func isFinderDeleteCommand(transcript: String, bundleID: String) -> Bool {
        self.finderBundleIDs.contains(bundleID.lowercased())
            && self.normalizedPhrase(transcript) == "delete"
    }

    static func isCodexClearLineCommand(transcript: String, bundleID: String) -> Bool {
        guard self.codexBundleIDs.contains(bundleID.lowercased()) else { return false }
        let phrase = self.normalizedPhrase(transcript)
        return phrase == "clear line" || phrase == "slash clear line"
    }

    static func isCodexStatusCommand(transcript: String) -> Bool {
        self.normalizedPhrase(transcript) == "codex status"
            || self.normalizedPhrase(transcript) == "codec status"
    }

    static func codexWeeklyStatus() async -> CodexWeeklyStatus? {
        guard let executable = self.codexExecutableURL() else { return nil }
        let input = [
            #"{"id":1,"method":"initialize","params":{"clientInfo":{"name":"fluidvoice","title":"FluidVoice","version":"1.0"},"capabilities":{"experimentalApi":true}}}"#,
            #"{"method":"initialized","params":{}}"#,
            #"{"id":2,"method":"account/rateLimits/read","params":{}}"#,
        ].joined(separator: "\n") + "\n"
        let result = await self.runProcess(
            executable,
            arguments: ["app-server", "--stdio"],
            standardInput: Data(input.utf8),
            standardInputCloseDelay: 1
        )
        guard result.status == 0 else { return nil }

        for line in result.output.split(separator: 0x0A) {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  (object["id"] as? NSNumber)?.intValue == 2,
                  let response = object["result"] as? [String: Any],
                  let rateLimits = response["rateLimits"] as? [String: Any],
                  let primary = rateLimits["primary"] as? [String: Any],
                  let usedPercent = (primary["usedPercent"] as? NSNumber)?.doubleValue,
                  let windowMinutes = (primary["windowDurationMins"] as? NSNumber)?.doubleValue,
                  let resetsAt = (primary["resetsAt"] as? NSNumber)?.doubleValue
            else {
                continue
            }
            return CodexWeeklyStatus(
                usedPercent: usedPercent,
                windowDurationMinutes: windowMinutes,
                resetsAt: Date(timeIntervalSince1970: resetsAt)
            )
        }
        return nil
    }

    @MainActor
    static func showStatusToast(_ text: String) {
        VoiceMacroStatusToast.shared.show(text)
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

    static func resolveWorkspaceInvocation(
        query: String,
        workspaces: [HerdrWorkspace]
    ) -> HerdrWorkspaceInvocation? {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty,
              let expression = try? NSRegularExpression(pattern: #"\S+"#)
        else {
            return nil
        }

        let queryRange = NSRange(query.startIndex..., in: query)
        let words = expression.matches(in: query, range: queryRange)
        for wordCount in stride(from: words.count, through: 1, by: -1) {
            let prefixRange = NSRange(
                location: 0,
                length: words[wordCount - 1].range.location + words[wordCount - 1].range.length
            )
            guard let swiftPrefixRange = Range(prefixRange, in: query),
                  let workspace = self.resolveWorkspace(
                      query: String(query[swiftPrefixRange]),
                      workspaces: workspaces
                  )
            else {
                continue
            }

            let trailingText = query[swiftPrefixRange.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ",:;-"))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return HerdrWorkspaceInvocation(
                workspace: workspace,
                trailingText: trailingText.isEmpty ? nil : trailingText
            )
        }
        return nil
    }

    @MainActor
    static func openHerdrWorkspace(query: String) async -> Bool {
        guard let executable = self.herdrExecutableURL() else { return false }
        let listResult = await self.runProcess(executable, arguments: ["workspace", "list"])
        guard listResult.status == 0,
              let response = try? JSONDecoder().decode(
                  HerdrWorkspaceListResponse.self,
                  from: listResult.output
              ),
              let invocation = self.resolveWorkspaceInvocation(
                  query: query,
                  workspaces: response.result.workspaces
              )
        else {
            return false
        }

        let focusResult = await self.runProcess(
            executable,
            arguments: ["workspace", "focus", invocation.workspace.workspaceID]
        )
        guard focusResult.status == 0 else { return false }

        guard let herdrApplication = NSRunningApplication.runningApplications(
            withBundleIdentifier: self.herdrBundleIDs[0]
        ).first else {
            return false
        }
        guard herdrApplication.activate(
            options: [.activateAllWindows, .activateIgnoringOtherApps]
        ) else {
            return false
        }

        guard let trailingText = invocation.trailingText else { return true }
        try? await Task.sleep(nanoseconds: 150_000_000)
        guard self.isTargetFrontmost(herdrApplication.processIdentifier) else { return false }
        return self.postText(trailingText, to: herdrApplication.processIdentifier)
    }

    @MainActor
    static func launchApplication(named applicationName: String) async -> Bool {
        guard let applicationURL = self.resolveApplicationURL(
            query: applicationName,
            candidates: self.installedApplicationURLs
        ) else {
            return false
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false
        return await withCheckedContinuation { continuation in
            NSWorkspace.shared.openApplication(
                at: applicationURL,
                configuration: configuration
            ) { _, error in
                continuation.resume(returning: error == nil)
            }
        }
    }

    static func resolveApplicationURL(query: String, candidates: [URL]) -> URL? {
        let rawNormalizedQuery = self.normalizedApplicationName(query)
        let normalizedQuery = self.applicationAliases[rawNormalizedQuery] ?? rawNormalizedQuery
        guard !normalizedQuery.isEmpty else { return nil }

        let namedCandidates = candidates.map {
            ($0, self.normalizedApplicationName($0.deletingPathExtension().lastPathComponent))
        }
        let exactMatches = namedCandidates.filter { $0.1 == normalizedQuery }
        if exactMatches.count == 1 {
            return exactMatches[0].0
        }
        guard exactMatches.isEmpty else { return nil }

        let scored = namedCandidates.map {
            ($0.0, self.editDistance(normalizedQuery, $0.1))
        }.sorted { $0.1 < $1.1 }
        guard let best = scored.first else { return nil }

        let maximumDistance = max(1, min(2, normalizedQuery.count / 5))
        guard best.1 <= maximumDistance else { return nil }
        guard scored.count == 1 || scored[1].1 > best.1 else { return nil }
        return best.0
    }

    @MainActor
    static func openOrFocusOutboundDashInChrome(_ url: URL) -> Bool {
        let baseURL = url.absoluteString
        let script = """
        tell application "Google Chrome"
            repeat with windowIndex from 1 to count of windows
                set chromeWindow to window windowIndex
                repeat with tabIndex from 1 to count of tabs of chromeWindow
                    set tabURL to URL of tab tabIndex of chromeWindow
                    if tabURL is "\(baseURL)" or tabURL is "\(baseURL)/" then
                        set active tab index of chromeWindow to tabIndex
                        set index of chromeWindow to 1
                        activate
                        return true
                    end if
                end repeat
            end repeat

            if (count of windows) is 0 then
                make new window
                set URL of active tab of front window to "\(baseURL)"
            else
                tell front window
                    make new tab at end of tabs with properties {URL:"\(baseURL)"}
                    set active tab index to count of tabs
                end tell
            end if
            activate
            return true
        end tell
        """

        var error: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
        return result?.booleanValue == true && error == nil
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

    @MainActor
    static func runChatGPTSearch(query: String, targetPID: pid_t) async -> Bool {
        guard self.isTargetFrontmost(targetPID) else { return false }
        guard self.postKey(
            CGKeyCode(kVK_ANSI_F),
            flags: [.maskCommand, .maskShift],
            to: targetPID
        ) else {
            return false
        }

        try? await Task.sleep(nanoseconds: 150_000_000)
        guard self.isTargetFrontmost(targetPID) else { return false }
        return self.postText(query, to: targetPID)
    }

    @MainActor
    static func toggleChatGPTSidebar(targetPID: pid_t) -> Bool {
        guard self.isTargetFrontmost(targetPID) else { return false }
        return self.postKey(
            CGKeyCode(kVK_ANSI_S),
            flags: [.maskControl, .maskCommand],
            to: targetPID
        )
    }

    @MainActor
    static func openChromeURL(_ url: String, targetPID: pid_t) async -> Bool {
        guard self.isTargetFrontmost(targetPID) else { return false }
        guard self.postKey(CGKeyCode(kVK_ANSI_L), flags: .maskCommand, to: targetPID) else {
            return false
        }

        try? await Task.sleep(nanoseconds: 150_000_000)
        guard self.isTargetFrontmost(targetPID),
              self.postText(url, to: targetPID)
        else {
            return false
        }

        try? await Task.sleep(nanoseconds: 50_000_000)
        guard self.isTargetFrontmost(targetPID) else { return false }
        return self.postKey(CGKeyCode(kVK_Return), to: targetPID)
    }

    @MainActor
    static func deleteFinderSelection(targetPID: pid_t) -> Bool {
        guard self.isTargetFrontmost(targetPID) else { return false }
        return self.postKey(CGKeyCode(kVK_Delete), flags: .maskCommand, to: targetPID)
    }

    @MainActor
    static func clearCodexLine(targetPID: pid_t) -> Bool {
        guard self.isTargetFrontmost(targetPID) else { return false }
        // Codex has no one-shot clear-all shortcut for its multiline composer.
        // Repeated Ctrl-K removes every line after the cursor; repeated Ctrl-U
        // then removes the current line and every line before it.
        let maximumComposerLines = 256
        for _ in 0..<maximumComposerLines {
            guard self.postKey(CGKeyCode(kVK_ANSI_K), flags: .maskControl, to: targetPID) else {
                return false
            }
        }
        for _ in 0..<maximumComposerLines {
            guard self.postKey(CGKeyCode(kVK_ANSI_U), flags: .maskControl, to: targetPID) else {
                return false
            }
        }
        return true
    }

    private static func commandArgument(
        _ transcript: String,
        command: String,
        preserveTerminalPunctuation: Bool = false
    ) -> String? {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let commandRange = trimmed.range(
            of: #"^\#(command)[\s\p{P}]+"#,
            options: [.regularExpression, .caseInsensitive]
        ) else {
            return nil
        }

        var argument = String(trimmed[commandRange.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !preserveTerminalPunctuation {
            argument = argument
                .trimmingCharacters(in: CharacterSet(charactersIn: ".!?"))
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return argument.isEmpty ? nil : argument
    }

    private static func normalizedPhrase(_ text: String) -> String {
        let words = text.lowercased().split {
            $0.isWhitespace || $0.isPunctuation
        }
        return words.joined(separator: " ")
    }

    private static func normalizedApplicationName(_ text: String) -> String {
        text.lowercased().filter { $0.isLetter || $0.isNumber }
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

    private static func codexExecutableURL() -> URL? {
        let candidates = [
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".local/bin/codex"),
            URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
            URL(fileURLWithPath: "/usr/local/bin/codex"),
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private static func runProcess(
        _ executable: URL,
        arguments: [String],
        standardInput: Data? = nil,
        standardInputCloseDelay: TimeInterval = 0
    ) async -> (status: Int32, output: Data) {
        await Task.detached {
            let process = Process()
            let outputPipe = Pipe()
            let inputPipe = Pipe()
            process.executableURL = executable
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = Pipe()
            if standardInput != nil {
                process.standardInput = inputPipe
            }

            do {
                try process.run()
                if let standardInput {
                    inputPipe.fileHandleForWriting.write(standardInput)
                    if standardInputCloseDelay > 0 {
                        Thread.sleep(forTimeInterval: standardInputCloseDelay)
                    }
                    try? inputPipe.fileHandleForWriting.close()
                }
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

@MainActor
private final class VoiceMacroStatusToast {
    static let shared = VoiceMacroStatusToast()

    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")
    private var hideTask: Task<Void, Never>?

    private init() {
        self.panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.panel.level = .statusBar
        self.panel.isOpaque = false
        self.panel.backgroundColor = .clear
        self.panel.hasShadow = true
        self.panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        self.label.font = .systemFont(ofSize: 14, weight: .medium)
        self.label.textColor = .labelColor
        self.label.maximumNumberOfLines = 3
        self.label.lineBreakMode = .byWordWrapping
        self.label.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(self.label)
        NSLayoutConstraint.activate([
            self.label.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 18),
            self.label.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -18),
            self.label.topAnchor.constraint(equalTo: background.topAnchor, constant: 14),
            self.label.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -14),
            self.label.widthAnchor.constraint(equalToConstant: 260),
        ])
        self.panel.contentView = background
    }

    func show(_ text: String) {
        self.hideTask?.cancel()
        self.label.stringValue = text
        self.panel.contentView?.layoutSubtreeIfNeeded()
        let size = self.panel.contentView?.fittingSize ?? NSSize(width: 296, height: 84)
        let screenFrame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? .zero
        self.panel.setFrame(
            NSRect(
                x: screenFrame.maxX - size.width - 24,
                y: screenFrame.maxY - size.height - 24,
                width: size.width,
                height: size.height
            ),
            display: true
        )
        self.panel.orderFrontRegardless()
        self.hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            self.panel.orderOut(nil)
        }
    }
}
