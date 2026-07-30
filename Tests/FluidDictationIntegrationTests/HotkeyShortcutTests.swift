import AppKit
@testable import FluidVoice_Debug
import Foundation
import XCTest

final class HotkeyShortcutTests: XCTestCase {
    private let legacyHotkeyShortcutKey = "HotkeyShortcutKey"
    private let primaryDictationShortcutsKey = "PrimaryDictationShortcuts"
    private let pasteLastTranscriptionShortcutKey = "PasteLastTranscriptionHotkeyShortcut"
    private let pasteLastTranscriptionEnabledKey = "PasteLastTranscriptionShortcutEnabled"

    func testRecentTranscriptMenuTitleCollapsesWhitespaceAndTruncatesLongText() {
        XCTAssertEqual(
            MenuBarManager.recentTranscriptMenuTitle(for: "First line\n  second\tline"),
            "First line second line"
        )

        let longText = String(repeating: "a", count: 81)
        XCTAssertEqual(
            MenuBarManager.recentTranscriptMenuTitle(for: longText),
            String(repeating: "a", count: 77) + "..."
        )
    }

    func testHerdrWorkspaceCommandExtractsWorkspaceName() {
        XCTAssertEqual(VoiceMacroService.herdrWorkspaceQuery(
            transcript: "Edit comms."
        ), "comms.")
        XCTAssertEqual(VoiceMacroService.herdrWorkspaceQuery(
            transcript: "  EDIT   fluid voice! "
        ), "fluid voice!")
        XCTAssertEqual(VoiceMacroService.herdrWorkspaceQuery(
            transcript: "Her Fluid Voice",
            bundleID: "com.mitchellh.ghostty"
        ), "Fluid Voice")
        XCTAssertNil(VoiceMacroService.herdrWorkspaceQuery(
            transcript: "Herder comms."
        ))
        XCTAssertNil(VoiceMacroService.herdrWorkspaceQuery(
            transcript: "Terminal comms."
        ))
        XCTAssertNil(VoiceMacroService.herdrWorkspaceQuery(
            transcript: "Her name is Sarah",
            bundleID: "com.google.Chrome"
        ))
    }

    func testHerdrWorkspaceOpenCommandIsNotSupported() {
        XCTAssertNil(VoiceMacroService.herdrWorkspaceQuery(
            transcript: "open comms",
            bundleID: "com.mitchellh.ghostty"
        ))
        XCTAssertNil(VoiceMacroService.herdrWorkspaceQuery(
            transcript: "open comms",
            bundleID: "com.google.Chrome"
        ))
    }

    func testApplicationLaunchCommandSupportsExplicitPhrases() {
        XCTAssertEqual(
            VoiceMacroService.applicationLaunchQuery(transcript: "Launch Key Mapper."),
            "Key Mapper"
        )
        XCTAssertEqual(
            VoiceMacroService.applicationLaunchQuery(transcript: "Open the Key Mapper app!"),
            "Key Mapper"
        )
        XCTAssertEqual(
            VoiceMacroService.applicationLaunchQuery(transcript: "open Key Mapper application"),
            "Key Mapper"
        )
    }

    func testApplicationLaunchCommandDoesNotClaimWorkspacePhrase() {
        XCTAssertNil(
            VoiceMacroService.applicationLaunchQuery(transcript: "Open Key Mapper")
        )
    }

    func testApplicationLaunchCommandSupportsBareInstalledApplicationName() {
        let applications = [
            URL(fileURLWithPath: "/Applications/Key Mapper.app"),
            URL(fileURLWithPath: "/Applications/Keynote.app"),
        ]

        XCTAssertEqual(
            VoiceMacroService.applicationLaunchQuery(
                transcript: "Key Mapper.",
                candidates: applications
            ),
            "Key Mapper"
        )
        XCTAssertNil(VoiceMacroService.applicationLaunchQuery(
            transcript: "Write a note.",
            candidates: applications
        ))
    }

    func testApplicationResolutionIgnoresSpacingAndSupportsUniqueTypos() {
        let applications = [
            URL(fileURLWithPath: "/Applications/keymapper.app"),
            URL(fileURLWithPath: "/Applications/Google Chrome.app"),
            URL(fileURLWithPath: "/Applications/Keynote.app"),
        ]

        XCTAssertEqual(
            VoiceMacroService.resolveApplicationURL(
                query: "key mapper",
                candidates: applications
            ),
            applications[0]
        )
        XCTAssertEqual(
            VoiceMacroService.resolveApplicationURL(
                query: "key mappr",
                candidates: applications
            ),
            applications[0]
        )
    }

    func testApplicationResolutionRejectsAmbiguousMatches() {
        XCTAssertNil(VoiceMacroService.resolveApplicationURL(
            query: "Note",
            candidates: [
                URL(fileURLWithPath: "/Applications/Notes.app"),
                URL(fileURLWithPath: "/Applications/Noted.app"),
            ]
        ))
    }

    func testApplicationResolutionSupportsChatGPTClassicAlias() {
        let chatGPTClassic = URL(fileURLWithPath: "/Applications/ChatGPT Classic.app")

        XCTAssertEqual(
            VoiceMacroService.resolveApplicationURL(
                query: "ChatGPT",
                candidates: [chatGPTClassic]
            ),
            chatGPTClassic
        )
    }

    func testWorkspaceResolutionSupportsExactAliasAndUniqueTypoMatches() {
        let workspaces = [
            VoiceMacroService.HerdrWorkspace(label: "comms", workspaceID: "w1"),
            VoiceMacroService.HerdrWorkspace(label: "fluidvoice", workspaceID: "w2"),
            VoiceMacroService.HerdrWorkspace(label: "commerce-land", workspaceID: "w3"),
            VoiceMacroService.HerdrWorkspace(label: "commerce-leak", workspaceID: "w4"),
            VoiceMacroService.HerdrWorkspace(label: "ordellan", workspaceID: "w5"),
        ]

        XCTAssertEqual(
            VoiceMacroService.resolveWorkspace(query: "COMMS", workspaces: workspaces)?.workspaceID,
            "w1"
        )
        XCTAssertEqual(
            VoiceMacroService.resolveWorkspace(query: "fluid boys", workspaces: workspaces)?.workspaceID,
            "w2"
        )
        XCTAssertEqual(
            VoiceMacroService.resolveWorkspace(query: "coms", workspaces: workspaces)?.workspaceID,
            "w1"
        )
        XCTAssertEqual(
            VoiceMacroService.resolveWorkspace(query: "or Dell in", workspaces: workspaces)?.workspaceID,
            "w5"
        )
        XCTAssertEqual(
            VoiceMacroService.resolveWorkspace(query: "or delin", workspaces: workspaces)?.workspaceID,
            "w5"
        )
        XCTAssertNil(VoiceMacroService.resolveWorkspace(query: "commerce", workspaces: workspaces))
    }

    func testCodexStatusCommandSupportsCommonRecognitionVariant() {
        XCTAssertTrue(VoiceMacroService.isCodexStatusCommand(transcript: "Codex status."))
        XCTAssertTrue(VoiceMacroService.isCodexStatusCommand(transcript: "Codec status"))
        XCTAssertFalse(VoiceMacroService.isCodexStatusCommand(transcript: "Codex stats"))
    }

    func testAddSynonymCommandUsesExactPhrase() {
        XCTAssertTrue(VoiceMacroService.isAddSynonymCommand(
            transcript: "Add synonym."
        ))
        XCTAssertTrue(VoiceMacroService.isAddSynonymCommand(
            transcript: "ADD SYNONYM!"
        ))
        XCTAssertFalse(VoiceMacroService.isAddSynonymCommand(
            transcript: "Add a synonym"
        ))
        XCTAssertFalse(VoiceMacroService.isAddSynonymCommand(
            transcript: "Add synonyms"
        ))
    }

    func testRefreshCommandIsScopedToChrome() {
        XCTAssertTrue(VoiceMacroService.isChromeRefreshCommand(
            transcript: "Refresh.",
            bundleID: "com.google.Chrome"
        ))
        XCTAssertFalse(VoiceMacroService.isChromeRefreshCommand(
            transcript: "Refresh",
            bundleID: "com.apple.Safari"
        ))
        XCTAssertFalse(VoiceMacroService.isChromeRefreshCommand(
            transcript: "Reload",
            bundleID: "com.google.Chrome"
        ))
    }

    func testCopyURLCommandIsScopedToChrome() {
        XCTAssertTrue(VoiceMacroService.isChromeCopyURLCommand(
            transcript: "Copy URL.",
            bundleID: "com.google.Chrome"
        ))
        XCTAssertTrue(VoiceMacroService.isChromeCopyURLCommand(
            transcript: "copy url",
            bundleID: "com.google.Chrome"
        ))
        XCTAssertFalse(VoiceMacroService.isChromeCopyURLCommand(
            transcript: "Copy URL",
            bundleID: "com.apple.Safari"
        ))
        XCTAssertFalse(VoiceMacroService.isChromeCopyURLCommand(
            transcript: "Copy the URL",
            bundleID: "com.google.Chrome"
        ))
    }

    func testChromeCloseTabCommandIsExactAndAppScoped() {
        XCTAssertTrue(VoiceMacroService.isChromeCloseTabCommand(
            transcript: "Close tab.",
            bundleID: "com.google.Chrome"
        ))
        XCTAssertFalse(VoiceMacroService.isChromeCloseTabCommand(
            transcript: "Close the tab",
            bundleID: "com.google.Chrome"
        ))
        XCTAssertFalse(VoiceMacroService.isChromeCloseTabCommand(
            transcript: "Close tab",
            bundleID: "com.mitchellh.ghostty"
        ))
    }

    func testCloseWindowCommandAcceptsBothWordOrders() {
        XCTAssertTrue(VoiceMacroService.isCloseWindowCommand(
            transcript: "Close window."
        ))
        XCTAssertTrue(VoiceMacroService.isCloseWindowCommand(
            transcript: "Window close!"
        ))
        XCTAssertTrue(VoiceMacroService.isCloseWindowCommand(
            transcript: "Closed window."
        ))
        XCTAssertFalse(VoiceMacroService.isCloseWindowCommand(
            transcript: "Close"
        ))
        XCTAssertFalse(VoiceMacroService.isCloseWindowCommand(
            transcript: "Close the window"
        ))
    }

    func testBackCommandUsesExactPhrase() {
        XCTAssertTrue(VoiceMacroService.isBackCommand(transcript: "Back."))
        XCTAssertFalse(VoiceMacroService.isBackCommand(transcript: "Go back"))
    }

    func testWindowScreenshotCommandUsesExactPhrase() {
        XCTAssertTrue(VoiceMacroService.isWindowScreenshotCommand(
            transcript: "Screenshot window."
        ))
        XCTAssertTrue(VoiceMacroService.isWindowScreenshotCommand(
            transcript: "Screen shot window!"
        ))
        XCTAssertFalse(VoiceMacroService.isWindowScreenshotCommand(
            transcript: "Screenshot the window"
        ))
        XCTAssertFalse(VoiceMacroService.isWindowScreenshotCommand(
            transcript: "Screenshot"
        ))
    }

    func testWindowMiddleCommandUsesExactPhrase() {
        XCTAssertTrue(VoiceMacroService.isWindowMiddleCommand(
            transcript: "Window middle."
        ))
        XCTAssertTrue(VoiceMacroService.isWindowMiddleCommand(
            transcript: "WINDOW MIDDLE!"
        ))
        XCTAssertFalse(VoiceMacroService.isWindowMiddleCommand(
            transcript: "move window middle"
        ))
        XCTAssertFalse(VoiceMacroService.isWindowMiddleCommand(
            transcript: "window"
        ))
        XCTAssertEqual(
            VoiceMacroService.windowMiddleURL,
            URL(string: "rectangle-pro://execute-custom?name=Middle")
        )
    }

    func testWindowTopLeftCommandUsesExactPhrase() {
        XCTAssertTrue(VoiceMacroService.isWindowTopLeftCommand(
            transcript: "Window top left."
        ))
        XCTAssertTrue(VoiceMacroService.isWindowTopLeftCommand(
            transcript: "WINDOW TOP LEFT!"
        ))
        XCTAssertFalse(VoiceMacroService.isWindowTopLeftCommand(
            transcript: "move window top left"
        ))
        XCTAssertFalse(VoiceMacroService.isWindowTopLeftCommand(
            transcript: "window top"
        ))
    }

    func testHerdrNotificationsCommandMatchesExactState() {
        XCTAssertEqual(
            VoiceMacroService.herdrNotificationsEnabledCommand(
                transcript: "Notifications on."
            ),
            true
        )
        XCTAssertEqual(
            VoiceMacroService.herdrNotificationsEnabledCommand(
                transcript: "notifications off"
            ),
            false
        )
        XCTAssertNil(
            VoiceMacroService.herdrNotificationsEnabledCommand(
                transcript: "toggle notifications"
            )
        )
    }

    func testNudgesCommandMatchesExactState() {
        XCTAssertEqual(
            VoiceMacroService.nudgesEnabledCommand(transcript: "Nudges on."),
            true
        )
        XCTAssertEqual(
            VoiceMacroService.nudgesEnabledCommand(transcript: "nudges off"),
            false
        )
        XCTAssertNil(
            VoiceMacroService.nudgesEnabledCommand(transcript: "toggle nudges")
        )
    }

    func testNewCodexTabCommandUsesExactPhrase() {
        XCTAssertTrue(VoiceMacroService.isNewCodexTabCommand(
            transcript: "New tab."
        ))
        XCTAssertTrue(VoiceMacroService.isNewCodexTabCommand(
            transcript: "New Codex tab."
        ))
        XCTAssertTrue(VoiceMacroService.isNewCodexTabCommand(
            transcript: "Codex new tab."
        ))
        XCTAssertTrue(VoiceMacroService.isNewCodexTabCommand(
            transcript: "New tab investigate the focus issue."
        ))
        XCTAssertEqual(
            VoiceMacroService.newCodexTabPrompt(
                transcript: "New Codex tab. Investigate the focus issue."
            ),
            "Investigate the focus issue."
        )
        XCTAssertEqual(
            VoiceMacroService.newCodexTabPrompt(
                transcript: "Codex new tab, review the current changes."
            ),
            "review the current changes."
        )
        XCTAssertNil(VoiceMacroService.newCodexTabPrompt(transcript: "New tab."))
        XCTAssertFalse(VoiceMacroService.isNewCodexTabCommand(
            transcript: "Open a new Codex tab"
        ))
    }

    func testWritingWorkspaceCommandHandlesWriteHomophones() {
        XCTAssertTrue(VoiceMacroService.isWritingWorkspaceCommand(
            transcript: "Write."
        ))
        XCTAssertTrue(VoiceMacroService.isWritingWorkspaceCommand(
            transcript: "Right"
        ))
        XCTAssertTrue(VoiceMacroService.isWritingWorkspaceCommand(
            transcript: "Start writing."
        ))
        XCTAssertTrue(VoiceMacroService.isWritingWorkspaceCommand(
            transcript: "Start writing draft a launch announcement."
        ))
        XCTAssertEqual(
            VoiceMacroService.writingWorkspacePrompt(
                transcript: "Start writing, draft a launch announcement."
            ),
            "draft a launch announcement."
        )
        XCTAssertNil(VoiceMacroService.writingWorkspacePrompt(
            transcript: "Start writing."
        ))
        XCTAssertFalse(VoiceMacroService.isWritingWorkspaceCommand(
            transcript: "Write this"
        ))
    }

    func testTabNavigationCommandsAreScopedToHerdr() {
        XCTAssertNotNil(VoiceMacroService.tabDirectionCommand(
            transcript: "Tab right.",
            bundleID: "com.mitchellh.ghostty"
        ))
        XCTAssertNotNil(VoiceMacroService.tabDirectionCommand(
            transcript: "Tab left",
            bundleID: "com.mitchellh.ghostty"
        ))
        XCTAssertNil(VoiceMacroService.tabDirectionCommand(
            transcript: "Tab right",
            bundleID: "com.google.Chrome"
        ))
    }

    func testCloseTabCommandIsScopedToHerdr() {
        XCTAssertTrue(VoiceMacroService.isCloseTabCommand(
            transcript: "Close tab.",
            bundleID: "com.mitchellh.ghostty"
        ))
        XCTAssertFalse(VoiceMacroService.isCloseTabCommand(
            transcript: "Close tab",
            bundleID: "com.google.Chrome"
        ))
        XCTAssertFalse(VoiceMacroService.isCloseTabCommand(
            transcript: "Close the tab",
            bundleID: "com.mitchellh.ghostty"
        ))
    }

    func testNextPendingCommandUsesExactPhrase() {
        XCTAssertTrue(VoiceMacroService.isNextPendingCommand(
            transcript: "Next."
        ))
        XCTAssertFalse(VoiceMacroService.isNextPendingCommand(
            transcript: "Next pending"
        ))
    }

    func testEDMFocusPlaylistCommandUsesConcisePhrase() {
        XCTAssertTrue(VoiceMacroService.isEDMFocusPlaylistCommand(
            transcript: "Spotify EDM."
        ))
        XCTAssertFalse(VoiceMacroService.isEDMFocusPlaylistCommand(
            transcript: "Play EDM Focus Background Beats"
        ))
    }

    func testCodexWeeklyStatusSummaryReportsWholeDayPacing() {
        let reset = Date(timeIntervalSince1970: 1_800_000_000)
        let now = reset.addingTimeInterval(-6.5 * 24 * 60 * 60)
        let summary = VoiceMacroService.CodexWeeklyStatus(
            usedPercent: 10,
            windowDurationMinutes: 7 * 24 * 60,
            resetsAt: reset
        ).summary(now: now)

        XCTAssertTrue(summary.contains("90% remaining"))
        XCTAssertTrue(summary.contains("On pace"))
        XCTAssertTrue(summary.contains("day 1 of 7"))
        XCTAssertTrue(summary.contains("Resets"))
    }

    func testWorkspaceInvocationSeparatesWorkspaceFromTrailingDictation() {
        let workspaces = [
            VoiceMacroService.HerdrWorkspace(label: "herdr", workspaceID: "w1"),
            VoiceMacroService.HerdrWorkspace(label: "commerce-land", workspaceID: "w2"),
        ]

        XCTAssertEqual(
            VoiceMacroService.resolveWorkspaceInvocation(
                query: "herder, investigate the focus issue.",
                workspaces: workspaces
            ),
            VoiceMacroService.HerdrWorkspaceInvocation(
                workspace: workspaces[0],
                trailingText: "investigate the focus issue."
            )
        )
        XCTAssertEqual(
            VoiceMacroService.resolveWorkspaceInvocation(
                query: "commerce land",
                workspaces: workspaces
            ),
            VoiceMacroService.HerdrWorkspaceInvocation(
                workspace: workspaces[1],
                trailingText: nil
            )
        )
    }

    func testChromeFindCommandUsesRawQueryAndIsAppScoped() {
        XCTAssertEqual(
            VoiceMacroService.chromeFindQuery(
                transcript: "Find Export Currently.",
                bundleID: "com.google.Chrome"
            ),
            "Export Currently"
        )
        XCTAssertNil(VoiceMacroService.chromeFindQuery(
            transcript: "Find export",
            bundleID: "com.apple.Safari"
        ))
    }

    func testChatGPTSearchCommandUsesRawQueryAndIsAppScoped() {
        XCTAssertEqual(
            VoiceMacroService.chatGPTSearchQuery(
                transcript: "Search Project planning notes.",
                bundleID: "com.openai.chat"
            ),
            "Project planning notes"
        )
        XCTAssertNil(VoiceMacroService.chatGPTSearchQuery(
            transcript: "Search project planning notes",
            bundleID: "com.google.Chrome"
        ))
        XCTAssertNil(VoiceMacroService.chatGPTSearchQuery(
            transcript: "Search",
            bundleID: "com.openai.chat"
        ))
    }

    func testChatGPTSidebarCommandIsExactAndAppScoped() {
        XCTAssertTrue(VoiceMacroService.isChatGPTSidebarCommand(
            transcript: "Sidebar.",
            bundleID: "com.openai.chat"
        ))
        XCTAssertFalse(VoiceMacroService.isChatGPTSidebarCommand(
            transcript: "Open sidebar",
            bundleID: "com.openai.chat"
        ))
        XCTAssertFalse(VoiceMacroService.isChatGPTSidebarCommand(
            transcript: "Sidebar",
            bundleID: "com.google.Chrome"
        ))
    }

    func testOutboundDashCommandIsExactAndGlobal() {
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Outbound Dash."),
            URL(string: "http://outbound-dash.localhost:8764")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "SignalFlame Site."),
            URL(string: "http://signalflame.localhost:8780")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Signal Flame Site."),
            URL(string: "http://signalflame.localhost:8780")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "HVAC Site."),
            URL(string: "http://hvac.localhost:8782")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Commerce Leak Site."),
            URL(string: "http://commerceleak.localhost:8781")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Ordellan Site."),
            URL(string: "http://ordellan.localhost:8783")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Commerce Land Site."),
            URL(string: "http://commerce-land.localhost:8784")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Matchbook Site."),
            URL(string: "http://matchbook.localhost:8786")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Outbound Farm Site."),
            URL(string: "http://outbound.farm.localhost:8787")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Signalflame Dash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/signalflame")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Signal Flame Dash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/signalflame")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Matchbook Dash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/matchbook")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Matt's book dash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/matchbook")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Commerce Land Dash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/commerce-land")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Commerce Landash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/commerce-land")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Commerce Land Ash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/commerce-land")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Commerce Land Act."),
            URL(string: "http://outbound-dash.localhost:8764/clients/commerce-land")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Carmer's Landash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/commerce-land")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Carmerce Land Dash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/commerce-land")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Commerceland Dash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/commerce-land")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Commerce Leak Dash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/commerce-leak")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Commerce leaked Ash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/commerce-leak")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Outbound ash."),
            URL(string: "http://outbound-dash.localhost:8764")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Ordellan Dash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/ordellan")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Or Dell and Dash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/ordellan")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Or Delin Dash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/ordellan")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "LinkedIn CRM Dash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/linkedin-crm")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "LinkedIn Dash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/linkedin-crm")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "ST3 Dash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/st3aero?view=targets")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "S T three dash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/st3aero?view=targets")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "HVAC Dash."),
            URL(
                string: "http://outbound-dash.localhost:8764/clients/hvac?card=opportunity_identified"
            )
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Layers Dash."),
            URL(
                string: "http://outbound-dash.localhost:8764/clients/layers?card=cannot_outreach"
            )
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Outbound Farm Dash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/outbound-farm")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "H fact dash."),
            URL(
                string: "http://outbound-dash.localhost:8764/clients/hvac?card=opportunity_identified"
            )
        )
        XCTAssertNil(VoiceMacroService.outboundDashURL(
            transcript: "Open outbound dash"
        ))
    }

    func testOpenGmailCommandIsExactAndGlobal() {
        XCTAssertEqual(
            VoiceMacroService.gmailURL(transcript: "Open Gmail."),
            URL(string: "https://mail.google.com/mail/u/0/#search/fdsafdsafdsafdsafdsafdsafdsa")
        )
        XCTAssertNil(VoiceMacroService.gmailURL(transcript: "Open my Gmail"))
    }

    func testGoogleSearchCommandUsesRawQueryAndIsGlobal() {
        XCTAssertEqual(
            VoiceMacroService.googleSearchURL(transcript: "Google Most realistic outbound voice agent."),
            URL(string: "https://www.google.com/search?q=Most%20realistic%20outbound%20voice%20agent")
        )
        XCTAssertNil(VoiceMacroService.googleSearchURL(transcript: "Google"))
        XCTAssertNil(VoiceMacroService.googleSearchURL(transcript: "Search Google for voice agents"))
    }

    func testChromeURLCommandResolvesClientDashboardAndIsAppScoped() {
        XCTAssertEqual(
            VoiceMacroService.chromeURL(
                transcript: "Open layers dash.",
                bundleID: "com.google.Chrome"
            ),
            "http://outbound-dash.localhost:8764/clients/layers?card=cannot_outreach"
        )
        XCTAssertEqual(
            VoiceMacroService.chromeURL(
                transcript: "open matchbook dash",
                bundleID: "com.google.Chrome"
            ),
            "http://outbound-dash.localhost:8764/clients/matchbook"
        )
        XCTAssertEqual(
            VoiceMacroService.chromeURL(
                transcript: "open commerce land dash",
                bundleID: "com.google.Chrome"
            ),
            "http://outbound-dash.localhost:8764/clients/commerce-land"
        )
        XCTAssertEqual(
            VoiceMacroService.chromeURL(
                transcript: "open or delin dash",
                bundleID: "com.google.Chrome"
            ),
            "http://outbound-dash.localhost:8764/clients/ordellan"
        )
        XCTAssertEqual(
            VoiceMacroService.chromeURL(
                transcript: "open h fact dash",
                bundleID: "com.google.Chrome"
            ),
            "http://outbound-dash.localhost:8764/clients/hvac?card=opportunity_identified"
        )
        XCTAssertNil(VoiceMacroService.chromeURL(
            transcript: "open layers dash",
            bundleID: "com.apple.Safari"
        ))
        XCTAssertNil(VoiceMacroService.chromeURL(
            transcript: "open another dashboard",
            bundleID: "com.google.Chrome"
        ))
    }

    func testFinderDeleteCommandIsExactAndAppScoped() {
        XCTAssertTrue(VoiceMacroService.isFinderDeleteCommand(
            transcript: "Delete.",
            bundleID: "com.apple.finder"
        ))
        XCTAssertFalse(VoiceMacroService.isFinderDeleteCommand(
            transcript: "delete this",
            bundleID: "com.apple.finder"
        ))
        XCTAssertFalse(VoiceMacroService.isFinderDeleteCommand(
            transcript: "delete",
            bundleID: "com.google.Chrome"
        ))
    }

    func testDeleteDesktopCommandIsExactAndAppIndependent() {
        XCTAssertTrue(VoiceMacroService.isDeleteDesktopCommand(
            transcript: "Delete desktop."
        ))
        XCTAssertTrue(VoiceMacroService.isDeleteDesktopCommand(
            transcript: "DELETE DESKTOP!"
        ))
        XCTAssertFalse(VoiceMacroService.isDeleteDesktopCommand(
            transcript: "delete the desktop"
        ))
        XCTAssertFalse(VoiceMacroService.isDeleteDesktopCommand(
            transcript: "delete desktop files"
        ))
    }

    func testCodexClearLineCommandAcceptsSpokenSlashAndIsAppScoped() {
        for transcript in ["Clear line.", "slash clear line", "/clear line"] {
            for bundleID in ["com.mitchellh.ghostty", "com.openai.codex"] {
                XCTAssertTrue(
                    VoiceMacroService.isCodexClearLineCommand(
                        transcript: transcript,
                        bundleID: bundleID
                    )
                )
            }
        }
        XCTAssertFalse(VoiceMacroService.isCodexClearLineCommand(
            transcript: "clear the line",
            bundleID: "com.openai.codex"
        ))
        XCTAssertFalse(VoiceMacroService.isCodexClearLineCommand(
            transcript: "clear line",
            bundleID: "com.apple.Terminal"
        ))
    }

    func testRestartFluidVoiceCommandIsExactAndGlobal() {
        XCTAssertTrue(VoiceMacroService.isRestartFluidVoiceCommand(
            transcript: "Restart Fluid Voice."
        ))
        XCTAssertFalse(VoiceMacroService.isRestartFluidVoiceCommand(
            transcript: "Please restart Fluid Voice"
        ))
    }

    func testCoreAudioFrameCountUsesActualBufferChannelLayout() {
        XCTAssertEqual(fv_core_audio_buffer_frame_count(512 * 4, 4, 1), 512)
        XCTAssertEqual(fv_core_audio_buffer_frame_count(512 * 8, 4, 2), 512)
        XCTAssertEqual(fv_core_audio_buffer_frame_count(512 * 12, 4, 3), 512)

        // Three non-interleaved buffers each contain one channel and must each
        // report 512 frames, never the 170-frame failure observed in the field.
        for _ in 0..<3 {
            XCTAssertEqual(fv_core_audio_buffer_frame_count(512 * 4, 4, 1), 512)
        }
    }

    func testDirectCaptureDurationMismatchFilter() {
        XCTAssertFalse(ASRService.directCaptureDurationIsMismatched(
            capturedMilliseconds: 100,
            elapsedMilliseconds: 499
        ))
        XCTAssertFalse(ASRService.directCaptureDurationIsMismatched(
            capturedMilliseconds: 460,
            elapsedMilliseconds: 500
        ))
        XCTAssertFalse(ASRService.directCaptureDurationIsMismatched(
            capturedMilliseconds: 700,
            elapsedMilliseconds: 1000
        ))
        XCTAssertFalse(ASRService.directCaptureDurationIsMismatched(
            capturedMilliseconds: 1300,
            elapsedMilliseconds: 1000
        ))
        XCTAssertTrue(ASRService.directCaptureDurationIsMismatched(
            capturedMilliseconds: 333,
            elapsedMilliseconds: 1000
        ))
        XCTAssertTrue(ASRService.directCaptureDurationIsMismatched(
            capturedMilliseconds: 1500,
            elapsedMilliseconds: 1000
        ))
        XCTAssertFalse(ASRService.directCaptureShouldDisable(afterFailureCount: 1))
        XCTAssertFalse(ASRService.directCaptureShouldDisable(afterFailureCount: 2))
        XCTAssertTrue(ASRService.directCaptureShouldDisable(afterFailureCount: 3))
        XCTAssertTrue(ASRService.directCaptureShouldDisable(afterFailureCount: 4))
    }

    func testLegacyKeyboardShortcutPayloadDefaultsToKeyboardKind() throws {
        let json = #"{"keyCode":61,"modifierFlagsRawValue":0}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        let shortcut = try JSONDecoder().decode(HotkeyShortcut.self, from: data)

        XCTAssertEqual(shortcut.kind, .keyboard)
        XCTAssertFalse(shortcut.isMouseShortcut)
        XCTAssertEqual(shortcut.keyCode, 61)
        XCTAssertTrue(shortcut.matches(keyCode: 61, modifiers: NSEvent.ModifierFlags()))
    }

    func testKeyboardPayloadIgnoresStrayMouseButtonField() throws {
        let json = #"{"kind":"keyboard","keyCode":0,"modifierFlagsRawValue":0,"mouseButton":3}"#
        let data = try XCTUnwrap(json.data(using: .utf8))

        let shortcut = try JSONDecoder().decode(HotkeyShortcut.self, from: data)

        XCTAssertFalse(shortcut.isMouseShortcut)
        XCTAssertEqual(shortcut.displayString, "A")
        XCTAssertFalse(shortcut.matchesMouse(button: 3, modifiers: NSEvent.ModifierFlags()))
    }

    func testMouseShortcutRoundTripsAndMatchesOnlyMouseEvents() throws {
        let shortcut = HotkeyShortcut(mouseButton: 3, modifierFlags: [.option])

        let data = try JSONEncoder().encode(shortcut)
        let decoded = try JSONDecoder().decode(HotkeyShortcut.self, from: data)

        XCTAssertEqual(decoded.kind, .mouse)
        XCTAssertTrue(decoded.isMouseShortcut)
        XCTAssertEqual(decoded.mouseButton, 3)
        XCTAssertTrue(decoded.matchesMouse(button: 3, modifiers: [.option]))
        XCTAssertFalse(decoded.matchesMouse(button: 3, modifiers: NSEvent.ModifierFlags()))
        XCTAssertFalse(decoded.matches(keyCode: 0, modifiers: [.option]))
    }

    func testUnmodifiedLeftAndRightClicksDoNotMatchMouseEvents() {
        let leftClick = HotkeyShortcut(mouseButton: 0, modifierFlags: NSEvent.ModifierFlags())
        let rightClick = HotkeyShortcut(mouseButton: 1, modifierFlags: NSEvent.ModifierFlags())
        let sideButton = HotkeyShortcut(mouseButton: 3, modifierFlags: NSEvent.ModifierFlags())
        let modifiedLeftClick = HotkeyShortcut(mouseButton: 0, modifierFlags: [.control])

        XCTAssertTrue(leftClick.isUnmodifiedLeftOrRightClick)
        XCTAssertTrue(rightClick.isUnmodifiedLeftOrRightClick)
        XCTAssertFalse(leftClick.matchesMouse(button: 0, modifiers: NSEvent.ModifierFlags()))
        XCTAssertFalse(rightClick.matchesMouse(button: 1, modifiers: NSEvent.ModifierFlags()))
        XCTAssertTrue(sideButton.matchesMouse(button: 3, modifiers: NSEvent.ModifierFlags()))
        XCTAssertTrue(modifiedLeftClick.matchesMouse(button: 0, modifiers: [.control]))
    }

    func testMouseShortcutDisplayIncludesModifiers() {
        let shortcut = HotkeyShortcut(mouseButton: 0, modifierFlags: [.control, .shift])

        XCTAssertEqual(shortcut.displayString, "⌃ + ⇧ + Left Click")
    }

    func testMouseShortcutDoesNotEqualKeyboardShortcutWithPlaceholderKeyCode() {
        let mouseShortcut = HotkeyShortcut(mouseButton: 3, modifierFlags: NSEvent.ModifierFlags())
        let keyboardShortcut = HotkeyShortcut(keyCode: 0, modifierFlags: NSEvent.ModifierFlags())

        XCTAssertEqual(mouseShortcut.displayString, "Mouse 4")
        XCTAssertNotEqual(mouseShortcut, keyboardShortcut)
    }

    func testModifiedMouseShortcutConflictsWithModifierOnlyShortcut() {
        let optionOnly = HotkeyShortcut(keyCode: 61, modifierFlags: [])
        let modifiedClick = HotkeyShortcut(mouseButton: 0, modifierFlags: [.option])
        let unmodifiedSideButton = HotkeyShortcut(mouseButton: 3, modifierFlags: [])

        XCTAssertTrue(modifiedClick.conflictsWith(optionOnly))
        XCTAssertTrue(optionOnly.conflictsWith(modifiedClick))
        XCTAssertFalse(unmodifiedSideButton.conflictsWith(optionOnly))
    }

    func testPrimaryDictationShortcutsFallbackToLegacyShortcut() throws {
        try self.withRestoredDefaults(keys: [self.legacyHotkeyShortcutKey, self.primaryDictationShortcutsKey]) {
            let legacyShortcut = HotkeyShortcut(keyCode: 12, modifierFlags: [.option])
            let data = try JSONEncoder().encode(legacyShortcut)
            UserDefaults.standard.set(data, forKey: self.legacyHotkeyShortcutKey)
            UserDefaults.standard.removeObject(forKey: self.primaryDictationShortcutsKey)

            XCTAssertEqual(SettingsStore.shared.primaryDictationShortcuts, [legacyShortcut])
            XCTAssertEqual(SettingsStore.shared.hotkeyShortcut, legacyShortcut)
        }
    }

    func testPrimaryDictationShortcutsPersistMultipleAndUpdateLegacyFirst() throws {
        try self.withRestoredDefaults(keys: [self.legacyHotkeyShortcutKey, self.primaryDictationShortcutsKey]) {
            let mouseShortcut = HotkeyShortcut(mouseButton: 3, modifierFlags: NSEvent.ModifierFlags())
            let keyboardShortcut = HotkeyShortcut(keyCode: 12, modifierFlags: [.option])

            SettingsStore.shared.primaryDictationShortcuts = [mouseShortcut, keyboardShortcut, mouseShortcut]

            XCTAssertEqual(SettingsStore.shared.primaryDictationShortcuts, [mouseShortcut, keyboardShortcut])
            XCTAssertEqual(SettingsStore.shared.hotkeyShortcut, mouseShortcut)
            XCTAssertEqual(
                SettingsStore.shared.primaryDictationShortcutDisplayString,
                "\(mouseShortcut.displayString) / \(keyboardShortcut.displayString)"
            )
        }
    }

    func testPasteLastTranscriptionShortcutDefaultsToUnboundAndDisabled() throws {
        try self.withRestoredDefaults(keys: [
            self.pasteLastTranscriptionShortcutKey,
            self.pasteLastTranscriptionEnabledKey,
        ]) {
            UserDefaults.standard.removeObject(forKey: self.pasteLastTranscriptionShortcutKey)
            UserDefaults.standard.removeObject(forKey: self.pasteLastTranscriptionEnabledKey)

            XCTAssertNil(SettingsStore.shared.pasteLastTranscriptionHotkeyShortcut)
            XCTAssertFalse(SettingsStore.shared.pasteLastTranscriptionShortcutEnabled)
        }
    }

    func testPasteLastTranscriptionShortcutPersistsAndClears() throws {
        try self.withRestoredDefaults(keys: [
            self.pasteLastTranscriptionShortcutKey,
            self.pasteLastTranscriptionEnabledKey,
        ]) {
            let shortcut = HotkeyShortcut(keyCode: 9, modifierFlags: [.command, .shift])
            SettingsStore.shared.pasteLastTranscriptionHotkeyShortcut = shortcut
            SettingsStore.shared.pasteLastTranscriptionShortcutEnabled = true

            XCTAssertEqual(SettingsStore.shared.pasteLastTranscriptionHotkeyShortcut, shortcut)
            XCTAssertTrue(SettingsStore.shared.pasteLastTranscriptionShortcutEnabled)

            // Removing the shortcut returns to the unbound state.
            SettingsStore.shared.pasteLastTranscriptionHotkeyShortcut = nil
            XCTAssertNil(SettingsStore.shared.pasteLastTranscriptionHotkeyShortcut)
        }
    }

    func testPasteLastTranscriptionShortcutSupportsMouseButton() throws {
        try self.withRestoredDefaults(keys: [self.pasteLastTranscriptionShortcutKey]) {
            let mouseShortcut = HotkeyShortcut(mouseButton: 3, modifierFlags: [.option])
            SettingsStore.shared.pasteLastTranscriptionHotkeyShortcut = mouseShortcut

            let stored = SettingsStore.shared.pasteLastTranscriptionHotkeyShortcut
            XCTAssertEqual(stored, mouseShortcut)
            XCTAssertTrue(stored?.isMouseShortcut ?? false)
            XCTAssertTrue(stored?.matchesMouse(button: 3, modifiers: [.option]) ?? false)
        }
    }

    private func withRestoredDefaults(keys: [String], run: () throws -> Void) rethrows {
        let defaults = UserDefaults.standard
        var snapshot: [String: Any] = [:]
        for key in keys {
            if let value = defaults.object(forKey: key) {
                snapshot[key] = value
            }
        }

        defer {
            for key in keys {
                if let previous = snapshot[key] {
                    defaults.set(previous, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }

        try run()
    }
}
