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

    private struct NewCodexTabInvocation {
        let trailingText: String?
    }

    struct DesktopDeletionResult: Equatable {
        let deletedCount: Int
        let failedCount: Int
    }

    enum TabDirection {
        case left
        case right
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

    private struct HerdrCurrentPaneResponse: Decodable {
        struct Result: Decodable {
            let pane: Pane
        }

        struct Pane: Decodable {
            struct AgentSession: Decodable {
                let value: String
            }

            let agent: String?
            let agentSession: AgentSession?
            let agentStatus: String?
            let cwd: String
            let paneID: String
            let tabID: String
            let workspaceID: String

            enum CodingKeys: String, CodingKey {
                case agent
                case agentSession = "agent_session"
                case agentStatus = "agent_status"
                case cwd
                case paneID = "pane_id"
                case tabID = "tab_id"
                case workspaceID = "workspace_id"
            }
        }

        let result: Result
    }

    private struct HerdrTabListResponse: Decodable {
        struct Result: Decodable {
            let tabs: [Tab]
        }

        struct Tab: Decodable {
            let number: Int
            let tabID: String

            enum CodingKeys: String, CodingKey {
                case number
                case tabID = "tab_id"
            }
        }

        let result: Result
    }

    private struct HerdrPaneListResponse: Decodable {
        struct Result: Decodable {
            let panes: [Pane]
        }

        struct Pane: Decodable {
            let agent: String?
            let agentStatus: String?
            let paneID: String
            let tabID: String

            enum CodingKeys: String, CodingKey {
                case agent
                case agentStatus = "agent_status"
                case paneID = "pane_id"
                case tabID = "tab_id"
            }
        }

        let result: Result
    }

    private struct HerdrTabCreateResponse: Decodable {
        struct Result: Decodable {
            let rootPane: RootPane

            enum CodingKeys: String, CodingKey {
                case rootPane = "root_pane"
            }
        }

        struct RootPane: Decodable {
            let paneID: String

            enum CodingKeys: String, CodingKey {
                case paneID = "pane_id"
            }
        }

        let result: Result
    }

    private struct HerdrWorkspaceCreateResponse: Decodable {
        struct Result: Decodable {
            let workspace: Workspace
            let rootPane: HerdrTabCreateResponse.RootPane

            enum CodingKeys: String, CodingKey {
                case workspace
                case rootPane = "root_pane"
            }
        }

        struct Workspace: Decodable {
            let workspaceID: String

            enum CodingKeys: String, CodingKey {
                case workspaceID = "workspace_id"
            }
        }

        let result: Result
    }

    private static let herdrBundleIDs = ["com.mitchellh.ghostty"]
    private static let herdrCommandAliases = [
        "edit",
    ]
    private static let bareHerdrWorkspaceAliases: [String: String] = [
        "fluidvoice": "fluidvoice",
        "nudges": "nudges",
    ]
    private static let herdrCallerEnvironmentVariables: Set<String> = [
        "HERDR_PANE_ID",
        "HERDR_TAB_ID",
        "HERDR_TERMINAL_ID",
        "HERDR_WORKSPACE_ID",
    ]
    private static let chromeBundleIDs = ["com.google.chrome"]
    private static let chatGPTBundleIDs = ["com.openai.chat"]
    private static let finderBundleIDs = ["com.apple.finder"]
    private static let spotifyBundleIDs = ["com.spotify.client"]
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
    private static let projectAliases: [String: [String]] = [
        "comms": ["coms", "comms workspace"],
        "fluidvoice": ["fluid voice", "fluid boys"],
        "commerce-land": ["commerce land"],
        "commerce-leak": ["commerce leak"],
        "hvac": ["h fact"],
        "ordellan": [
            "or dell and",
            "or dell in",
            "or dallin",
            "or dall in",
            "or delin",
        ],
    ]
    private static let applicationAliases: [String: String] = [
        "chatgpt": "chatgptclassic",
    ]

    static func herdrWorkspaceQuery(transcript: String, bundleID: String = "") -> String? {
        if let query = self.bareHerdrWorkspaceAliases[self.normalizedPhrase(transcript)] {
            return query
        }

        let globalQuery = self.herdrCommandArgument(
            transcript,
            preserveTerminalPunctuation: true
        )
        if let globalQuery {
            return globalQuery
        }

        guard self.herdrBundleIDs.contains(bundleID.lowercased()) else { return nil }
        if let query = self.commandArgument(
            transcript,
            command: "her",
            preserveTerminalPunctuation: true
        ) {
            return query
        }
        return nil
    }

    static func applicationLaunchQuery(
        transcript: String,
        candidates: [URL]? = nil
    ) -> String? {
        if self.normalizedPhrase(transcript) == "record meeting" {
            return "Anarlog"
        }

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
        if let match = expression.firstMatch(in: trimmed, range: range),
           let nameRange = Range(match.range(at: 1), in: trimmed)
        {
            let applicationName = trimmed[nameRange].trimmingCharacters(in: .whitespacesAndNewlines)
            return applicationName.isEmpty ? nil : applicationName
        }

        guard self.resolveApplicationURL(
            query: trimmed,
            candidates: candidates ?? self.installedApplicationURLs
        ) != nil else {
            return nil
        }
        return trimmed
    }

    static func chromeFindQuery(transcript: String, bundleID: String) -> String? {
        guard self.chromeBundleIDs.contains(bundleID.lowercased()) else { return nil }
        return self.commandArgument(transcript, command: "find")
    }

    static func isChromeRefreshCommand(transcript: String, bundleID: String) -> Bool {
        self.chromeBundleIDs.contains(bundleID.lowercased())
            && self.normalizedPhrase(transcript) == "refresh"
    }

    static func isChromeCopyURLCommand(transcript: String, bundleID: String) -> Bool {
        self.chromeBundleIDs.contains(bundleID.lowercased())
            && self.normalizedPhrase(transcript) == "copy url"
    }

    static func isChromeCloseTabCommand(transcript: String, bundleID: String) -> Bool {
        self.chromeBundleIDs.contains(bundleID.lowercased())
            && self.normalizedPhrase(transcript) == "close tab"
    }

    static func refreshChrome(targetPID: pid_t) -> Bool {
        self.postKey(CGKeyCode(kVK_ANSI_R), flags: .maskCommand, to: targetPID)
    }

    static func closeChromeTab(targetPID: pid_t) -> Bool {
        self.postKey(CGKeyCode(kVK_ANSI_W), flags: .maskCommand, to: targetPID)
    }

    static func isCloseWindowCommand(transcript: String) -> Bool {
        switch self.normalizedPhrase(transcript) {
        case "close window", "closed window", "window close":
            return true
        default:
            return false
        }
    }

    static func closeWindow(targetPID: pid_t) -> Bool {
        self.postKey(CGKeyCode(kVK_ANSI_W), flags: .maskCommand, to: targetPID)
    }

    static func isQuitApplicationCommand(transcript: String) -> Bool {
        switch self.normalizedPhrase(transcript) {
        case "exit", "quit":
            return true
        default:
            return false
        }
    }

    static func quitApplication(targetPID: pid_t) -> Bool {
        guard let application = NSRunningApplication(processIdentifier: targetPID),
              application.bundleIdentifier != Bundle.main.bundleIdentifier
        else {
            return false
        }
        return application.terminate()
    }

    @MainActor
    static func copyChromeURL(targetPID: pid_t) -> Bool {
        guard self.isTargetFrontmost(targetPID) else { return false }

        var error: NSDictionary?
        guard let url = NSAppleScript(
            source: #"tell application "Google Chrome" to get URL of active tab of front window"#
        )?.executeAndReturnError(&error).stringValue,
            error == nil,
            !url.isEmpty
        else {
            return false
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(url, forType: .string)
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
        let phrase = self.normalizedPhrase(transcript)
        switch phrase {
        case "outbound dash", "outbound ash":
            return URL(string: "http://outbound-dash.localhost:8764")
        case "signalflame site", "signal flame site":
            return URL(string: "http://signalflame.localhost:8780")
        case "hvac site":
            return URL(string: "http://hvac.localhost:8782")
        case "commerce leak site":
            return URL(string: "http://commerceleak.localhost:8781")
        case "ordellan site":
            return URL(string: "http://ordellan.localhost:8783")
        case "commerce land site", "commerceland site":
            return URL(string: "http://commerce-land.localhost:8784")
        case "matchbook site":
            return URL(string: "http://matchbook.localhost:8786")
        case "outbound farm site":
            return URL(string: "http://outbound.farm.localhost:8787")
        case "signalflame dash", "signal flame dash":
            return URL(string: "http://outbound-dash.localhost:8764/clients/signalflame")
        case "matchbook dash", "matt s book dash":
            return URL(string: "http://outbound-dash.localhost:8764/clients/matchbook")
        case "commerce land dash", "commerce landash", "commerce land ash", "commerce land act",
             "commerceland dash", "carmer s landash", "carmerce land dash":
            return URL(string: "http://outbound-dash.localhost:8764/clients/commerce-land")
        case "commerce leak dash", "commerce leaked ash":
            return URL(string: "http://outbound-dash.localhost:8764/clients/commerce-leak")
        case "linkedin crm", "linkedin dash", "linkedin crm dash":
            return URL(string: "http://outbound-dash.localhost:8764/clients/linkedin-crm")
        case "st3 dash", "s t three dash":
            return URL(string: "http://outbound-dash.localhost:8764/clients/st3aero?view=targets")
        case "layers dash":
            return URL(
                string: "http://outbound-dash.localhost:8764/clients/layers?card=cannot_outreach"
            )
        case "outbound farm dash":
            return URL(string: "http://outbound-dash.localhost:8764/clients/outbound-farm")
        case "hvac dash":
            return URL(
                string: "http://outbound-dash.localhost:8764/clients/hvac?card=opportunity_identified"
            )
        default:
            break
        }

        guard phrase.hasSuffix(" dash") else { return nil }
        let spokenProjectName = String(phrase.dropLast(" dash".count))
        guard let projectName = self.canonicalProjectName(for: spokenProjectName) else {
            return nil
        }
        switch projectName {
        case "hvac":
            return URL(
                string: "http://outbound-dash.localhost:8764/clients/hvac?card=opportunity_identified"
            )
        case "ordellan":
            return URL(string: "http://outbound-dash.localhost:8764/clients/ordellan")
        default:
            return nil
        }
    }

    static func gmailURL(transcript: String) -> URL? {
        guard self.normalizedPhrase(transcript) == "open gmail" else { return nil }
        return URL(
            string: "https://mail.google.com/mail/u/0/#search/fdsafdsafdsafdsafdsafdsafdsa"
        )
    }

    static func googleCalendarURL(transcript: String) -> URL? {
        guard self.normalizedPhrase(transcript) == "google calendar" else { return nil }
        return URL(string: "https://calendar.google.com/calendar/u/0/r")
    }

    static func googleSearchURL(transcript: String) -> URL? {
        guard let query = self.commandArgument(transcript, command: "google") else {
            return nil
        }

        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [URLQueryItem(name: "q", value: query)]
        return components?.url
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

        let slug = self.canonicalProjectName(for: clientName)
            ?? clientName.replacingOccurrences(of: " ", with: "-")
        if slug == "hvac" {
            return "http://outbound-dash.localhost:8764/clients/hvac?card=opportunity_identified"
        }
        if slug == "layers" {
            return "http://outbound-dash.localhost:8764/clients/layers?card=cannot_outreach"
        }
        return "http://outbound-dash.localhost:8764/clients/\(slug)"
    }

    static func isFinderDeleteCommand(transcript: String, bundleID: String) -> Bool {
        self.finderBundleIDs.contains(bundleID.lowercased())
            && self.normalizedPhrase(transcript) == "delete"
    }

    static func isDeleteDesktopCommand(transcript: String) -> Bool {
        self.normalizedPhrase(transcript) == "delete desktop"
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

    static func isAddSynonymCommand(transcript: String) -> Bool {
        self.normalizedPhrase(transcript) == "add synonym"
    }

    static func isRestartFluidVoiceCommand(transcript: String) -> Bool {
        self.normalizedPhrase(transcript) == "restart fluid voice"
    }

    static func isBackCommand(transcript: String) -> Bool {
        self.normalizedPhrase(transcript) == "back"
    }

    static func isWindowScreenshotCommand(transcript: String) -> Bool {
        switch self.normalizedPhrase(transcript) {
        case "screenshot window", "screen shot window":
            return true
        default:
            return false
        }
    }

    static func isWindowMiddleCommand(transcript: String) -> Bool {
        self.normalizedPhrase(transcript) == "window middle"
    }

    static let windowMiddleURL = URL(
        string: "rectangle-pro://execute-custom?name=Middle"
    )!

    static func moveWindowToMiddle() -> Bool {
        NSWorkspace.shared.open(self.windowMiddleURL)
    }

    static func isWindowTopLeftCommand(transcript: String) -> Bool {
        self.normalizedPhrase(transcript) == "window top left"
    }

    static func moveWindowToTopLeft(targetPID: pid_t) -> Bool {
        self.postKey(
            CGKeyCode(kVK_ANSI_U),
            flags: [.maskControl, .maskAlternate],
            to: targetPID
        )
    }

    static func herdrNotificationsEnabledCommand(
        transcript: String
    ) -> Bool? {
        switch self.normalizedPhrase(transcript) {
        case "notifications on":
            return true
        case "notifications off":
            return false
        default:
            return nil
        }
    }

    static func nudgesEnabledCommand(transcript: String) -> Bool? {
        switch self.normalizedPhrase(transcript) {
        case "nudges on":
            return true
        case "nudges off":
            return false
        default:
            return nil
        }
    }

    static func setHerdrNotificationsEnabled(_ enabled: Bool) async -> Bool {
        await self.invokeHerdrPluginAction(
            "herdr-focus-notify.\(enabled ? "enable" : "disable")"
        )
    }

    static func setNudgesEnabled(_ enabled: Bool) async -> Bool {
        await self.invokeHerdrPluginAction(
            "kalen.nudges.\(enabled ? "enable" : "disable")"
        )
    }

    static func switchToPreviousApplication() -> Bool {
        guard let commandDown = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(kVK_Command),
            keyDown: true
        ),
        let tabDown = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(kVK_Tab),
            keyDown: true
        ),
        let tabUp = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(kVK_Tab),
            keyDown: false
        ),
        let commandUp = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(kVK_Command),
            keyDown: false
        )
        else {
            return false
        }

        commandDown.flags = .maskCommand
        tabDown.flags = .maskCommand
        tabUp.flags = .maskCommand
        commandUp.flags = []
        commandDown.post(tap: .cghidEventTap)
        tabDown.post(tap: .cghidEventTap)
        tabUp.post(tap: .cghidEventTap)
        commandUp.post(tap: .cghidEventTap)
        return true
    }

    static func isNewCodexTabCommand(transcript: String) -> Bool {
        self.newCodexTabInvocation(transcript: transcript) != nil
    }

    static func newCodexTabPrompt(transcript: String) -> String? {
        self.newCodexTabInvocation(transcript: transcript)?.trailingText
    }

    static func isWritingWorkspaceCommand(transcript: String) -> Bool {
        if self.writingWorkspacePrompt(transcript: transcript) != nil
            || self.normalizedPhrase(transcript) == "start writing"
        {
            return true
        }
        switch self.normalizedPhrase(transcript) {
        case "right", "write":
            return true
        default:
            return false
        }
    }

    static func writingWorkspacePrompt(transcript: String) -> String? {
        let pattern = #"^start writing\b(.*)$"#
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let range = NSRange(transcript.startIndex..., in: transcript)
        guard let match = expression.firstMatch(in: transcript, range: range),
              match.range.location == 0,
              let trailingRange = Range(match.range(at: 1), in: transcript)
        else {
            return nil
        }

        let trailingText = String(transcript[trailingRange].drop(while: {
            $0.isWhitespace || $0.isPunctuation
        }))
        return trailingText.isEmpty ? nil : trailingText
    }

    static func tabDirectionCommand(transcript: String, bundleID: String) -> TabDirection? {
        guard self.herdrBundleIDs.contains(bundleID.lowercased()) else { return nil }
        switch self.normalizedPhrase(transcript) {
        case "tab left":
            return .left
        case "tab right":
            return .right
        default:
            return nil
        }
    }

    static func isCloseTabCommand(transcript: String, bundleID: String) -> Bool {
        self.herdrBundleIDs.contains(bundleID.lowercased())
            && self.normalizedPhrase(transcript) == "close tab"
    }

    static func isNextPendingCommand(transcript: String) -> Bool {
        self.normalizedPhrase(transcript) == "next"
    }

    static func isEDMFocusPlaylistCommand(transcript: String) -> Bool {
        self.normalizedPhrase(transcript) == "spotify edm"
    }

    @MainActor
    static func playEDMFocusPlaylist() async -> Bool {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        guard let applicationURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: self.spotifyBundleIDs[0]
        ) else {
            return false
        }

        do {
            _ = try await NSWorkspace.shared.openApplication(
                at: applicationURL,
                configuration: configuration
            )
        } catch {
            return false
        }

        try? await Task.sleep(for: .milliseconds(250))
        let script = """
        tell application "Spotify"
            play track "spotify:track:1HWy19J4EI51m1RR9iqzn5" in context "spotify:playlist:3YLw8MyzjwzAoZe73zXQK6"
            activate
        end tell
        """
        var error: NSDictionary?
        guard NSAppleScript(source: script)?.executeAndReturnError(&error) != nil else {
            return false
        }
        return error == nil
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
            let aliases = self.projectAliases[workspace.label.lowercased()] ?? []
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
              )
        else {
            return false
        }

        guard let invocation = self.resolveWorkspaceInvocation(
            query: query,
            workspaces: response.result.workspaces
        ) else {
            guard let repoURL = self.localRepoURL(query: query) else { return false }
            return await self.createHerdrWorkspace(
                executable: executable,
                repoURL: repoURL,
                label: repoURL.lastPathComponent.lowercased()
            )
        }

        let focusResult = await self.runProcess(
            executable,
            arguments: ["workspace", "focus", invocation.workspace.workspaceID]
        )
        guard focusResult.status == 0 else { return false }

        guard let applicationURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: self.herdrBundleIDs[0]
        ) else {
            return false
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false
        guard let herdrApplication = try? await NSWorkspace.shared.openApplication(
            at: applicationURL,
            configuration: configuration
        ) else {
            return false
        }

        guard let trailingText = invocation.trailingText else { return true }
        try? await Task.sleep(nanoseconds: 150_000_000)
        guard self.isTargetFrontmost(herdrApplication.processIdentifier) else { return false }
        return self.postText(trailingText, to: herdrApplication.processIdentifier)
    }

    @MainActor
    static func openNewCodexTab(prompt: String? = nil) async -> Bool {
        guard let executable = self.herdrExecutableURL() else { return false }
        // FluidVoice can inherit Herdr caller IDs when launched from a Herdr terminal.
        // Remove them so --current resolves the workspace currently visible in Herdr.
        let currentResult = await self.runProcess(
            executable,
            arguments: ["pane", "current", "--current"],
            removingEnvironmentVariables: self.herdrCallerEnvironmentVariables
        )
        guard currentResult.status == 0,
              let current = try? JSONDecoder().decode(
                  HerdrCurrentPaneResponse.self,
                  from: currentResult.output
              )
        else {
            return false
        }

        let pane = current.result.pane
        let createResult = await self.runProcess(
            executable,
            arguments: [
                "tab", "create",
                "--workspace", pane.workspaceID,
                "--cwd", pane.cwd,
                "--focus",
            ]
        )
        guard createResult.status == 0,
              let created = try? JSONDecoder().decode(
                  HerdrTabCreateResponse.self,
                  from: createResult.output
              )
        else {
            return false
        }

        let runResult = await self.runProcess(
            executable,
            arguments: ["pane", "run", created.result.rootPane.paneID, "codex"]
        )
        guard runResult.status == 0,
              let herdrApplication = NSRunningApplication.runningApplications(
                  withBundleIdentifier: self.herdrBundleIDs[0]
              ).first
        else {
            return false
        }
        guard herdrApplication.activate(
            options: [.activateAllWindows, .activateIgnoringOtherApps]
        ) else {
            return false
        }

        guard let prompt else { return true }
        for _ in 0..<60 {
            let paneListResult = await self.runProcess(
                executable,
                arguments: ["pane", "list", "--workspace", pane.workspaceID]
            )
            if paneListResult.status == 0,
               let paneResponse = try? JSONDecoder().decode(
                   HerdrPaneListResponse.self,
                   from: paneListResult.output
               ),
               let createdPane = paneResponse.result.panes.first(where: {
                   $0.paneID == created.result.rootPane.paneID
               }),
               createdPane.agent?.lowercased() == "codex",
               createdPane.agentStatus?.lowercased() == "idle"
            {
                try? await Task.sleep(for: .milliseconds(150))
                guard self.isTargetFrontmost(herdrApplication.processIdentifier) else {
                    return false
                }
                guard self.postText(prompt, to: herdrApplication.processIdentifier) else {
                    return false
                }
                try? await Task.sleep(for: .milliseconds(50))
                guard self.isTargetFrontmost(herdrApplication.processIdentifier) else {
                    return false
                }
                return self.postKey(
                    CGKeyCode(kVK_Return),
                    to: herdrApplication.processIdentifier
                )
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return false
    }

    @MainActor
    static func openAddSynonymCodexTab() async -> Bool {
        guard let executable = self.herdrExecutableURL() else { return false }
        let listResult = await self.runProcess(executable, arguments: ["workspace", "list"])
        guard listResult.status == 0,
              let response = try? JSONDecoder().decode(
                  HerdrWorkspaceListResponse.self,
                  from: listResult.output
              ),
              let workspace = response.result.workspaces.first(where: {
                  self.normalizedPhrase($0.label) == "fluidvoice"
              })
        else {
            return false
        }

        let focusResult = await self.runProcess(
            executable,
            arguments: ["workspace", "focus", workspace.workspaceID]
        )
        guard focusResult.status == 0 else { return false }

        let createResult = await self.runProcess(
            executable,
            arguments: [
                "tab", "create",
                "--workspace", workspace.workspaceID,
                "--cwd", "/Users/kalen/repos/FluidVoice",
                "--focus",
            ]
        )
        guard createResult.status == 0,
              let created = try? JSONDecoder().decode(
                  HerdrTabCreateResponse.self,
                  from: createResult.output
              )
        else {
            return false
        }

        let runResult = await self.runProcess(
            executable,
            arguments: ["pane", "run", created.result.rootPane.paneID, "codex"]
        )
        guard runResult.status == 0,
              let herdrApplication = NSRunningApplication.runningApplications(
                  withBundleIdentifier: self.herdrBundleIDs[0]
              ).first,
              herdrApplication.activate(
                  options: [.activateAllWindows, .activateIgnoringOtherApps]
              )
        else {
            return false
        }

        let prompt = "add synonym: "
        for _ in 0..<60 {
            let paneListResult = await self.runProcess(
                executable,
                arguments: ["pane", "list", "--workspace", workspace.workspaceID]
            )
            if paneListResult.status == 0,
               let paneResponse = try? JSONDecoder().decode(
                   HerdrPaneListResponse.self,
                   from: paneListResult.output
               ),
               let createdPane = paneResponse.result.panes.first(where: {
                   $0.paneID == created.result.rootPane.paneID
               }),
               createdPane.agent?.lowercased() == "codex",
               createdPane.agentStatus?.lowercased() == "idle"
            {
                try? await Task.sleep(for: .milliseconds(150))
                guard self.isTargetFrontmost(herdrApplication.processIdentifier),
                      self.postText(prompt, to: herdrApplication.processIdentifier)
                else {
                    return false
                }
                return self.isTargetFrontmost(herdrApplication.processIdentifier)
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return false
    }

    @MainActor
    static func openWritingWorkspace(prompt: String? = nil) async -> Bool {
        guard let executable = self.herdrExecutableURL() else { return false }
        let listResult = await self.runProcess(executable, arguments: ["workspace", "list"])
        guard listResult.status == 0,
              let response = try? JSONDecoder().decode(
                  HerdrWorkspaceListResponse.self,
                  from: listResult.output
              )
        else {
            return false
        }

        guard let workspace = response.result.workspaces.first(where: {
            self.normalizedPhrase($0.label) == "writing"
        }) else {
            let repoURL = URL(fileURLWithPath: "/Users/kalen/repos/writing", isDirectory: true)
            guard FileManager.default.fileExists(atPath: repoURL.path) else { return false }
            return await self.createHerdrWorkspace(
                executable: executable,
                repoURL: repoURL,
                label: "writing",
                prompt: prompt
            )
        }

        let paneListResult = await self.runProcess(
            executable,
            arguments: ["pane", "list", "--workspace", workspace.workspaceID]
        )
        guard paneListResult.status == 0,
              let paneResponse = try? JSONDecoder().decode(
                  HerdrPaneListResponse.self,
                  from: paneListResult.output
              )
        else {
            return false
        }

        let emptyCodexPane = paneResponse.result.panes.first {
            $0.agent?.lowercased() == "codex" && $0.agentStatus?.lowercased() == "idle"
        }
        if let emptyCodexPane {
            let focusWorkspaceResult = await self.runProcess(
                executable,
                arguments: ["workspace", "focus", workspace.workspaceID]
            )
            guard focusWorkspaceResult.status == 0 else { return false }
            let focusTabResult = await self.runProcess(
                executable,
                arguments: ["tab", "focus", emptyCodexPane.tabID]
            )
            guard focusTabResult.status == 0 else { return false }
            guard self.activateHerdr() else { return false }
            guard let prompt else { return true }
            try? await Task.sleep(for: .milliseconds(150))
            return await self.submitHerdrPrompt(prompt)
        }

        let createResult = await self.runProcess(
            executable,
            arguments: [
                "tab", "create",
                "--workspace", workspace.workspaceID,
                "--cwd", "/Users/kalen/repos/writing",
                "--focus",
            ]
        )
        guard createResult.status == 0,
              let created = try? JSONDecoder().decode(
                  HerdrTabCreateResponse.self,
                  from: createResult.output
              )
        else {
            return false
        }

        let runResult = await self.runProcess(
            executable,
            arguments: ["pane", "run", created.result.rootPane.paneID, "codex"]
        )
        guard runResult.status == 0, self.activateHerdr() else { return false }
        guard let prompt else { return true }

        for _ in 0..<60 {
            let updatedPaneListResult = await self.runProcess(
                executable,
                arguments: ["pane", "list", "--workspace", workspace.workspaceID]
            )
            if updatedPaneListResult.status == 0,
               let updatedPaneResponse = try? JSONDecoder().decode(
                   HerdrPaneListResponse.self,
                   from: updatedPaneListResult.output
               ),
               let createdPane = updatedPaneResponse.result.panes.first(where: {
                   $0.paneID == created.result.rootPane.paneID
               }),
               createdPane.agent?.lowercased() == "codex",
               createdPane.agentStatus?.lowercased() == "idle"
            {
                try? await Task.sleep(for: .milliseconds(150))
                return await self.submitHerdrPrompt(prompt)
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return false
    }

    private static func localRepoURL(query: String) -> URL? {
        let reposURL = URL(fileURLWithPath: "/Users/kalen/repos", isDirectory: true)
        guard let repoURLs = try? FileManager.default.contentsOfDirectory(
            at: reposURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let normalizedQuery = self.normalizedPhrase(query)
        return repoURLs.first { repoURL in
            guard (try? repoURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            else {
                return false
            }
            return self.normalizedPhrase(repoURL.lastPathComponent) == normalizedQuery
        }
    }

    @MainActor
    private static func createHerdrWorkspace(
        executable: URL,
        repoURL: URL,
        label: String,
        prompt: String? = nil
    ) async -> Bool {
        let createResult = await self.runProcess(
            executable,
            arguments: [
                "workspace", "create",
                "--cwd", repoURL.path,
                "--label", label,
                "--focus",
            ]
        )
        guard createResult.status == 0,
              let created = try? JSONDecoder().decode(
                  HerdrWorkspaceCreateResponse.self,
                  from: createResult.output
              )
        else {
            return false
        }

        let paneID = created.result.rootPane.paneID
        let workspaceID = created.result.workspace.workspaceID
        let runResult = await self.runProcess(
            executable,
            arguments: ["pane", "run", paneID, "codex"]
        )
        guard runResult.status == 0, self.activateHerdr() else { return false }
        guard let prompt else { return true }

        for _ in 0..<60 {
            let paneListResult = await self.runProcess(
                executable,
                arguments: ["pane", "list", "--workspace", workspaceID]
            )
            if paneListResult.status == 0,
               let paneResponse = try? JSONDecoder().decode(
                   HerdrPaneListResponse.self,
                   from: paneListResult.output
               ),
               let createdPane = paneResponse.result.panes.first(where: {
                   $0.paneID == paneID
               }),
               createdPane.agent?.lowercased() == "codex",
               createdPane.agentStatus?.lowercased() == "idle"
            {
                try? await Task.sleep(for: .milliseconds(150))
                return await self.submitHerdrPrompt(prompt)
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return false
    }

    @MainActor
    private static func submitHerdrPrompt(_ prompt: String) async -> Bool {
        guard let application = NSRunningApplication.runningApplications(
            withBundleIdentifier: self.herdrBundleIDs[0]
        ).first,
              self.isTargetFrontmost(application.processIdentifier),
              self.postText(prompt, to: application.processIdentifier)
        else {
            return false
        }
        try? await Task.sleep(for: .milliseconds(50))
        return self.isTargetFrontmost(application.processIdentifier)
            && self.postKey(CGKeyCode(kVK_Return), to: application.processIdentifier)
    }

    @MainActor
    static func submitInCurrentHerdrPane(_ text: String) async -> Bool {
        guard let executable = self.herdrExecutableURL() else { return false }
        let currentResult = await self.runProcess(
            executable,
            arguments: ["pane", "current", "--current"],
            removingEnvironmentVariables: self.herdrCallerEnvironmentVariables
        )
        guard currentResult.status == 0,
              let currentPane = try? JSONDecoder().decode(
                  HerdrCurrentPaneResponse.self,
                  from: currentResult.output
              ).result.pane
        else {
            return false
        }

        let result = await self.runProcess(
            executable,
            arguments: ["pane", "run", currentPane.paneID, text]
        )
        return result.status == 0
    }

    private static func activateHerdr() -> Bool {
        guard let application = NSRunningApplication.runningApplications(
            withBundleIdentifier: self.herdrBundleIDs[0]
        ).first else {
            return false
        }
        return application.activate(
            options: [.activateAllWindows, .activateIgnoringOtherApps]
        )
    }

    @MainActor
    static func moveHerdrTab(_ direction: TabDirection) async -> Bool {
        guard let executable = self.herdrExecutableURL() else { return false }
        let currentResult = await self.runProcess(
            executable,
            arguments: ["pane", "current", "--current"],
            removingEnvironmentVariables: self.herdrCallerEnvironmentVariables
        )
        guard currentResult.status == 0,
              let currentPane = try? JSONDecoder().decode(
                  HerdrCurrentPaneResponse.self,
                  from: currentResult.output
              ).result.pane
        else {
            return false
        }

        let listResult = await self.runProcess(
            executable,
            arguments: ["tab", "list", "--workspace", currentPane.workspaceID]
        )
        guard listResult.status == 0,
              let response = try? JSONDecoder().decode(
                  HerdrTabListResponse.self,
                  from: listResult.output
              ),
              response.result.tabs.count > 1
        else {
            return false
        }

        let tabs = response.result.tabs.sorted { $0.number < $1.number }
        guard let currentIndex = tabs.firstIndex(where: { $0.tabID == currentPane.tabID }) else {
            return false
        }
        let offset: Int
        switch direction {
        case .left:
            offset = tabs.count - 1
        case .right:
            offset = 1
        }
        let target = tabs[(currentIndex + offset) % tabs.count]
        let focusResult = await self.runProcess(
            executable,
            arguments: ["tab", "focus", target.tabID]
        )
        return focusResult.status == 0
    }

    @MainActor
    static func closeCurrentHerdrTab() async -> Bool {
        guard let executable = self.herdrExecutableURL() else { return false }
        let currentResult = await self.runProcess(
            executable,
            arguments: ["pane", "current", "--current"],
            removingEnvironmentVariables: self.herdrCallerEnvironmentVariables
        )
        guard currentResult.status == 0,
              let currentPane = try? JSONDecoder().decode(
                  HerdrCurrentPaneResponse.self,
                  from: currentResult.output
              ).result.pane
        else {
            return false
        }

        let closeResult = await self.runProcess(
            executable,
            arguments: ["tab", "close", currentPane.tabID]
        )
        return closeResult.status == 0
    }

    @MainActor
    static func openNextPendingHerdrTab() async -> Bool {
        guard let herdrApplication = NSRunningApplication.runningApplications(
            withBundleIdentifier: self.herdrBundleIDs[0]
        ).first,
              herdrApplication.activate(
                  options: [.activateAllWindows, .activateIgnoringOtherApps]
              )
        else {
            return false
        }

        try? await Task.sleep(for: .milliseconds(150))
        let processIdentifier = herdrApplication.processIdentifier
        guard self.isTargetFrontmost(processIdentifier),
              self.postKey(
                  CGKeyCode(kVK_ANSI_D),
                  flags: .maskCommand,
                  to: processIdentifier
              )
        else {
            return false
        }

        try? await Task.sleep(for: .milliseconds(100))
        return self.postKey(CGKeyCode(kVK_Return), to: processIdentifier)
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
    static func openOrFocusURLInChrome(_ url: URL) -> Bool {
        let baseURL = url.absoluteString
        let script = """
        tell application "Google Chrome"
            launch
            repeat with windowIndex from 1 to count of windows
                    set chromeWindow to window windowIndex
                    repeat with tabIndex from 1 to count of tabs of chromeWindow
                        set tabURL to URL of tab tabIndex of chromeWindow
                    if tabURL is "\(baseURL)" ¬
                        or tabURL is "\(baseURL)/" ¬
                        or tabURL starts with "\(baseURL)?" ¬
                        or tabURL starts with "\(baseURL)#" ¬
                        or tabURL starts with "\(baseURL)/?" ¬
                        or tabURL starts with "\(baseURL)/#" then
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

    static func deleteDesktopContents(
        fileManager: FileManager = .default
    ) -> DesktopDeletionResult? {
        guard let desktopURL = fileManager.urls(
            for: .desktopDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }

        let items: [URL]
        do {
            items = try fileManager.contentsOfDirectory(
                at: desktopURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            return nil
        }

        var deletedCount = 0
        var failedCount = 0
        for item in items {
            do {
                guard try item.resourceValues(
                    forKeys: [.isRegularFileKey]
                ).isRegularFile == true else {
                    continue
                }
                _ = try fileManager.trashItem(at: item, resultingItemURL: nil)
                deletedCount += 1
            } catch {
                failedCount += 1
            }
        }
        return DesktopDeletionResult(
            deletedCount: deletedCount,
            failedCount: failedCount
        )
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

    private static func herdrCommandArgument(
        _ transcript: String,
        preserveTerminalPunctuation: Bool = false
    ) -> String? {
        for command in self.herdrCommandAliases {
            if let argument = self.commandArgument(
                transcript,
                command: command,
                preserveTerminalPunctuation: preserveTerminalPunctuation
            ) {
                return argument
            }
        }
        return nil
    }

    private static func normalizedPhrase(_ text: String) -> String {
        let words = text.lowercased().split {
            $0.isWhitespace || $0.isPunctuation
        }
        return words.joined(separator: " ")
    }

    private static func newCodexTabInvocation(
        transcript: String
    ) -> NewCodexTabInvocation? {
        let pattern = #"^(new codex tab|codex new tab|new tab)\b(.*)$"#
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let range = NSRange(transcript.startIndex..., in: transcript)
        guard let match = expression.firstMatch(in: transcript, range: range),
              match.range.location == 0,
              let trailingRange = Range(match.range(at: 2), in: transcript)
        else {
            return nil
        }

        let trailingText = String(transcript[trailingRange].drop(while: {
            $0.isWhitespace || $0.isPunctuation
        }))
        return NewCodexTabInvocation(
            trailingText: trailingText.isEmpty ? nil : trailingText
        )
    }

    private static func canonicalProjectName(for spokenName: String) -> String? {
        let normalizedName = self.normalizedPhrase(spokenName)
        return self.projectAliases.first { projectName, aliases in
            self.normalizedPhrase(projectName) == normalizedName
                || aliases.contains { self.normalizedPhrase($0) == normalizedName }
        }?.key
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
        standardInputCloseDelay: TimeInterval = 0,
        removingEnvironmentVariables: Set<String> = []
    ) async -> (status: Int32, output: Data) {
        await Task.detached {
            let process = Process()
            let outputPipe = Pipe()
            let inputPipe = Pipe()
            process.executableURL = executable
            process.arguments = arguments
            if !removingEnvironmentVariables.isEmpty {
                var environment = ProcessInfo.processInfo.environment
                for variable in removingEnvironmentVariables {
                    environment.removeValue(forKey: variable)
                }
                process.environment = environment
            }
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

    private static func invokeHerdrPluginAction(_ actionID: String) async -> Bool {
        guard let executable = self.herdrExecutableURL() else { return false }
        let result = await self.runProcess(
            executable,
            arguments: ["plugin", "action", "invoke", actionID],
            removingEnvironmentVariables: self.herdrCallerEnvironmentVariables
        )
        return result.status == 0
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
