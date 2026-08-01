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

    private struct HerdrWorkspaceQueryCandidate {
        let query: String
        let trailingWorkspace: String?
    }

    private struct NewCodexTabInvocation {
        let trailingText: String?
    }

    struct DesktopDeletionResult: Equatable {
        let deletedCount: Int
        let failedCount: Int
    }

    struct WindowOperationResult: Equatable {
        let succeededCount: Int
        let failedCount: Int
    }

    enum TabDirection {
        case left
        case right
    }

    enum CodexReasoningLevel: String, Equatable {
        case low
        case medium
        case high
    }

    enum CodexReasoningSetResult: Equatable {
        case set
        case busy
        case failed
    }

    enum AirPodsDevice: Equatable {
        case pro
        case max
    }

    enum AirPodsCommand: Equatable {
        case connect(AirPodsDevice)
        case disconnect(AirPodsDevice)
    }

    struct AirPodsBatteryStatus: Equatable {
        let leftPercent: Int?
        let rightPercent: Int?
        let casePercent: Int?

        var summary: String {
            let levels = [
                self.leftPercent.map { "Left \($0)%" },
                self.rightPercent.map { "Right \($0)%" },
                self.casePercent.map { "Case \($0)%" },
            ].compactMap { $0 }
            return "AirPods battery\n" + levels.joined(separator: " · ")
        }
    }

    struct CodexWeeklyStatus: Equatable {
        let usedPercent: Double
        let windowDurationMinutes: Double
        let resetsAt: Date

        var usageFraction: Double {
            min(max(self.usedPercent / 100, 0), 1)
        }

        func pacing(now: Date = Date()) -> (allowedUsageFraction: Double, elapsedDays: Int, windowDays: Int) {
            let windowStart = self.resetsAt.addingTimeInterval(-self.windowDurationMinutes * 60)
            let windowDays = max(1, Int(ceil(self.windowDurationMinutes / (24 * 60))))
            let elapsedDays = max(
                1,
                min(windowDays, Int(ceil(now.timeIntervalSince(windowStart) / (24 * 60 * 60))))
            )
            return (Double(elapsedDays) / Double(windowDays), elapsedDays, windowDays)
        }

        func summary(now: Date = Date()) -> String {
            let pacing = self.pacing(now: now)
            let pace = self.usageFraction <= pacing.allowedUsageFraction ? "On pace" : "Behind pace"
            let remainingPercent = max(0, 100 - self.usedPercent)

            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "EEE 'at' h:mm a"
            return "Codex weekly: \(Int(remainingPercent.rounded()))% remaining\n"
                + "\(pace) · day \(pacing.elapsedDays) of \(pacing.windowDays)\n"
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

    private struct HerdrPaneProcessInfoResponse: Decodable {
        struct Result: Decodable {
            let processInfo: ProcessInfo

            enum CodingKeys: String, CodingKey {
                case processInfo = "process_info"
            }
        }

        struct ProcessInfo: Decodable {
            let foregroundProcesses: [ForegroundProcess]

            enum CodingKeys: String, CodingKey {
                case foregroundProcesses = "foreground_processes"
            }
        }

        struct ForegroundProcess: Decodable {
            let name: String
            let pid: Int
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
            struct AgentSession: Decodable {
                let value: String
            }

            let agent: String?
            let agentSession: AgentSession?
            let agentStatus: String?
            let cwd: String?
            let paneID: String
            let tabID: String

            enum CodingKeys: String, CodingKey {
                case agent
                case agentSession = "agent_session"
                case agentStatus = "agent_status"
                case cwd
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
    private struct SynonymCatalog {
        let herdrCommands: [String]
        let herdrNames: Set<String>
        let exactHerdrWorkspaces: [String: String]
        let bareHerdrWorkspaces: [String: String]
        let projects: [String: [String]]
        let applications: [String: String]
        let speechRecognitionWords: [String: Set<String>]
        let outboundRoutes: [(phrases: Set<String>, url: String)]
    }

    /// Canonical source for voice-command synonyms. Add observed recognition variants here.
    private static let synonyms = SynonymCatalog(
        herdrCommands: ["edit"],
        herdrNames: ["herdr", "herder", "hurt her"],
        exactHerdrWorkspaces: [
            "router": "router",
        ],
        bareHerdrWorkspaces: [
            "fluid voice": "fluidvoice",
            "fluidvoice": "fluidvoice",
            "nudges": "nudges",
            "skills": "skills",
        ],
        projects: [
            "comms": ["coms", "comms workspace"],
            "fluidvoice": ["fluid voice", "fluid boys"],
            "commerce-land": ["commerce land"],
            "commerce-leak": ["commerce leak"],
            "hvac": ["h fact"],
            "ordellan": ["or dell and", "or dell in", "or dallin", "or dall in", "or delin"],
        ],
        applications: ["chatgpt": "chatgptclassic"],
        speechRecognitionWords: ["codex": ["codec", "codecs"]],
        outboundRoutes: [
            (["outbound dash", "outbound ash"], "http://outbound-dash.localhost:8764"),
            (["signalflame site", "signal flame site"], "http://signalflame.localhost:8780"),
            (["hvac site"], "http://hvac.localhost:8782"),
            (["commerce leak site"], "http://commerceleak.localhost:8781"),
            (["ordellan site"], "http://ordellan.localhost:8783"),
            (["commerce land site", "commerceland site"], "http://commerce-land.localhost:8784"),
            (["matchbook site"], "http://matchbook.localhost:8786"),
            (["outbound farm site"], "http://outbound.farm.localhost:8787"),
            (
                ["signalflame dash", "signal flame dash"],
                "http://outbound-dash.localhost:8764/clients/signalflame"
            ),
            (
                ["matchbook dash", "matt s book dash"],
                "http://outbound-dash.localhost:8764/clients/matchbook"
            ),
            (
                [
                    "commerce land dash", "commerce landash", "commerce land ash",
                    "commerce land act", "commerceland dash", "carmer s landash",
                    "carmerce land dash",
                ],
                "http://outbound-dash.localhost:8764/clients/commerce-land"
            ),
            (
                ["commerce leak dash", "commerce leaked ash"],
                "http://outbound-dash.localhost:8764/clients/commerce-leak"
            ),
            (
                ["linkedin crm", "linkedin dash", "linkedin crm dash"],
                "http://outbound-dash.localhost:8764/clients/linkedin-crm"
            ),
            (
                ["st3 dash", "s t three dash"],
                "http://outbound-dash.localhost:8764/clients/st3aero?view=targets"
            ),
            (
                ["layers dash"],
                "http://outbound-dash.localhost:8764/clients/layers?card=cannot_outreach"
            ),
            (["outbound farm dash"], "http://outbound-dash.localhost:8764/clients/outbound-farm"),
            (["hvac dash"], "http://outbound-dash.localhost:8764/clients/hvac?card=opportunity_identified"),
        ]
    )
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

    static let shellBackedCodexLaunchCommand = "zsh -il -c 'codex; exec zsh -il'"

    enum RestartCodexResult: Equatable {
        case restarted
        case noThreadToResume
        case failed
    }

    static func herdrWorkspaceQuery(transcript: String, bundleID: String = "") -> String? {
        self.herdrWorkspaceQueryCandidate(transcript: transcript, bundleID: bundleID)?.query
    }

    static func validatedHerdrWorkspaceQuery(
        transcript: String,
        bundleID: String = ""
    ) async -> String? {
        guard let candidate = self.herdrWorkspaceQueryCandidate(
            transcript: transcript,
            bundleID: bundleID
        ) else {
            return nil
        }
        guard let trailingWorkspace = candidate.trailingWorkspace else {
            return candidate.query
        }
        guard let executable = self.herdrExecutableURL() else { return nil }
        let listResult = await self.runProcess(executable, arguments: ["workspace", "list"])
        guard listResult.status == 0,
              let response = try? JSONDecoder().decode(
                  HerdrWorkspaceListResponse.self,
                  from: listResult.output
              ),
              self.resolveWorkspace(
                  query: trailingWorkspace,
                  workspaces: response.result.workspaces
              ) != nil
        else {
            return nil
        }
        return candidate.query
    }

    private static func herdrWorkspaceQueryCandidate(
        transcript: String,
        bundleID: String
    ) -> HerdrWorkspaceQueryCandidate? {
        let normalizedTranscript = self.normalizedPhrase(transcript)
        if let query = self.synonyms.exactHerdrWorkspaces[normalizedTranscript] {
            return HerdrWorkspaceQueryCandidate(query: query, trailingWorkspace: nil)
        }
        if let query = self.synonyms.bareHerdrWorkspaces[normalizedTranscript] {
            return HerdrWorkspaceQueryCandidate(query: query, trailingWorkspace: nil)
        }

        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let editCommandsPattern = self.regexAlternation(self.synonyms.herdrCommands)
        if let expression = try? NSRegularExpression(
            pattern: #"^(.+)\s+(?:"# + editCommandsPattern + #")\s+(.+)$"#,
            options: [.caseInsensitive]
        ) {
            let range = NSRange(trimmedTranscript.startIndex..., in: trimmedTranscript)
            if let match = expression.firstMatch(in: trimmedTranscript, range: range),
               let promptRange = Range(match.range(at: 1), in: trimmedTranscript),
               let workspaceRange = Range(match.range(at: 2), in: trimmedTranscript)
            {
                let prompt = trimmedTranscript[promptRange]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ",:;-"))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let workspace = trimmedTranscript[workspaceRange]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !prompt.isEmpty, !workspace.isEmpty {
                    return HerdrWorkspaceQueryCandidate(
                        query: workspace + ", " + prompt,
                        trailingWorkspace: workspace
                    )
                }
            }
        }

        let herdrNamesPattern = self.regexAlternation(Array(self.synonyms.herdrNames))
        if let expression = try? NSRegularExpression(
            pattern: #"^(?:"# + herdrNamesPattern + #")\b(.*)$"#,
            options: [.caseInsensitive]
        ) {
            let range = NSRange(trimmedTranscript.startIndex..., in: trimmedTranscript)
            if let match = expression.firstMatch(in: trimmedTranscript, range: range),
               let trailingRange = Range(match.range(at: 1), in: trimmedTranscript)
            {
                let trailingText = trimmedTranscript[trailingRange]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ",:;-"))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !self.normalizedPhrase(trailingText).isEmpty else {
                    return HerdrWorkspaceQueryCandidate(query: "herdr", trailingWorkspace: nil)
                }
                return HerdrWorkspaceQueryCandidate(
                    query: "herdr " + trailingText,
                    trailingWorkspace: nil
                )
            }
        }

        for (alias, workspace) in self.synonyms.bareHerdrWorkspaces.sorted(by: {
            $0.key.count > $1.key.count
        }) {
            let pattern = #"^"# + NSRegularExpression.escapedPattern(for: alias) + #"\b(.*)$"#
            guard let expression = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            ) else {
                continue
            }
            let range = NSRange(trimmedTranscript.startIndex..., in: trimmedTranscript)
            guard let match = expression.firstMatch(in: trimmedTranscript, range: range),
                  let trailingRange = Range(match.range(at: 1), in: trimmedTranscript)
            else {
                continue
            }
            let trailingText = trimmedTranscript[trailingRange]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: ",:;-"))
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trailingText.isEmpty else {
                return HerdrWorkspaceQueryCandidate(query: workspace, trailingWorkspace: nil)
            }
            return HerdrWorkspaceQueryCandidate(
                query: workspace + " " + trailingText,
                trailingWorkspace: nil
            )
        }

        let globalQuery = self.herdrCommandArgument(
            transcript,
            preserveTerminalPunctuation: true
        )
        if let globalQuery {
            return HerdrWorkspaceQueryCandidate(query: globalQuery, trailingWorkspace: nil)
        }

        guard self.herdrBundleIDs.contains(bundleID.lowercased()) else { return nil }
        if let query = self.commandArgument(
            transcript,
            command: "her",
            preserveTerminalPunctuation: true
        ) {
            return HerdrWorkspaceQueryCandidate(query: query, trailingWorkspace: nil)
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
        if let route = self.synonyms.outboundRoutes.first(where: { $0.phrases.contains(phrase) }) {
            return URL(string: route.url)
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

    static func isCopyLastResultCommand(transcript: String) -> Bool {
        let phrase = self.normalizedPhrase(transcript)
        return phrase == "copy last result" || phrase == "copy last action"
    }

    static func isEnterCommand(transcript: String) -> Bool {
        self.normalizedPhrase(transcript) == "enter"
    }

    static func pressEnter(targetPID: pid_t) -> Bool {
        self.postKey(CGKeyCode(kVK_Return), to: targetPID)
    }

    static func isCodexClearLineCommand(transcript: String, bundleID: String) -> Bool {
        guard self.codexBundleIDs.contains(bundleID.lowercased()) else { return false }
        let phrase = self.normalizedPhrase(transcript)
        return phrase == "clear line" || phrase == "slash clear line"
    }

    static func isCodexStatusCommand(transcript: String) -> Bool {
        self.normalizedCommandPhrase(transcript) == "codex status"
    }

    static func isRestartCodexCommand(transcript: String, bundleID: String) -> Bool {
        guard self.herdrBundleIDs.contains(bundleID.lowercased()) else { return false }
        let phrase = self.normalizedCommandPhrase(transcript)
        return phrase == "restart codex" || phrase == "codex restart"
    }

    static func codexReasoningLevelCommand(
        transcript: String,
        bundleID: String
    ) -> CodexReasoningLevel? {
        guard self.herdrBundleIDs.contains(bundleID.lowercased()) else { return nil }
        switch self.normalizedCommandPhrase(transcript) {
        case "codex low", "codex reasoning low", "set codex reasoning low":
            return .low
        case "codex medium", "codex reasoning medium", "set codex reasoning medium":
            return .medium
        case "codex high", "codex reasoning high", "set codex reasoning high":
            return .high
        default:
            return nil
        }
    }

    static func isAddSynonymCommand(transcript: String) -> Bool {
        self.normalizedPhrase(transcript) == "add synonym"
    }

    static func isRestartFluidVoiceCommand(transcript: String) -> Bool {
        self.normalizedPhrase(transcript) == "restart fluid voice"
    }

    static func isPlayCommand(transcript: String) -> Bool {
        self.normalizedPhrase(transcript) == "play"
    }

    static func isAirPodsBatteryCommand(transcript: String) -> Bool {
        switch self.normalizedPhrase(transcript) {
        case "airpods battery", "air pods battery", "check airpods battery", "check air pods battery":
            return true
        default:
            return false
        }
    }

    static func airPodsCommand(transcript: String) -> AirPodsCommand? {
        switch self.normalizedPhrase(transcript) {
        case "connect airpods", "connect air pods":
            return .connect(.pro)
        case "disconnect airpods", "disconnect air pods":
            return .disconnect(.pro)
        case "connect airpods max", "connect air pods max":
            return .connect(.max)
        case "disconnect airpods max", "disconnect air pods max":
            return .disconnect(.max)
        default:
            return nil
        }
    }

    static func runAirPodsCommand(_ command: AirPodsCommand) async -> Bool {
        let device: AirPodsDevice
        switch command {
        case let .connect(selectedDevice), let .disconnect(selectedDevice):
            device = selectedDevice
        }
        let address: String
        let airPodsName: String
        switch device {
        case .pro:
            address = "30:0E:43:33:94:9B"
            airPodsName = "Kalen’s AirPods Pro"
        case .max:
            address = "70:F9:4A:9D:98:BC"
            airPodsName = "Kalen’s AirPods Max"
        }
        let speakersName = "MacBook Air Speakers"
        guard let blueutil = self.executableURL(named: "blueutil"),
              let switchAudioSource = self.executableURL(named: "SwitchAudioSource")
        else {
            return false
        }

        switch command {
        case .disconnect:
            let switchResult = await self.runProcess(
                switchAudioSource,
                arguments: ["-s", speakersName, "-t", "output"]
            )
            guard switchResult.status == 0 else { return false }
            for _ in 0..<3 {
                _ = await self.runProcess(blueutil, arguments: ["--disconnect", address])
                let connectedResult = await self.runProcess(
                    blueutil,
                    arguments: ["--is-connected", address]
                )
                let isConnected = String(decoding: connectedResult.output, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if connectedResult.status == 0, isConnected == "0" {
                    return true
                }
                try? await Task.sleep(for: .milliseconds(500))
            }
            return false

        case .connect:
            _ = await self.runProcess(
                blueutil,
                arguments: ["--connect", address]
            )

            for attempt in 0..<10 {
                let availableResult = await self.runProcess(
                    switchAudioSource,
                    arguments: ["-a", "-t", "output"]
                )
                let availableOutputs = String(decoding: availableResult.output, as: UTF8.self)
                if availableResult.status == 0,
                   availableOutputs.split(separator: "\n").contains(Substring(airPodsName))
                {
                    let switchResult = await self.runProcess(
                        switchAudioSource,
                        arguments: ["-s", airPodsName, "-t", "output"]
                    )
                    return switchResult.status == 0
                }

                if attempt == 1 {
                    _ = await self.runProcess(blueutil, arguments: ["--disconnect", address])
                    try? await Task.sleep(for: .milliseconds(500))
                    _ = await self.runProcess(
                        blueutil,
                        arguments: ["--connect", address]
                    )
                } else if attempt > 1 {
                    _ = await self.runProcess(
                        blueutil,
                        arguments: ["--connect", address]
                    )
                }
                try? await Task.sleep(for: .seconds(1))
            }
            return false
        }
    }

    static func readAirPodsBatteryStatus() async -> AirPodsBatteryStatus? {
        let systemProfiler = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        let result = await self.runProcess(
            systemProfiler,
            arguments: ["SPBluetoothDataType", "-json"]
        )
        guard result.status == 0 else { return nil }
        return self.parseAirPodsBatteryStatus(from: result.output)
    }

    static func parseAirPodsBatteryStatus(from data: Data) -> AirPodsBatteryStatus? {
        guard let root = try? JSONSerialization.jsonObject(with: data) else { return nil }
        var candidates: [(name: String, properties: [String: Any])] = []

        func collectDevices(from value: Any) {
            if let dictionary = value as? [String: Any] {
                for (name, child) in dictionary {
                    if let properties = child as? [String: Any],
                       name.localizedCaseInsensitiveContains("airpods"),
                       !name.localizedCaseInsensitiveContains("max")
                    {
                        candidates.append((name, properties))
                    }
                    collectDevices(from: child)
                }
            } else if let array = value as? [Any] {
                array.forEach { collectDevices(from: $0) }
            }
        }

        collectDevices(from: root)
        guard let properties = candidates.first(where: {
            $0.properties["device_address"] as? String == "30:0E:43:33:94:9B"
        })?.properties ?? candidates.first?.properties else {
            return nil
        }

        func percentage(_ key: String) -> Int? {
            guard let value = properties[key] as? String else { return nil }
            return Int(value.trimmingCharacters(in: CharacterSet(charactersIn: "%")))
        }

        let status = AirPodsBatteryStatus(
            leftPercent: percentage("device_batteryLevelLeft"),
            rightPercent: percentage("device_batteryLevelRight"),
            casePercent: percentage("device_batteryLevelCase")
        )
        guard status.leftPercent != nil || status.rightPercent != nil || status.casePercent != nil else {
            return nil
        }
        return status
    }

    static func isSwitchCommand(transcript: String) -> Bool {
        self.normalizedPhrase(transcript) == "switch"
    }

    static func textBeforeTrailingPasteCommand(transcript: String) -> String? {
        guard let expression = try? NSRegularExpression(
            pattern: #"\bpaste[\s\p{P}]*$"#,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let range = NSRange(transcript.startIndex..., in: transcript)
        guard let match = expression.firstMatch(in: transcript, range: range),
              let matchRange = Range(match.range, in: transcript)
        else {
            return nil
        }

        return String(transcript[..<matchRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

    static func isWindowMiddleAllCommand(transcript: String) -> Bool {
        self.normalizedPhrase(transcript) == "window middle all"
    }

    private static let windowMiddlePreferredSize = NSSize(width: 1294, height: 901)
    private static let windowMiddleTopLeftInset = NSPoint(x: 396, y: 103)
    private static let windowMiddleReferenceScreenSize = NSSize(width: 1920, height: 1080)

    static func moveWindowToMiddle(targetPID: pid_t) -> Bool {
        guard let screen = OverlayScreenResolver.screenForCurrentPointer(),
              let primaryScreen = NSScreen.screens.first
        else {
            return false
        }

        return self.moveFocusedWindow(
            operation: "middle",
            targetPID: targetPID,
            to: self.windowMiddleFrame(
                in: screen.visibleFrame,
                screenFrame: screen.frame
            ),
            screen: screen,
            primaryScreenMaxY: primaryScreen.frame.maxY
        )
    }

    static func moveAllApplicationWindowsToMiddle() -> WindowOperationResult {
        guard let screen = OverlayScreenResolver.screenForCurrentPointer(),
              let primaryScreen = NSScreen.screens.first
        else {
            return WindowOperationResult(succeededCount: 0, failedCount: 0)
        }

        let frame = self.windowMiddleFrame(
            in: screen.visibleFrame,
            screenFrame: screen.frame
        )
        let applications = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isTerminated
        }
        var succeededCount = 0
        var failedCount = 0
        for application in applications {
            if self.moveFocusedWindow(
                operation: "middle-all",
                targetPID: application.processIdentifier,
                to: frame,
                screen: screen,
                primaryScreenMaxY: primaryScreen.frame.maxY,
                allowMainWindowFallback: true
            ) {
                succeededCount += 1
            } else {
                failedCount += 1
            }
        }
        return WindowOperationResult(
            succeededCount: succeededCount,
            failedCount: failedCount
        )
    }

    static func windowMiddleFrame(
        in visibleFrame: NSRect,
        screenFrame: NSRect? = nil
    ) -> NSRect {
        let scalingFrame = screenFrame ?? visibleFrame
        let scale = min(
            scalingFrame.width / self.windowMiddleReferenceScreenSize.width,
            scalingFrame.height / self.windowMiddleReferenceScreenSize.height
        )
        return self.windowFrame(
            in: visibleFrame,
            preferredSize: NSSize(
                width: self.windowMiddlePreferredSize.width * scale,
                height: self.windowMiddlePreferredSize.height * scale
            ),
            topLeftInset: NSPoint(
                x: self.windowMiddleTopLeftInset.x * scale,
                y: self.windowMiddleTopLeftInset.y * scale
            )
        )
    }

    static func isWindowMaxCommand(transcript: String) -> Bool {
        self.normalizedPhrase(transcript) == "window max"
    }

    static func maximizeWindow(targetPID: pid_t) -> Bool {
        guard let screen = OverlayScreenResolver.screenForCurrentPointer(),
              let primaryScreen = NSScreen.screens.first
        else {
            return false
        }
        return self.moveFocusedWindow(
            operation: "max",
            targetPID: targetPID,
            to: self.windowMaxFrame(on: screen, primaryScreen: primaryScreen),
            screen: screen,
            primaryScreenMaxY: primaryScreen.frame.maxY
        )
    }

    static func windowMaxFrame(on screen: NSScreen, primaryScreen: NSScreen) -> NSRect {
        self.windowMaxFrame(
            screenFrame: screen.frame,
            primaryVisibleFrame: primaryScreen.visibleFrame
        )
    }

    static func windowMaxFrame(
        screenFrame: NSRect,
        primaryVisibleFrame: NSRect
    ) -> NSRect {
        let sharedMenuBarBottom = primaryVisibleFrame.maxY
        let top = min(screenFrame.maxY, sharedMenuBarBottom)
        return NSRect(
            x: screenFrame.minX,
            y: screenFrame.minY,
            width: screenFrame.width,
            height: top - screenFrame.minY
        )
    }

    static func isWindowTopLeftCommand(transcript: String) -> Bool {
        self.normalizedPhrase(transcript) == "window top left"
    }

    static func moveWindowToTopLeft(targetPID: pid_t) -> Bool {
        guard let screen = OverlayScreenResolver.screenForCurrentPointer(),
              let primaryScreen = NSScreen.screens.first
        else {
            return false
        }
        return self.moveFocusedWindow(
            operation: "top-left",
            targetPID: targetPID,
            to: self.windowTopLeftFrame(in: screen.visibleFrame),
            screen: screen,
            primaryScreenMaxY: primaryScreen.frame.maxY
        )
    }

    static func windowTopLeftFrame(in visibleFrame: NSRect) -> NSRect {
        self.windowFrame(
            in: visibleFrame,
            preferredSize: NSSize(width: 500, height: 375),
            topLeftInset: NSPoint(x: 0, y: 0)
        )
    }

    private static func windowFrame(
        in visibleFrame: NSRect,
        preferredSize: NSSize,
        topLeftInset: NSPoint
    ) -> NSRect {
        let size = NSSize(
            width: min(preferredSize.width, visibleFrame.width),
            height: min(preferredSize.height, visibleFrame.height)
        )
        let leftInset = min(topLeftInset.x, visibleFrame.width - size.width)
        let topInset = min(topLeftInset.y, visibleFrame.height - size.height)
        return NSRect(
            x: visibleFrame.minX + leftInset,
            y: visibleFrame.maxY - topInset - size.height,
            width: size.width,
            height: size.height
        )
    }

    private static func moveFocusedWindow(
        operation: String,
        targetPID: pid_t,
        to frame: NSRect,
        screen: NSScreen,
        primaryScreenMaxY: CGFloat,
        allowMainWindowFallback: Bool = false
    ) -> Bool {
        let logSource = "WindowResize"
        DebugLogger.shared.info(
            "Resize requested: operation=\(operation) targetPID=\(targetPID) " +
                "screen=\(screen.localizedName) screenFrame=\(NSStringFromRect(screen.frame)) " +
                "visibleFrame=\(NSStringFromRect(screen.visibleFrame)) " +
                "requestedAppKitFrame=\(NSStringFromRect(frame)) " +
                "primaryScreenMaxY=\(primaryScreenMaxY)",
            source: logSource
        )
        let application = AXUIElementCreateApplication(targetPID)
        var focusedWindowValue: CFTypeRef?
        var windowResult = AXUIElementCopyAttributeValue(
            application,
            kAXFocusedWindowAttribute as CFString,
            &focusedWindowValue
        )
        if allowMainWindowFallback,
           (windowResult != .success || focusedWindowValue == nil)
        {
            windowResult = AXUIElementCopyAttributeValue(
                application,
                kAXMainWindowAttribute as CFString,
                &focusedWindowValue
            )
        }
        guard windowResult == .success,
            let focusedWindowValue,
            CFGetTypeID(focusedWindowValue) == AXUIElementGetTypeID()
        else {
            DebugLogger.shared.error(
                "Resize failed: operation=\(operation) targetPID=\(targetPID) " +
                    "windowResult=\(windowResult.rawValue) " +
                    "hasValue=\(focusedWindowValue != nil)",
                source: logSource
            )
            return false
        }

        let window = unsafeBitCast(focusedWindowValue, to: AXUIElement.self)
        let beforePosition = self.windowAXPoint(window, attribute: kAXPositionAttribute)
        let beforeSize = self.windowAXSize(window, attribute: kAXSizeAttribute)
        var size = frame.size
        var position = CGPoint(x: frame.minX, y: primaryScreenMaxY - frame.maxY)
        var intermediateSize = CGSize(
            width: min(beforeSize?.width ?? size.width, size.width),
            height: min(beforeSize?.height ?? size.height, size.height)
        )
        DebugLogger.shared.info(
            "Resize applying: operation=\(operation) targetPID=\(targetPID) " +
                "beforePosition=\(String(describing: beforePosition)) " +
                "beforeSize=\(String(describing: beforeSize)) " +
                "intermediateAXSize=\(intermediateSize) " +
                "requestedAXPosition=\(position) requestedAXSize=\(size)",
            source: logSource
        )
        guard let sizeValue = AXValueCreate(.cgSize, &size),
              let intermediateSizeValue = AXValueCreate(.cgSize, &intermediateSize),
              let positionValue = AXValueCreate(.cgPoint, &position)
        else {
            DebugLogger.shared.error(
                "Resize failed creating AX values: operation=\(operation) targetPID=\(targetPID)",
                source: logSource
            )
            return false
        }

        let intermediateSizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            intermediateSizeValue
        )
        let positionResult = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            positionValue
        )
        let sizeResult = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            sizeValue
        )
        let afterPosition = self.windowAXPoint(window, attribute: kAXPositionAttribute)
        let afterSize = self.windowAXSize(window, attribute: kAXSizeAttribute)
        let succeeded = intermediateSizeResult == .success &&
            sizeResult == .success && positionResult == .success
        DebugLogger.shared.info(
            "Resize finished: operation=\(operation) targetPID=\(targetPID) " +
                "success=\(succeeded) intermediateSizeResult=\(intermediateSizeResult.rawValue) " +
                "sizeResult=\(sizeResult.rawValue) " +
                "positionResult=\(positionResult.rawValue) " +
                "afterPosition=\(String(describing: afterPosition)) " +
                "afterSize=\(String(describing: afterSize))",
            source: logSource
        )
        return succeeded
    }

    private static func windowAXPoint(
        _ window: AXUIElement,
        attribute: String
    ) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }
        var point = CGPoint.zero
        guard AXValueGetValue(unsafeBitCast(value, to: AXValue.self), .cgPoint, &point) else {
            return nil
        }
        return point
    }

    private static func windowAXSize(
        _ window: AXUIElement,
        attribute: String
    ) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, attribute as CFString, &value) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }
        var size = CGSize.zero
        guard AXValueGetValue(unsafeBitCast(value, to: AXValue.self), .cgSize, &size) else {
            return nil
        }
        return size
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
        case "write":
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
        case "left", "tab left":
            return .left
        case "right", "tab right":
            return .right
        default:
            return nil
        }
    }

    static func isBackCommand(transcript: String, bundleID: String) -> Bool {
        self.herdrBundleIDs.contains(bundleID.lowercased())
            && self.normalizedPhrase(transcript) == "back"
    }

    static func returnToPreviousHerdrTarget(targetPID: pid_t) -> Bool {
        guard self.postKey(
            CGKeyCode(kVK_ANSI_E),
            flags: .maskCommand,
            to: targetPID
        ) else {
            return false
        }
        return self.postKey(CGKeyCode(kVK_Return), to: targetPID)
    }

    static func isRunHerdrCommand(transcript: String) -> Bool {
        let phrase = self.normalizedPhrase(transcript)
        return self.synonyms.herdrNames.contains { phrase == "run " + $0 }
    }

    static func typeHerdrCommand(targetPID: pid_t) -> Bool {
        self.postText("herdr", to: targetPID)
    }

    static func isDetachHerdrCommand(transcript: String, bundleID: String) -> Bool {
        self.herdrBundleIDs.contains(bundleID.lowercased())
            && self.normalizedPhrase(transcript) == "detach"
    }

    static func detachHerdr(targetPID: pid_t) -> Bool {
        guard self.postKey(
            CGKeyCode(kVK_ANSI_B),
            flags: .maskControl,
            to: targetPID
        ) else {
            return false
        }
        return self.postKey(CGKeyCode(kVK_ANSI_Q), to: targetPID)
    }

    static func isCloseTabCommand(transcript: String, bundleID: String) -> Bool {
        guard self.herdrBundleIDs.contains(bundleID.lowercased()) else { return false }
        return ["close", "close tab"].contains(self.normalizedPhrase(transcript))
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

    @MainActor
    static func showCopiedActionToast(_ text: String) {
        VoiceMacroStatusToast.shared.show(
            text,
            maximumLines: 16,
            textWidth: 420
        )
    }

    @MainActor
    static func showCopiedResultToast(_ text: String) {
        VoiceMacroStatusToast.shared.show(
            "Copied last result:\n\n\(text)",
            maximumLines: 16,
            textWidth: 420
        )
    }

    @MainActor
    static func showCodexStatusLoadingToast() {
        VoiceMacroStatusToast.shared.show(
            "Reading Codex weekly usage…",
            automaticallyHides: false
        )
    }

    @MainActor
    static func showCodexStatusToast(_ status: CodexWeeklyStatus) {
        let now = Date()
        let pacing = status.pacing(now: now)
        VoiceMacroStatusToast.shared.show(
            status.summary(now: now),
            progress: status.usageFraction,
            pacingProgress: pacing.allowedUsageFraction,
            isOnPace: status.usageFraction <= pacing.allowedUsageFraction
        )
    }

    static func resolveWorkspace(query: String, workspaces: [HerdrWorkspace]) -> HerdrWorkspace? {
        let normalizedQuery = self.normalizedPhrase(query)
        guard !normalizedQuery.isEmpty else { return nil }

        if let exact = workspaces.first(where: { self.normalizedPhrase($0.label) == normalizedQuery }) {
            return exact
        }

        let aliasMatches = workspaces.filter { workspace in
            let aliases = self.synonyms.projects[workspace.label.lowercased()] ?? []
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

        guard let trailingText = invocation.trailingText else {
            let focusResult = await self.runProcess(
                executable,
                arguments: ["workspace", "focus", invocation.workspace.workspaceID]
            )
            return focusResult.status == 0 && self.activateHerdr()
        }

        return await self.openHerdrWorkspacePrompt(
            trailingText,
            workspace: invocation.workspace,
            executable: executable
        )
    }

    @MainActor
    private static func openHerdrWorkspacePrompt(
        _ prompt: String,
        workspace: HerdrWorkspace,
        executable: URL
    ) async -> Bool {
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

        if let emptyCodexPane = paneResponse.result.panes.first(where: {
            self.isUnusedCodexPane($0)
        }) {
            let focusWorkspaceResult = await self.runProcess(
                executable,
                arguments: ["workspace", "focus", workspace.workspaceID]
            )
            guard focusWorkspaceResult.status == 0 else { return false }
            let focusTabResult = await self.runProcess(
                executable,
                arguments: ["tab", "focus", emptyCodexPane.tabID]
            )
            guard focusTabResult.status == 0, self.activateHerdr() else { return false }
            try? await Task.sleep(for: .milliseconds(150))
            return await self.submitHerdrPrompt(prompt)
        }

        let cwd = paneResponse.result.panes.compactMap(\.cwd).first
            ?? self.localRepoURL(query: workspace.label)?.path
        guard let cwd else { return false }
        let createResult = await self.runProcess(
            executable,
            arguments: [
                "tab", "create",
                "--workspace", workspace.workspaceID,
                "--cwd", cwd,
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

        let paneID = created.result.rootPane.paneID
        let runResult = await self.runProcess(
            executable,
            arguments: ["pane", "run", paneID, self.shellBackedCodexLaunchCommand]
        )
        guard runResult.status == 0, self.activateHerdr() else { return false }

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
                   $0.paneID == paneID
               }),
               self.isCodexPaneReady(
                   agent: createdPane.agent,
                   agentStatus: createdPane.agentStatus
               )
            {
                try? await Task.sleep(for: .milliseconds(150))
                return await self.submitHerdrPrompt(prompt)
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return false
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
            arguments: [
                "pane", "run", created.result.rootPane.paneID,
                self.shellBackedCodexLaunchCommand,
            ]
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
               self.isCodexPaneReady(
                   agent: createdPane.agent,
                   agentStatus: createdPane.agentStatus
               )
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
            arguments: [
                "pane", "run", created.result.rootPane.paneID,
                self.shellBackedCodexLaunchCommand,
            ]
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
               self.isCodexPaneReady(
                   agent: createdPane.agent,
                   agentStatus: createdPane.agentStatus
               )
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
            self.isUnusedCodexPane($0)
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
            arguments: [
                "pane", "run", created.result.rootPane.paneID,
                self.shellBackedCodexLaunchCommand,
            ]
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
               self.isCodexPaneReady(
                   agent: createdPane.agent,
                   agentStatus: createdPane.agentStatus
               )
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

    private static func isUnusedCodexPane(_ pane: HerdrPaneListResponse.Pane) -> Bool {
        guard self.isCodexPaneReady(agent: pane.agent, agentStatus: pane.agentStatus),
              let sessionID = pane.agentSession?.value,
              let sessionContents = self.codexSessionContents(sessionID: sessionID)
        else {
            return false
        }
        return !self.codexSessionHasUserMessage(sessionContents)
    }

    static func isCodexPaneReady(agent: String?, agentStatus: String?) -> Bool {
        agent?.lowercased() == "codex" && agentStatus?.lowercased() == "idle"
    }

    static func codexSessionHasUserMessage(_ contents: String) -> Bool {
        contents.split(separator: "\n").contains { line in
            line.contains(#""type":"event_msg""#)
                && line.contains(#""type":"user_message""#)
        }
    }

    static func codexReasoningShortcutAdjustment(
        paneText: String,
        requestedLevel: CodexReasoningLevel
    ) -> Int? {
        let orderedEfforts = ["low", "medium", "high", "xhigh", "max", "ultra"]
        guard let currentEffort = self.currentCodexReasoningEffort(inPaneText: paneText),
              let currentIndex = orderedEfforts.firstIndex(of: currentEffort),
              let requestedIndex = orderedEfforts.firstIndex(of: requestedLevel.rawValue)
        else {
            return nil
        }
        return requestedIndex - currentIndex
    }

    static func currentCodexReasoningEffort(inPaneText paneText: String) -> String? {
        guard let expression = try? NSRegularExpression(
            pattern: #"\b(?:gpt|o)[a-z0-9._-]*\s+(low|medium|high|xhigh|extra high|max|ultra)\b"#,
            options: [.caseInsensitive]
        ) else {
            return nil
        }
        let range = NSRange(paneText.startIndex..., in: paneText)
        guard let match = expression.matches(in: paneText, range: range).last,
              let effortRange = Range(match.range(at: 1), in: paneText)
        else {
            return nil
        }
        let effort = paneText[effortRange].lowercased()
        return effort == "extra high" ? "xhigh" : effort
    }

    private static func codexSessionContents(sessionID: String) -> String? {
        let codexURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
        for directoryName in ["sessions", "archived_sessions"] {
            let directoryURL = codexURL.appendingPathComponent(directoryName, isDirectory: true)
            guard let enumerator = FileManager.default.enumerator(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else {
                continue
            }
            for case let fileURL as URL in enumerator
                where fileURL.lastPathComponent.contains(sessionID)
                    && fileURL.pathExtension == "jsonl"
            {
                return try? String(contentsOf: fileURL, encoding: .utf8)
            }
        }
        return nil
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
            arguments: ["pane", "run", paneID, self.shellBackedCodexLaunchCommand]
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
               self.isCodexPaneReady(
                   agent: createdPane.agent,
                   agentStatus: createdPane.agentStatus
               )
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
    static func submitClearFollowUpInCurrentHerdrPane(
        _ message: String,
        openNextPendingTab: Bool
    ) async -> Bool {
        let logSource = "VoiceMacroService"
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
              ).result.pane,
              currentPane.agent?.lowercased() == "codex"
        else {
            return false
        }

        let startedAt = Date()
        let previousSessionID = currentPane.agentSession?.value
        DebugLogger.shared.info(
            "Clear follow-up started: pane=\(currentPane.paneID) session=\(previousSessionID ?? "none")",
            source: logSource
        )

        let clearResult = await self.runProcess(
            executable,
            arguments: ["pane", "run", currentPane.paneID, "/clear"]
        )
        guard clearResult.status == 0 else {
            DebugLogger.shared.warning(
                "Clear follow-up failed to submit /clear: pane=\(currentPane.paneID) status=\(clearResult.status)",
                source: logSource
            )
            return false
        }

        DebugLogger.shared.info(
            "Clear follow-up submitted /clear: pane=\(currentPane.paneID)",
            source: logSource
        )
        try? await Task.sleep(for: .milliseconds(300))

        for attempt in 0..<18 {
            let paneResult = await self.runProcess(
                executable,
                arguments: ["pane", "get", currentPane.paneID]
            )
            let updatedPane = paneResult.status == 0
                ? try? JSONDecoder().decode(
                      HerdrCurrentPaneResponse.self,
                      from: paneResult.output
                  ).result.pane
                : nil
            let elapsedMilliseconds = Int(Date().timeIntervalSince(startedAt) * 1_000)
            DebugLogger.shared.info(
                "Clear follow-up readiness poll: pane=\(currentPane.paneID) attempt=\(attempt + 1) elapsedMs=\(elapsedMilliseconds) commandStatus=\(paneResult.status) agent=\(updatedPane?.agent ?? "none") agentStatus=\(updatedPane?.agentStatus ?? "none") previousSession=\(previousSessionID ?? "none") currentSession=\(updatedPane?.agentSession?.value ?? "none")",
                source: logSource
            )

            guard let updatedPane,
                  self.isCodexPaneReady(
                      agent: updatedPane.agent,
                      agentStatus: updatedPane.agentStatus
                  )
            else {
                if attempt < 17 {
                    try? await Task.sleep(for: .milliseconds(100))
                }
                continue
            }

            let followUpResult = await self.runProcess(
                executable,
                arguments: ["pane", "run", currentPane.paneID, message]
            )
            guard followUpResult.status == 0 else {
                DebugLogger.shared.warning(
                    "Clear follow-up submission failed: pane=\(currentPane.paneID) status=\(followUpResult.status)",
                    source: logSource
                )
                self.showStatusToast("New session is ready, but the follow-up was not submitted.")
                return true
            }
            DebugLogger.shared.info(
                "Clear follow-up submitted: pane=\(currentPane.paneID) elapsedMs=\(Int(Date().timeIntervalSince(startedAt) * 1_000))",
                source: logSource
            )
            if openNextPendingTab, !(await self.openNextPendingHerdrTab()) {
                self.showStatusToast("Follow-up submitted, but the next pending tab did not open.")
            }
            return true
        }
        DebugLogger.shared.warning(
            "Clear follow-up timed out waiting for Codex idle: pane=\(currentPane.paneID) elapsedMs=\(Int(Date().timeIntervalSince(startedAt) * 1_000))",
            source: logSource
        )
        self.showStatusToast("Codex did not become ready. Follow-up was not submitted.")
        return true
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

    @MainActor
    static func restartCodexInCurrentHerdrPane() async -> RestartCodexResult {
        let logSource = "VoiceMacroService"
        DebugLogger.shared.info("Restart Codex started", source: logSource)
        guard let executable = self.herdrExecutableURL() else {
            DebugLogger.shared.error("Restart Codex could not find the Herdr executable", source: logSource)
            return .failed
        }
        let currentResult = await self.runProcess(
            executable,
            arguments: ["pane", "current", "--current"],
            removingEnvironmentVariables: self.herdrCallerEnvironmentVariables
        )
        guard currentResult.status == 0 else {
            DebugLogger.shared.error(
                "Restart Codex pane lookup failed with status \(currentResult.status): \(self.logSafeOutput(currentResult.output))",
                source: logSource
            )
            return .failed
        }
        guard let currentPane = try? JSONDecoder().decode(
            HerdrCurrentPaneResponse.self,
            from: currentResult.output
        ).result.pane else {
            DebugLogger.shared.error(
                "Restart Codex could not decode the current pane: \(self.logSafeOutput(currentResult.output))",
                source: logSource
            )
            return .failed
        }
        guard currentPane.agent?.lowercased() == "codex" else {
            DebugLogger.shared.error(
                "Restart Codex current pane \(currentPane.paneID) has agent \(currentPane.agent ?? "nil")",
                source: logSource
            )
            return .failed
        }
        DebugLogger.shared.info(
            "Restart Codex found pane \(currentPane.paneID); session present=\(currentPane.agentSession?.value != nil)",
            source: logSource
        )

        let reportedSessionID: String?
        if let value = currentPane.agentSession?.value,
           value.range(of: #"^[A-Za-z0-9-]+$"#, options: .regularExpression) != nil
        {
            reportedSessionID = value
        } else {
            reportedSessionID = nil
        }

        guard let originalCodexPID = await self.codexProcesses(
            inPane: currentPane.paneID,
            executable: executable
        )?.first?.pid else {
            DebugLogger.shared.error(
                "Restart Codex found no foreground Codex process in pane \(currentPane.paneID)",
                source: logSource
            )
            return .failed
        }
        DebugLogger.shared.info(
            "Restart Codex will interrupt PID \(originalCodexPID) in pane \(currentPane.paneID)",
            source: logSource
        )
        let terminalBeforeExit = await self.readRecentPaneText(
            currentPane.paneID,
            executable: executable
        ) ?? ""

        // When Codex is generating, the first Ctrl-C only interrupts the turn.
        // Send another only if the same Codex process remains in the foreground.
        for interruptAttempt in 0..<3 {
            DebugLogger.shared.info(
                "Restart Codex sending Ctrl-C attempt \(interruptAttempt + 1) to pane \(currentPane.paneID)",
                source: logSource
            )
            let interruptResult = await self.runProcess(
                executable,
                arguments: ["pane", "send-keys", currentPane.paneID, "ctrl+c"]
            )
            guard interruptResult.status == 0 else {
                DebugLogger.shared.error(
                    "Restart Codex failed to send Ctrl-C (attempt \(interruptAttempt + 1))",
                    source: "VoiceMacroService"
                )
                return .failed
            }

            for _ in 0..<15 {
                try? await Task.sleep(for: .milliseconds(100))
                guard let runningProcesses = await self.codexProcesses(
                    inPane: currentPane.paneID,
                    executable: executable
                ) else {
                    continue
                }
                let runningPID = runningProcesses.first?.pid
                if runningPID == nil {
                    var sessionID = reportedSessionID
                    if sessionID == nil {
                        if let terminalAfterExit = await self.readRecentPaneText(
                            currentPane.paneID,
                            executable: executable
                        ) {
                            sessionID = self.newCodexResumeSessionID(
                                beforeExit: terminalBeforeExit,
                                afterExit: terminalAfterExit
                            )
                        }
                    }
                    guard let sessionID else {
                        DebugLogger.shared.info(
                            "Restart Codex exited a bare session with no thread ID to resume",
                            source: logSource
                        )
                        return .noThreadToResume
                    }
                    DebugLogger.shared.info(
                        "Restart Codex process exited after Ctrl-C attempt \(interruptAttempt + 1); sending resume",
                        source: logSource
                    )
                    let resumeResult = await self.runProcess(
                        executable,
                        arguments: [
                            "pane", "run", currentPane.paneID,
                            "codex resume \(sessionID)",
                        ]
                    )
                    guard resumeResult.status == 0 else {
                        DebugLogger.shared.error(
                            "Restart Codex resume command failed with status \(resumeResult.status)",
                            source: "VoiceMacroService"
                        )
                        return .failed
                    }

                    for _ in 0..<30 {
                        try? await Task.sleep(for: .milliseconds(100))
                        if let resumedPID = await self.codexProcesses(
                            inPane: currentPane.paneID,
                            executable: executable
                        )?.first?.pid, resumedPID != originalCodexPID {
                            DebugLogger.shared.info(
                                "Restart Codex resumed successfully as PID \(resumedPID)",
                                source: logSource
                            )
                            return .restarted
                        }
                    }
                    DebugLogger.shared.error(
                        "Restart Codex could not verify the resumed process",
                        source: "VoiceMacroService"
                    )
                    return .failed
                }
            }
            let remainingPID = await self.codexProcesses(
                inPane: currentPane.paneID,
                executable: executable
            )?.first?.pid
            DebugLogger.shared.info(
                "Restart Codex Ctrl-C attempt \(interruptAttempt + 1) completed; foreground Codex PID=\(remainingPID.map(String.init) ?? "nil")",
                source: logSource
            )
        }
        DebugLogger.shared.error(
            "Restart Codex process remained after three Ctrl-C attempts",
            source: "VoiceMacroService"
        )
        return .failed
    }

    @MainActor
    static func setCodexReasoningLevel(
        _ level: CodexReasoningLevel,
        targetPID: pid_t
    ) async -> CodexReasoningSetResult {
        let logSource = "VoiceMacroService"
        guard self.isTargetFrontmost(targetPID),
              let executable = self.herdrExecutableURL()
        else {
            return .failed
        }
        let currentResult = await self.runProcess(
            executable,
            arguments: ["pane", "current", "--current"],
            removingEnvironmentVariables: self.herdrCallerEnvironmentVariables
        )
        guard currentResult.status == 0,
              let currentPane = try? JSONDecoder().decode(
                  HerdrCurrentPaneResponse.self,
                  from: currentResult.output
              ).result.pane,
              currentPane.agent?.lowercased() == "codex",
              self.isTargetFrontmost(targetPID)
        else {
            return .failed
        }
        guard currentPane.agentStatus?.lowercased() != "working" else {
            DebugLogger.shared.info(
                "Codex reasoning command deferred: pane=\(currentPane.paneID) status=working requested=\(level.rawValue)",
                source: logSource
            )
            return .busy
        }

        let readArguments = [
            "pane", "read", currentPane.paneID,
            "--source", "visible", "--format", "text",
        ]
        let paneRead = await self.runProcess(
            executable,
            arguments: readArguments,
            removingEnvironmentVariables: self.herdrCallerEnvironmentVariables
        )
        guard paneRead.status == 0,
              let adjustment = self.codexReasoningShortcutAdjustment(
                  paneText: String(decoding: paneRead.output, as: UTF8.self),
                  requestedLevel: level
              )
        else {
            DebugLogger.shared.error(
                "Codex reasoning command could not read current effort: pane=\(currentPane.paneID) requested=\(level.rawValue)",
                source: logSource
            )
            return .failed
        }

        DebugLogger.shared.info(
            "Codex reasoning adjustment: pane=\(currentPane.paneID) requested=\(level.rawValue) steps=\(adjustment)",
            source: logSource
        )
        if adjustment != 0 {
            let key = adjustment < 0 ? "alt+comma" : "alt+period"
            let sendResult = await self.runProcess(
                executable,
                arguments: ["pane", "send-keys", currentPane.paneID]
                    + Array(repeating: key, count: abs(adjustment)),
                removingEnvironmentVariables: self.herdrCallerEnvironmentVariables
            )
            guard sendResult.status == 0 else {
                DebugLogger.shared.error(
                    "Codex reasoning key delivery failed: pane=\(currentPane.paneID) requested=\(level.rawValue)",
                    source: logSource
                )
                return .failed
            }
        }

        for _ in 0..<10 {
            let verification = await self.runProcess(
                executable,
                arguments: readArguments,
                removingEnvironmentVariables: self.herdrCallerEnvironmentVariables
            )
            if verification.status == 0,
               self.currentCodexReasoningEffort(
                   inPaneText: String(decoding: verification.output, as: UTF8.self)
               ) == level.rawValue
            {
                DebugLogger.shared.info(
                    "Codex reasoning verified: pane=\(currentPane.paneID) level=\(level.rawValue)",
                    source: logSource
                )
                return .set
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        DebugLogger.shared.error(
            "Codex reasoning verification failed: pane=\(currentPane.paneID) requested=\(level.rawValue)",
            source: logSource
        )
        return .failed
    }

    static func newCodexResumeSessionID(beforeExit: String, afterExit: String) -> String? {
        var priorCounts: [String: Int] = [:]
        for sessionID in self.codexResumeSessionIDs(in: beforeExit) {
            priorCounts[sessionID, default: 0] += 1
        }
        var seenCounts: [String: Int] = [:]
        return self.codexResumeSessionIDs(in: afterExit).last { sessionID in
            seenCounts[sessionID, default: 0] += 1
            return seenCounts[sessionID, default: 0] > priorCounts[sessionID, default: 0]
        }
    }

    private static func codexResumeSessionIDs(in terminalText: String) -> [String] {
        guard let expression = try? NSRegularExpression(
            pattern: #"(?i)To continue this session, run codex resume[^\n]*\(([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\)"#
        ) else { return [] }
        let range = NSRange(terminalText.startIndex..., in: terminalText)
        return expression.matches(in: terminalText, range: range).compactMap { match in
            guard let sessionRange = Range(match.range(at: 1), in: terminalText) else { return nil }
            return String(terminalText[sessionRange])
        }
    }

    private static func readRecentPaneText(_ paneID: String, executable: URL) async -> String? {
        let result = await self.runProcess(
            executable,
            arguments: [
                "pane", "read", paneID,
                "--source", "recent", "--lines", "30", "--format", "text",
            ]
        )
        guard result.status == 0 else { return nil }
        return String(data: result.output, encoding: .utf8)
    }

    private static func logSafeOutput(_ data: Data) -> String {
        let output = String(data: data, encoding: .utf8) ?? "<non-UTF8 output>"
        return String(output.replacingOccurrences(of: "\n", with: " ").prefix(500))
    }

    private static func codexProcesses(
        inPane paneID: String,
        executable: URL
    ) async -> [HerdrPaneProcessInfoResponse.ForegroundProcess]? {
        let processResult = await self.runProcess(
            executable,
            arguments: ["pane", "process-info", "--pane", paneID]
        )
        guard processResult.status == 0,
              let foregroundProcesses = try? JSONDecoder().decode(
                  HerdrPaneProcessInfoResponse.self,
                  from: processResult.output
              ).result.processInfo.foregroundProcesses
        else {
            return nil
        }
        return foregroundProcesses.filter { $0.name.lowercased() == "codex" }
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

        let listResult = await self.runProcess(
            executable,
            arguments: ["tab", "list", "--workspace", currentPane.workspaceID]
        )
        guard listResult.status == 0,
              let response = try? JSONDecoder().decode(
                  HerdrTabListResponse.self,
                  from: listResult.output
              )
        else {
            return false
        }

        let closeResult = await self.runProcess(
            executable,
            arguments: self.herdrCloseArguments(
                tabID: currentPane.tabID,
                workspaceID: currentPane.workspaceID,
                tabCount: response.result.tabs.count
            )
        )
        return closeResult.status == 0
    }

    static func herdrCloseArguments(
        tabID: String,
        workspaceID: String,
        tabCount: Int
    ) -> [String] {
        if tabCount == 1 {
            return ["workspace", "close", workspaceID]
        }
        return ["tab", "close", tabID]
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
        let normalizedQuery = self.synonyms.applications[rawNormalizedQuery] ?? rawNormalizedQuery
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
        for command in self.synonyms.herdrCommands {
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

    private static func regexAlternation(_ phrases: [String]) -> String {
        phrases
            .sorted { $0.count > $1.count }
            .map(NSRegularExpression.escapedPattern(for:))
            .joined(separator: "|")
    }

    private static func normalizedCommandPhrase(_ text: String) -> String {
        self.normalizedPhrase(text)
            .split(separator: " ")
            .map { word in
                let word = String(word)
                return self.synonyms.speechRecognitionWords.first {
                    $0.value.contains(word)
                }?.key ?? word
            }
            .joined(separator: " ")
    }

    private static func newCodexTabInvocation(
        transcript: String
    ) -> NewCodexTabInvocation? {
        let leadingPattern = #"^(new codex (?:tab|tap)|codex new (?:tab|tap)|new (?:tab|tap))\b(.*)$"#
        guard let leadingExpression = try? NSRegularExpression(
            pattern: leadingPattern,
            options: [.caseInsensitive]
        ) else {
            return nil
        }

        let range = NSRange(transcript.startIndex..., in: transcript)
        if let match = leadingExpression.firstMatch(in: transcript, range: range),
           match.range.location == 0,
           let trailingRange = Range(match.range(at: 2), in: transcript)
        {
            let trailingText = String(transcript[trailingRange].drop(while: {
                $0.isWhitespace || $0.isPunctuation
            }))
            return NewCodexTabInvocation(
                trailingText: trailingText.isEmpty ? nil : trailingText
            )
        }

        let trailingPattern = #"^(.*?)\b(new codex (?:tab|tap)|codex new (?:tab|tap)|new (?:tab|tap))[\s\p{P}]*$"#
        guard let trailingExpression = try? NSRegularExpression(
            pattern: trailingPattern,
            options: [.caseInsensitive]
        ),
        let match = trailingExpression.firstMatch(in: transcript, range: range),
        let precedingRange = Range(match.range(at: 1), in: transcript)
        else {
            return nil
        }

        let commandSeparators = CharacterSet.whitespacesAndNewlines.union(
            CharacterSet(charactersIn: ",;:")
        )
        let precedingText = String(transcript[precedingRange])
            .trimmingCharacters(in: commandSeparators)
        guard self.normalizedPhrase(precedingText) != "open a" else { return nil }
        return NewCodexTabInvocation(
            trailingText: precedingText.isEmpty ? nil : precedingText
        )
    }

    private static func canonicalProjectName(for spokenName: String) -> String? {
        let normalizedName = self.normalizedPhrase(spokenName)
        return self.synonyms.projects.first { projectName, aliases in
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

    private static func executableURL(named name: String) -> URL? {
        let candidates = [
            URL(fileURLWithPath: "/opt/homebrew/bin/\(name)"),
            URL(fileURLWithPath: "/usr/local/bin/\(name)"),
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
private final class VoiceMacroUsageProgressBar: NSView {
    var progress = 0.0 {
        didSet { self.needsDisplay = true }
    }

    var fillColor = NSColor.controlAccentColor {
        didSet { self.needsDisplay = true }
    }

    var pacingProgress: Double? {
        didSet { self.needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: 6)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let trackPath = NSBezierPath(roundedRect: self.bounds, xRadius: 3, yRadius: 3)
        NSColor.quaternaryLabelColor.setFill()
        trackPath.fill()

        let fillWidth = self.bounds.width * min(max(self.progress, 0), 1)
        if fillWidth > 0 {
            let fillRect = NSRect(x: 0, y: 0, width: fillWidth, height: self.bounds.height)
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 3, yRadius: 3)
            self.fillColor.setFill()
            fillPath.fill()
        }

        if let pacingProgress {
            let markerCenter = self.bounds.width * min(max(pacingProgress, 0), 1)
            let markerX = min(max(markerCenter - 1, 0), self.bounds.width - 2)
            let markerPath = NSBezierPath(
                roundedRect: NSRect(x: markerX, y: 0, width: 2, height: self.bounds.height),
                xRadius: 1,
                yRadius: 1
            )
            NSColor.labelColor.setFill()
            markerPath.fill()
        }
    }
}

@MainActor
private final class VoiceMacroStatusToast {
    static let shared = VoiceMacroStatusToast()

    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")
    private let progressBar = VoiceMacroUsageProgressBar()
    private lazy var labelWidthConstraint = self.label.widthAnchor.constraint(equalToConstant: 260)
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

        self.progressBar.isHidden = true

        let stack = NSStackView(views: [self.label, self.progressBar])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: background.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -14),
            self.labelWidthConstraint,
            self.progressBar.widthAnchor.constraint(equalTo: self.label.widthAnchor),
        ])
        self.panel.contentView = background
    }

    func show(
        _ text: String,
        progress: Double? = nil,
        pacingProgress: Double? = nil,
        isOnPace: Bool? = nil,
        automaticallyHides: Bool = true,
        maximumLines: Int = 3,
        textWidth: CGFloat = 260
    ) {
        self.hideTask?.cancel()
        self.label.maximumNumberOfLines = maximumLines
        self.labelWidthConstraint.constant = textWidth
        self.label.stringValue = text
        if let progress {
            let normalizedProgress = min(max(progress, 0), 1)
            self.progressBar.progress = normalizedProgress
            self.progressBar.pacingProgress = pacingProgress
            self.progressBar.fillColor = switch isOnPace {
            case true: .systemGreen
            case false where normalizedProgress >= 0.9: .systemRed
            case false: .systemOrange
            case nil: .controlAccentColor
            }
            self.progressBar.isHidden = false
        } else {
            self.progressBar.pacingProgress = nil
            self.progressBar.isHidden = true
        }
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
        guard automaticallyHides else { return }
        self.hideTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            self.panel.orderOut(nil)
        }
    }
}
