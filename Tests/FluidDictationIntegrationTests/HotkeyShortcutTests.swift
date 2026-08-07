import AppKit
@testable import FluidVoice_Debug
import Foundation
import XCTest

final class HotkeyShortcutTests: XCTestCase {
    private let legacyHotkeyShortcutKey = "HotkeyShortcutKey"
    private let primaryDictationShortcutsKey = "PrimaryDictationShortcuts"
    private let pasteLastTranscriptionShortcutKey = "PasteLastTranscriptionHotkeyShortcut"
    private let pasteLastTranscriptionEnabledKey = "PasteLastTranscriptionShortcutEnabled"

    @MainActor
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
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(transcript: "Herder comms."),
            "herdr comms."
        )
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(transcript: "Herdr, investigate the focus issue."),
            "herdr investigate the focus issue."
        )
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(transcript: "Herder."),
            "herdr"
        )
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(transcript: "Hurt her comms."),
            "herdr comms."
        )
        XCTAssertNil(VoiceMacroService.herdrWorkspaceQuery(
            transcript: "Terminal comms."
        ))
        XCTAssertNil(VoiceMacroService.herdrWorkspaceQuery(
            transcript: "Her name is Sarah",
            bundleID: "com.google.Chrome"
        ))
    }

    func testBareFrequentWorkspaceCommandsSupportTrailingPrompts() {
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(transcript: "ChatGPT."),
            "chatgpt"
        )
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(transcript: "Chat GPT."),
            "chatgpt"
        )
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(transcript: "Chat GBT."),
            "chatgpt"
        )
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(transcript: "Comms."),
            "comms"
        )
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(transcript: "Coms."),
            "comms"
        )
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(transcript: "Router."),
            "router"
        )
        XCTAssertNil(
            VoiceMacroService.herdrWorkspaceQuery(transcript: "Router is not the whole sentence")
        )
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(transcript: "FluidVoice."),
            "fluidvoice"
        )
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(transcript: "Fluid voice."),
            "fluidvoice"
        )
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(transcript: "NUDGES!"),
            "nudges"
        )
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(transcript: "Shopping."),
            "shopping"
        )
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(
                transcript: "Shopping, add paper towels"
            ),
            "shopping add paper towels"
        )
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(transcript: "Skills, add a release checklist"),
            "skills add a release checklist"
        )
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(transcript: "FluidVoice is working"),
            "fluidvoice is working"
        )
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(
                transcript: "Fluid Voice, investigate the focus issue."
            ),
            "fluidvoice investigate the focus issue."
        )
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(transcript: "Nudges are enabled"),
            "nudges are enabled"
        )
        XCTAssertNil(
            VoiceMacroService.herdrWorkspaceQuery(transcript: "SignalFlame Dash")
        )
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(
                transcript: "Edit Signal Flame, investigate the dashboard"
            ),
            "Signal Flame, investigate the dashboard"
        )
        XCTAssertNil(
            VoiceMacroService.herdrWorkspaceQuery(
                transcript: "Add a release checklist skills"
            )
        )
    }

    func testTrailingEditRoutesPrecedingPromptToWorkspace() {
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(
                transcript: "Investigate the dashboard, edit Signal Flame"
            ),
            "Signal Flame, Investigate the dashboard"
        )
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(
                transcript: "Add a release checklist edit skills."
            ),
            "skills, Add a release checklist"
        )
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(
                transcript: "Also, the reply is missing. Edit commerce leak."
            ),
            "commerce leak, Also, the reply is missing."
        )
    }

    func testEditChatGPTRoutesToWorkspace() {
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceQuery(transcript: "Edit ChatGPT."),
            "ChatGPT."
        )
    }

    func testTrailingEditWorkspaceMustConsumeTheEndOfTheTranscript() async {
        let conversationalResult = await VoiceMacroService.validatedHerdrWorkspaceQuery(
            transcript: "What if I just say edit router normally is it can always translate it"
        )
        let commandResult = await VoiceMacroService.validatedHerdrWorkspaceQuery(
            transcript: "Investigate the routing issue, edit router"
        )

        XCTAssertNil(conversationalResult)
        XCTAssertEqual(
            commandResult,
            "router, Investigate the routing issue"
        )
    }

    func testSpokenKeyMapperAliasResolvesLocalRepo() {
        let keyMapperRepo = URL(fileURLWithPath: "/Users/kalen/repos/keymapper")
        XCTAssertEqual(
            VoiceMacroService.resolveLocalRepoURL(
                query: "key mapper.",
                repoURLs: [keyMapperRepo]
            ),
            keyMapperRepo
        )
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

    func testBareChatGPTPrefersWorkspaceOverApplicationLaunch() {
        let chatGPT = URL(fileURLWithPath: "/Applications/ChatGPT.app")
        XCTAssertNil(VoiceMacroService.applicationLaunchQuery(
            transcript: "ChatGPT.",
            candidates: [chatGPT]
        ))
        XCTAssertNil(VoiceMacroService.applicationLaunchQuery(
            transcript: "Chat GBT.",
            candidates: [chatGPT]
        ))
        XCTAssertEqual(
            VoiceMacroService.applicationLaunchQuery(
                transcript: "Launch ChatGPT.",
                candidates: [chatGPT]
            ),
            "ChatGPT"
        )
    }

    func testRecordMeetingCommandLaunchesAnarlog() {
        XCTAssertEqual(
            VoiceMacroService.applicationLaunchQuery(transcript: "Record meeting."),
            "Anarlog"
        )
        XCTAssertNil(
            VoiceMacroService.applicationLaunchQuery(
                transcript: "Record meeting notes",
                candidates: []
            )
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
            VoiceMacroService.HerdrWorkspace(label: "yedric", workspaceID: "w6"),
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
        XCTAssertEqual(
            VoiceMacroService.resolveWorkspace(query: "or Delmon", workspaces: workspaces)?.workspaceID,
            "w5"
        )
        XCTAssertEqual(
            VoiceMacroService.resolveWorkspace(query: "Yedger", workspaces: workspaces)?.workspaceID,
            "w6"
        )
        XCTAssertEqual(
            VoiceMacroService.resolveWorkspace(query: "Yedrick", workspaces: workspaces)?.workspaceID,
            "w6"
        )
        XCTAssertNil(VoiceMacroService.resolveWorkspace(query: "commerce", workspaces: workspaces))

        XCTAssertNil(VoiceMacroService.resolveWorkspace(
            query: "commerce land",
            workspaces: [workspaces[3]]
        ))
    }

    func testLocalRepoResolutionSupportsCommerceLandDirectoryName() {
        let commerceLand = URL(fileURLWithPath: "/Users/kalen/repos/commerceland")
        let commerceLeak = URL(fileURLWithPath: "/Users/kalen/repos/commerce-leak")

        XCTAssertEqual(
            VoiceMacroService.resolveLocalRepoURL(
                query: "Commerce Land",
                repoURLs: [commerceLeak, commerceLand]
            ),
            commerceLand
        )
    }

    func testLocalRepoResolutionSupportsProjectSpeechAlias() {
        let ordellan = URL(fileURLWithPath: "/Users/kalen/repos/ordellan")

        XCTAssertEqual(
            VoiceMacroService.resolveLocalRepoURL(
                query: "or Delmon",
                repoURLs: [ordellan]
            ),
            ordellan
        )
    }

    func testLocalRepoResolutionSupportsUniqueTypoMatch() {
        let fluidvoice = URL(fileURLWithPath: "/Users/kalen/repos/fluidvoice")
        let comms = URL(fileURLWithPath: "/Users/kalen/repos/comms")

        XCTAssertEqual(
            VoiceMacroService.resolveLocalRepoURL(
                query: "fluidvoce",
                repoURLs: [comms, fluidvoice]
            ),
            fluidvoice
        )
    }

    func testLocalRepoResolutionRejectsAmbiguousTypoMatch() {
        let charted = URL(fileURLWithPath: "/Users/kalen/repos/charted")
        let charred = URL(fileURLWithPath: "/Users/kalen/repos/charred")

        XCTAssertNil(VoiceMacroService.resolveLocalRepoURL(
            query: "chared",
            repoURLs: [charted, charred]
        ))
    }

    func testCodexStatusCommandSupportsCommonRecognitionVariant() {
        XCTAssertTrue(VoiceMacroService.isCodexStatusCommand(transcript: "Codex status."))
        XCTAssertTrue(VoiceMacroService.isCodexStatusCommand(transcript: "Codec status"))
        XCTAssertTrue(VoiceMacroService.isCodexStatusCommand(transcript: "Codecs status"))
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

    func testTrailingPasteCommandReturnsPrecedingDictation() {
        XCTAssertEqual(
            VoiceMacroService.textBeforeTrailingPasteCommand(
                transcript: "Here is the context. Paste."
            ),
            "Here is the context."
        )
        XCTAssertEqual(
            VoiceMacroService.textBeforeTrailingPasteCommand(transcript: "Paste."),
            ""
        )
        XCTAssertEqual(
            VoiceMacroService.textBeforeTrailingPasteCommand(
                transcript: "Add this and PASTE! "
            ),
            "Add this and"
        )
        XCTAssertNil(VoiceMacroService.textBeforeTrailingPasteCommand(
            transcript: "paste that"
        ))
        XCTAssertNil(VoiceMacroService.textBeforeTrailingPasteCommand(
            transcript: "paste this in the middle of the sentence"
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

    func testHardRefreshCommandIsExactAndScopedToChrome() {
        XCTAssertTrue(VoiceMacroService.isChromeHardRefreshCommand(
            transcript: "Hard refresh.",
            bundleID: "com.google.Chrome"
        ))
        XCTAssertFalse(VoiceMacroService.isChromeHardRefreshCommand(
            transcript: "Hard refresh",
            bundleID: "com.apple.Safari"
        ))
        XCTAssertFalse(VoiceMacroService.isChromeHardRefreshCommand(
            transcript: "Refresh",
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

    func testSwitchCommandUsesExactPhrase() {
        XCTAssertTrue(VoiceMacroService.isSwitchCommand(transcript: "Switch."))
        XCTAssertFalse(VoiceMacroService.isSwitchCommand(transcript: "Back"))
        XCTAssertFalse(VoiceMacroService.isSwitchCommand(transcript: "Switch apps"))
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
        XCTAssertFalse(VoiceMacroService.isWindowMiddleCommand(
            transcript: "window middle all"
        ))
    }

    func testWindowMiddleAllCommandUsesExactPhrase() {
        XCTAssertTrue(VoiceMacroService.isWindowMiddleAllCommand(
            transcript: "Window middle all."
        ))
        XCTAssertTrue(VoiceMacroService.isWindowMiddleAllCommand(
            transcript: "WINDOW MIDDLE ALL!"
        ))
        XCTAssertTrue(VoiceMacroService.isWindowMiddleAllCommand(
            transcript: "All windows middle."
        ))
        XCTAssertFalse(VoiceMacroService.isWindowMiddleAllCommand(
            transcript: "window middle"
        ))
        XCTAssertFalse(VoiceMacroService.isWindowMiddleAllCommand(
            transcript: "middle all windows"
        ))
    }

    func testWindowMiddleFrameMatchesLargeChromeLayoutOnSelectedScreen() {
        let frame = VoiceMacroService.windowMiddleFrame(
            in: NSRect(x: 1440, y: -148, width: 1920, height: 1050),
            screenFrame: NSRect(x: 1440, y: -148, width: 1920, height: 1080)
        )

        XCTAssertEqual(frame, NSRect(x: 1836, y: -102, width: 1294, height: 901))
    }

    func testWindowMiddleFrameScalesProportionallyOnLaptopScreen() {
        let frame = VoiceMacroService.windowMiddleFrame(
            in: NSRect(x: 0, y: 0, width: 1440, height: 903),
            screenFrame: NSRect(x: 0, y: 0, width: 1440, height: 932)
        )

        XCTAssertEqual(frame.origin.x, 297, accuracy: 0.001)
        XCTAssertEqual(frame.origin.y, 150, accuracy: 0.001)
        XCTAssertEqual(frame.width, 970.5, accuracy: 0.001)
        XCTAssertEqual(frame.height, 675.75, accuracy: 0.001)
    }

    func testWindowMaxCommandUsesExactPhrase() {
        XCTAssertTrue(VoiceMacroService.isWindowMaxCommand(transcript: "Window max."))
        XCTAssertTrue(VoiceMacroService.isWindowMaxCommand(transcript: "WINDOW MAX!"))
        XCTAssertFalse(VoiceMacroService.isWindowMaxCommand(transcript: "maximize window"))
        XCTAssertFalse(VoiceMacroService.isWindowMaxCommand(transcript: "window maximum"))
        XCTAssertFalse(VoiceMacroService.isWindowMaxCommand(transcript: "window max all"))
    }

    func testWindowMaxAllCommandUsesExactPhrase() {
        XCTAssertTrue(VoiceMacroService.isWindowMaxAllCommand(transcript: "Window max all."))
        XCTAssertTrue(VoiceMacroService.isWindowMaxAllCommand(transcript: "WINDOW MAX ALL!"))
        XCTAssertTrue(VoiceMacroService.isWindowMaxAllCommand(transcript: "All windows max."))
        XCTAssertFalse(VoiceMacroService.isWindowMaxAllCommand(transcript: "window max"))
        XCTAssertFalse(VoiceMacroService.isWindowMaxAllCommand(transcript: "max all windows"))
    }

    func testWindowMaxFrameAppliesSharedMenuBarToExternalScreen() {
        let frame = VoiceMacroService.windowMaxFrame(
            screenFrame: NSRect(x: 1440, y: -148, width: 1920, height: 1080),
            primaryVisibleFrame: NSRect(x: 0, y: 0, width: 1440, height: 903)
        )

        XCTAssertEqual(frame, NSRect(x: 1440, y: -148, width: 1920, height: 1051))
    }

    func testWindowTopLeftFrameMatchesNetflixLayoutOnSelectedScreen() {
        let frame = VoiceMacroService.windowTopLeftFrame(
            in: NSRect(x: 1440, y: -148, width: 1920, height: 1080)
        )

        XCTAssertEqual(frame, NSRect(x: 1440, y: 557, width: 500, height: 375))
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

    func testHerdrWorkspaceNotificationsCommandMatchesExactState() {
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceNotificationsEnabledCommand(
                transcript: "Workspace notifications on."
            ),
            true
        )
        XCTAssertEqual(
            VoiceMacroService.herdrWorkspaceNotificationsEnabledCommand(
                transcript: "workspace notifications off"
            ),
            false
        )
        XCTAssertNil(
            VoiceMacroService.herdrWorkspaceNotificationsEnabledCommand(
                transcript: "toggle workspace notifications"
            )
        )
        XCTAssertNil(
            VoiceMacroService.herdrWorkspaceNotificationsEnabledCommand(
                transcript: "notifications on"
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
            transcript: "New tap."
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
        XCTAssertEqual(
            VoiceMacroService.newCodexTabPrompt(
                transcript: "Codex new tap, review the current changes."
            ),
            "review the current changes."
        )
        XCTAssertTrue(VoiceMacroService.isNewCodexTabCommand(
            transcript: "Investigate the focus issue. New tab."
        ))
        XCTAssertEqual(
            VoiceMacroService.newCodexTabPrompt(
                transcript: "Investigate the focus issue. New tab."
            ),
            "Investigate the focus issue."
        )
        XCTAssertEqual(
            VoiceMacroService.newCodexTabPrompt(
                transcript: "Review the current changes, Codex new tab."
            ),
            "Review the current changes"
        )
        XCTAssertEqual(
            VoiceMacroService.newCodexTabPrompt(
                transcript: "Investigate the focus issue new Codex tab"
            ),
            "Investigate the focus issue"
        )
        XCTAssertEqual(
            VoiceMacroService.newCodexTabPrompt(
                transcript: "Investigate the focus issue new tap"
            ),
            "Investigate the focus issue"
        )
        XCTAssertNil(VoiceMacroService.newCodexTabPrompt(transcript: "New tab."))
        XCTAssertFalse(VoiceMacroService.isNewCodexTabCommand(
            transcript: "Open a new Codex tab"
        ))
        XCTAssertFalse(VoiceMacroService.isNewCodexTabCommand(
            transcript: "Open a new tab and investigate the focus issue"
        ))
    }

    func testWritingWorkspaceCommandHandlesWriteHomophones() {
        XCTAssertTrue(VoiceMacroService.isWritingWorkspaceCommand(
            transcript: "Write."
        ))
        XCTAssertFalse(VoiceMacroService.isWritingWorkspaceCommand(
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
        XCTAssertEqual(VoiceMacroService.tabDirectionCommand(
            transcript: "Right",
            bundleID: "com.mitchellh.ghostty"
        ), .right)
        XCTAssertEqual(VoiceMacroService.tabDirectionCommand(
            transcript: "Left.",
            bundleID: "com.mitchellh.ghostty"
        ), .left)
        XCTAssertNil(VoiceMacroService.tabDirectionCommand(
            transcript: "Tab right",
            bundleID: "com.google.Chrome"
        ))
        XCTAssertNil(VoiceMacroService.tabDirectionCommand(
            transcript: "Right",
            bundleID: "com.google.Chrome"
        ))
    }

    func testBackCommandIsScopedToHerdrAndUsesExactPhrase() {
        XCTAssertTrue(VoiceMacroService.isBackCommand(
            transcript: "Back.",
            bundleID: "com.mitchellh.ghostty"
        ))
        XCTAssertFalse(VoiceMacroService.isBackCommand(
            transcript: "Go back",
            bundleID: "com.mitchellh.ghostty"
        ))
        XCTAssertFalse(VoiceMacroService.isBackCommand(
            transcript: "Back",
            bundleID: "com.google.Chrome"
        ))
    }

    func testRunHerdrCommandUsesExactPhrase() {
        XCTAssertTrue(VoiceMacroService.isRunHerdrCommand(transcript: "Run Herder."))
        XCTAssertTrue(VoiceMacroService.isRunHerdrCommand(transcript: "run herdr"))
        XCTAssertFalse(VoiceMacroService.isRunHerdrCommand(transcript: "run Herder now"))
    }

    func testRelaunchMainWindowSuppressionRequiresLaunchArgument() {
        XCTAssertTrue(AppRelauncher.shouldSuppressMainWindow(arguments: [
            "/Applications/FluidVoice.app/Contents/MacOS/FluidVoice",
            AppRelauncher.suppressMainWindowLaunchArgument,
        ]))
        XCTAssertFalse(AppRelauncher.shouldSuppressMainWindow(arguments: [
            "/Applications/FluidVoice.app/Contents/MacOS/FluidVoice",
            "-XCTest",
        ]))
    }

    func testXCTestHostDetectionProtectsLegacyRelaunchState() {
        XCTAssertTrue(AppRelauncher.isXCTestHost(environment: [
            "XCTestConfigurationFilePath": "/tmp/test.xctestconfiguration",
        ]))
        XCTAssertTrue(AppRelauncher.isXCTestHost(environment: [
            "XCTestBundlePath": "/tmp/FluidDictationIntegrationTests.xctest",
        ]))
        XCTAssertFalse(AppRelauncher.isXCTestHost(environment: [:]))
    }

    func testDetachCommandIsScopedToHerdr() {
        XCTAssertTrue(VoiceMacroService.isDetachHerdrCommand(
            transcript: "Detach.",
            bundleID: "com.mitchellh.ghostty"
        ))
        XCTAssertFalse(VoiceMacroService.isDetachHerdrCommand(
            transcript: "Detach",
            bundleID: "com.google.Chrome"
        ))
        XCTAssertFalse(VoiceMacroService.isDetachHerdrCommand(
            transcript: "Detach Herdr",
            bundleID: "com.mitchellh.ghostty"
        ))
    }

    func testCloseTabCommandIsScopedToHerdr() {
        XCTAssertTrue(VoiceMacroService.isCloseTabCommand(
            transcript: "Close tab.",
            bundleID: "com.mitchellh.ghostty"
        ))
        XCTAssertTrue(VoiceMacroService.isCloseTabCommand(
            transcript: "Close.",
            bundleID: "com.mitchellh.ghostty"
        ))
        XCTAssertFalse(VoiceMacroService.isCloseTabCommand(
            transcript: "Close tab",
            bundleID: "com.google.Chrome"
        ))
        XCTAssertFalse(VoiceMacroService.isCloseTabCommand(
            transcript: "Close",
            bundleID: "com.google.Chrome"
        ))
        XCTAssertFalse(VoiceMacroService.isCloseTabCommand(
            transcript: "Close the tab",
            bundleID: "com.mitchellh.ghostty"
        ))
    }

    func testCloseCommandClosesWorkspaceForItsOnlyTab() {
        XCTAssertEqual(
            VoiceMacroService.herdrCloseArguments(
                tabID: "w1:t1",
                workspaceID: "w1",
                tabCount: 1
            ),
            ["workspace", "close", "w1"]
        )
    }

    func testCloseCommandClosesTabWhenWorkspaceHasMultipleTabs() {
        XCTAssertEqual(
            VoiceMacroService.herdrCloseArguments(
                tabID: "w1:t2",
                workspaceID: "w1",
                tabCount: 2
            ),
            ["tab", "close", "w1:t2"]
        )
    }

    func testNextPendingCommandUsesExactPhrase() {
        XCTAssertTrue(VoiceMacroService.isNextPendingCommand(
            transcript: "Next."
        ))
        XCTAssertFalse(VoiceMacroService.isNextPendingCommand(
            transcript: "Next pending"
        ))
    }

    func testNextPendingTabRequiresAnUnfocusedDoneOrBlockedTab() {
        XCTAssertTrue(VoiceMacroService.hasNextPendingHerdrTab(statuses: [
            (agentStatus: "idle", focused: true),
            (agentStatus: "done", focused: false),
        ]))
        XCTAssertTrue(VoiceMacroService.hasNextPendingHerdrTab(statuses: [
            (agentStatus: "blocked", focused: false),
        ]))
        XCTAssertFalse(VoiceMacroService.hasNextPendingHerdrTab(statuses: [
            (agentStatus: "done", focused: true),
            (agentStatus: "working", focused: false),
        ]))
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

    func testCodexWeeklyStatusUsageFractionIsNormalized() {
        let reset = Date(timeIntervalSince1970: 1_800_000_000)

        func status(usedPercent: Double) -> VoiceMacroService.CodexWeeklyStatus {
            VoiceMacroService.CodexWeeklyStatus(
                usedPercent: usedPercent,
                windowDurationMinutes: 7 * 24 * 60,
                resetsAt: reset
            )
        }

        XCTAssertEqual(status(usedPercent: 42).usageFraction, 0.42, accuracy: 0.0001)
        XCTAssertEqual(status(usedPercent: -5).usageFraction, 0)
        XCTAssertEqual(status(usedPercent: 105).usageFraction, 1)
    }

    func testCodexWeeklyStatusPacingTracksElapsedDaysInWeek() {
        let reset = Date(timeIntervalSince1970: 1_800_000_000)
        let status = VoiceMacroService.CodexWeeklyStatus(
            usedPercent: 20,
            windowDurationMinutes: 7 * 24 * 60,
            resetsAt: reset
        )

        let dayOne = status.pacing(now: reset.addingTimeInterval(-6.5 * 24 * 60 * 60))
        XCTAssertEqual(dayOne.allowedUsageFraction, 1.0 / 7.0, accuracy: 0.0001)
        XCTAssertEqual(dayOne.elapsedDays, 1)
        XCTAssertEqual(dayOne.windowDays, 7)

        let dayFour = status.pacing(now: reset.addingTimeInterval(-3.5 * 24 * 60 * 60))
        XCTAssertEqual(dayFour.allowedUsageFraction, 4.0 / 7.0, accuracy: 0.0001)
        XCTAssertEqual(dayFour.elapsedDays, 4)
    }

    func testWorkspaceInvocationSeparatesWorkspaceFromTrailingDictation() {
        let workspaces = [
            VoiceMacroService.HerdrWorkspace(label: "herdr", workspaceID: "w1"),
            VoiceMacroService.HerdrWorkspace(label: "commerce-land", workspaceID: "w2"),
            VoiceMacroService.HerdrWorkspace(label: "skills", workspaceID: "w3"),
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
        XCTAssertEqual(
            VoiceMacroService.resolveWorkspaceInvocation(
                query: "skills",
                workspaces: workspaces
            ),
            VoiceMacroService.HerdrWorkspaceInvocation(
                workspace: workspaces[2],
                trailingText: nil
            )
        )
        XCTAssertEqual(
            VoiceMacroService.resolveWorkspaceInvocation(
                query: "skills, add a release checklist",
                workspaces: workspaces
            ),
            VoiceMacroService.HerdrWorkspaceInvocation(
                workspace: workspaces[2],
                trailingText: "add a release checklist"
            )
        )
    }

    func testCodexSessionUserMessageDetectionDistinguishesUnusedSessions() {
        let unusedSession = """
        {"type":"session_meta","payload":{"id":"session-1"}}
        {"type":"event_msg","payload":{"type":"token_count"}}
        """
        XCTAssertFalse(VoiceMacroService.codexSessionHasUserMessage(unusedSession))

        let usedSession = unusedSession + "\n"
            + #"{"type":"event_msg","payload":{"type":"user_message","message":"Hello"}}"#
        XCTAssertTrue(VoiceMacroService.codexSessionHasUserMessage(usedSession))
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
            URL(string: "http://outbound-dash.localhost:8764/")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Outbound Dash Old."),
            URL(string: "http://outbound-dash-legacy.localhost:8765/")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Signal Flame Dash Old."),
            URL(string: "http://outbound-dash-legacy.localhost:8765/clients/signalflame")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Outbound Farm Dash Old."),
            URL(string: "http://outbound-dash-legacy.localhost:8765/clients/outbound-farm")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Layers Dash Old."),
            URL(string: "http://outbound-dash-legacy.localhost:8765/clients/layers")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Commerce Leak Dash Old."),
            URL(string: "http://outbound-dash-legacy.localhost:8765/clients/commerce-leak")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "HVAC Dash Old."),
            URL(string: "http://outbound-dash-legacy.localhost:8765/clients/hvac")
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
        let liveSiteCommands = [
            ("Layers Live Site.", "https://uselayers.com"),
            ("SignalFlame Live Site.", "https://signalflame.net"),
            ("Signal Flame Live Site.", "https://signalflame.net"),
            ("HVAC Live Site.", "https://hvacbison.com"),
            ("HVAC Bison Live Site.", "https://hvacbison.com"),
            ("Commerce Leak Live Site.", "https://commerceleak.com"),
            ("Commerce Land Live Site.", "https://commerceland.app"),
            ("Commerceland Live Site.", "https://commerceland.app"),
            ("Ordellan Live Site.", "https://ordellan.com"),
            ("Matchbook Live Site.", "https://matchbook.chat"),
            ("Outbound Farm Live Site.", "https://outbound.farm"),
            ("ST3 Live Site.", "https://st3aero.com"),
            ("S T three Live Site.", "https://st3aero.com"),
            ("LinkedIn Live Site.", "https://www.linkedin.com"),
            ("LinkedIn CRM Live Site.", "https://www.linkedin.com"),
        ]
        for (transcript, expectedURL) in liveSiteCommands {
            XCTAssertEqual(
                VoiceMacroService.outboundDashURL(transcript: transcript),
                URL(string: expectedURL),
                transcript
            )
        }
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
            URL(string: "http://outbound-dash-v3.localhost:8766/clients/commerce-leak")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Commerce leaked Ash."),
            URL(string: "http://outbound-dash-v3.localhost:8766/clients/commerce-leak")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Outbound ash."),
            URL(string: "http://outbound-dash.localhost:8764/")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Outbound ash old."),
            URL(string: "http://outbound-dash-legacy.localhost:8765/")
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
            URL(string: "http://linkedin-crm.localhost:8772/")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "LinkedIn CRM."),
            URL(string: "http://linkedin-crm.localhost:8772/")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "LinkedIn Dash."),
            URL(string: "http://linkedin-crm.localhost:8772/")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "ST3 Dash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/st3aero")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "S T three dash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/st3aero")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "HVAC Dash."),
            URL(string: "http://outbound-dash-v3.localhost:8766/clients/hvac")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Layers Dash."),
            URL(string: "http://outbound-dash-v3.localhost:8766/clients/layers")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Insured Near Dash."),
            URL(string: "http://outbound-dash-v3.localhost:8766/clients/insured-near")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Outbound Farm Dash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/outbound-farm")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Outbound Farm Next Dash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/outbound-farm-next")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "Yedrick Dash."),
            URL(string: "http://outbound-dash.localhost:8764/clients/yedric")
        )
        XCTAssertEqual(
            VoiceMacroService.outboundDashURL(transcript: "H fact dash."),
            URL(string: "http://outbound-dash-v3.localhost:8766/clients/hvac")
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

    func testNetflixCommandIsExactAndGlobal() {
        XCTAssertTrue(VoiceMacroService.isNetflixCommand(transcript: "Netflix."))
        XCTAssertTrue(VoiceMacroService.isNetflixCommand(transcript: "NETFLIX!"))
        XCTAssertFalse(VoiceMacroService.isNetflixCommand(transcript: "Open Netflix"))
    }

    func testNetflixChromeScriptAlwaysCreatesANewWindow() {
        let script = VoiceMacroService.openNewChromeWindowScript(
            url: "https://www.netflix.com/"
        )

        XCTAssertTrue(script.contains("set chromeWindow to make new window"))
        XCTAssertTrue(script.contains(
            "set URL of active tab of chromeWindow to \"https://www.netflix.com/\""
        ))
        XCTAssertFalse(script.contains("make new tab"))
    }

    func testGoogleCalendarCommandIsExactAndGlobal() {
        XCTAssertEqual(
            VoiceMacroService.googleCalendarURL(transcript: "Google Calendar."),
            URL(string: "https://calendar.google.com/calendar/u/0/r")
        )
        XCTAssertNil(VoiceMacroService.googleCalendarURL(transcript: "Open Google Calendar"))
    }

    func testFinancesDashCommandIsExactAndGlobal() {
        XCTAssertEqual(
            VoiceMacroService.personalFinancesURL(transcript: "Finances dash."),
            URL(string: "http://finances.localhost:8000/app")
        )
        XCTAssertNil(VoiceMacroService.personalFinancesURL(transcript: "Personal finances"))
    }

    func testGoogleSearchCommandUsesRawQueryAndIsGlobal() {
        XCTAssertEqual(
            VoiceMacroService.googleSearchURL(transcript: "Google Most realistic outbound voice agent."),
            URL(string: "https://www.google.com/search?q=Most%20realistic%20outbound%20voice%20agent")
        )
        XCTAssertNil(VoiceMacroService.googleSearchURL(transcript: "Google"))
        XCTAssertNil(VoiceMacroService.googleSearchURL(transcript: "Search Google for voice agents"))
    }

    func testOpenOrFocusChromeURLReloadsAnExistingMatchingTab() {
        let script = VoiceMacroService.openOrFocusURLInChromeScript(
            baseURL: "https://matchbook.chat"
        )

        XCTAssertTrue(script.contains("reload tab tabIndex of chromeWindow"))
        XCTAssertEqual(script.components(separatedBy: "reload ").count - 1, 1)
        XCTAssertTrue(script.contains(
            "make new tab at end of tabs with properties {URL:\"https://matchbook.chat\"}"
        ))
    }

    func testChromeURLCommandResolvesClientDashboardAndIsAppScoped() {
        XCTAssertEqual(
            VoiceMacroService.chromeURL(
                transcript: "Open layers dash.",
                bundleID: "com.google.Chrome"
            ),
            "http://outbound-dash-v3.localhost:8766/clients/layers"
        )
        XCTAssertEqual(
            VoiceMacroService.chromeURL(
                transcript: "Open commerce leak dash.",
                bundleID: "com.google.Chrome"
            ),
            "http://outbound-dash-v3.localhost:8766/clients/commerce-leak"
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
            "http://outbound-dash-v3.localhost:8766/clients/hvac"
        )
        XCTAssertEqual(
            VoiceMacroService.chromeURL(
                transcript: "open outbound farm next dash",
                bundleID: "com.google.Chrome"
            ),
            "http://outbound-dash.localhost:8764/clients/outbound-farm-next"
        )
        XCTAssertEqual(
            VoiceMacroService.chromeURL(
                transcript: "open Yedrick dash",
                bundleID: "com.google.Chrome"
            ),
            "http://outbound-dash.localhost:8764/clients/yedric"
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

    func testCopyLastResultCommandRequiresExactPhrase() {
        XCTAssertTrue(VoiceMacroService.isCopyLastResultCommand(
            transcript: "Copy last result."
        ))
        XCTAssertTrue(VoiceMacroService.isCopyLastResultCommand(
            transcript: "Copy last action."
        ))
        XCTAssertFalse(VoiceMacroService.isCopyLastResultCommand(
            transcript: "Can you copy last result"
        ))
        XCTAssertFalse(VoiceMacroService.isCopyLastResultCommand(
            transcript: "copy the last action"
        ))
    }

    func testEnterCommandIsExactAndGlobal() {
        XCTAssertTrue(VoiceMacroService.isEnterCommand(
            transcript: "Enter."
        ))
        XCTAssertTrue(VoiceMacroService.isEnterCommand(
            transcript: "ENTER!"
        ))
        XCTAssertFalse(VoiceMacroService.isEnterCommand(
            transcript: "press enter"
        ))
        XCTAssertFalse(VoiceMacroService.isEnterCommand(
            transcript: "enter the room"
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

    func testAddMappingCommandExtractsReplacement() {
        XCTAssertEqual(
            VoiceMacroService.addMappingReplacement(transcript: "Add mapping for finances dash."),
            "finances dash"
        )
        XCTAssertEqual(
            VoiceMacroService.addMappingReplacement(transcript: "ADD MAPPING FOR Ordellin Dash!"),
            "Ordellin Dash"
        )
        XCTAssertEqual(
            VoiceMacroService.addMappingReplacement(transcript: "Ad mapping for finances dash."),
            "finances dash"
        )
        XCTAssertNil(VoiceMacroService.addMappingReplacement(transcript: "Add mapping"))
        XCTAssertNil(VoiceMacroService.addMappingReplacement(transcript: "Please add mapping for finances dash"))
    }

    func testMappingTriggerUsesLatestRawTranscriptionThatIsNotCommand() {
        let command = "Add mapping for finances dash."
        let entries = [
            TranscriptionHistoryEntry(
                rawText: command,
                processedText: command,
                appName: "Test",
                windowTitle: "",
                wasAIProcessed: false
            ),
            TranscriptionHistoryEntry(
                rawText: "Finance is dashed.",
                processedText: "Finance is dashed.",
                appName: "Test",
                windowTitle: "",
                wasAIProcessed: false
            ),
        ]

        XCTAssertEqual(
            VoiceMacroService.mappingTrigger(
                transcriptions: entries,
                actions: [],
                excluding: command
            ),
            "Finance is dashed."
        )
    }

    func testMappingTriggerFallsBackToLatestEntryWhenCommandIsNotStored() {
        let entries = [
            TranscriptionHistoryEntry(
                rawText: "Or Del and Dash?",
                processedText: "Or Del and Dash?",
                appName: "Test",
                windowTitle: "",
                wasAIProcessed: false
            ),
        ]

        XCTAssertEqual(
            VoiceMacroService.mappingTrigger(
                transcriptions: entries,
                actions: [],
                excluding: "Add mapping for Ordellin Dash"
            ),
            "Or Del and Dash?"
        )
    }

    func testMappingTriggerSelectsNewerVoiceAction() {
        let olderTranscription = TranscriptionHistoryEntry(
            timestamp: Date(timeIntervalSince1970: 100),
            rawText: "Some older dictation",
            processedText: "Some older dictation",
            appName: "Test",
            windowTitle: "",
            wasAIProcessed: false
        )
        let newerAction = RecentActionEntry(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 200),
            command: "Finance is dashed",
            succeeded: true,
            context: ""
        )

        XCTAssertEqual(
            VoiceMacroService.mappingTrigger(
                transcriptions: [olderTranscription],
                actions: [newerAction],
                excluding: "Add mapping for finances dash"
            ),
            "Finance is dashed"
        )
    }

    func testMappingTriggerSkipsPreviousMappingActions() {
        let mappingAction = RecentActionEntry(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 300),
            command: "Ad mapping for the wrong thing",
            succeeded: true,
            context: ""
        )
        let targetAction = RecentActionEntry(
            id: UUID(),
            timestamp: Date(timeIntervalSince1970: 200),
            command: "Or Del and Dash",
            succeeded: true,
            context: ""
        )

        XCTAssertEqual(
            VoiceMacroService.mappingTrigger(
                transcriptions: [],
                actions: [mappingAction, targetAction],
                excluding: "Add mapping for Ordellin Dash"
            ),
            "Or Del and Dash"
        )
    }

    func testAirPodsCommandsAreExactAndGlobal() {
        XCTAssertEqual(
            VoiceMacroService.airPodsCommand(transcript: "Connect AirPods."),
            .connect(.pro)
        )
        XCTAssertEqual(
            VoiceMacroService.airPodsCommand(transcript: "connect air pods"),
            .connect(.pro)
        )
        XCTAssertEqual(
            VoiceMacroService.airPodsCommand(transcript: "Disconnect AirPods!"),
            .disconnect(.pro)
        )
        XCTAssertEqual(
            VoiceMacroService.airPodsCommand(transcript: "Connect AirPods Max."),
            .connect(.max)
        )
        XCTAssertEqual(
            VoiceMacroService.airPodsCommand(transcript: "disconnect air pods max"),
            .disconnect(.max)
        )
        XCTAssertNil(VoiceMacroService.airPodsCommand(
            transcript: "Please connect AirPods"
        ))
    }

    func testPlayCommandIsExactAndGlobal() {
        XCTAssertTrue(VoiceMacroService.isPlayCommand(transcript: "Play."))
        XCTAssertTrue(VoiceMacroService.isPlayCommand(transcript: "PLAY!"))
        XCTAssertFalse(VoiceMacroService.isPlayCommand(transcript: "play music"))
        XCTAssertFalse(VoiceMacroService.isPlayCommand(transcript: "please play"))
    }

    func testAirPodsBatteryCommandIsExactAndGlobal() {
        for transcript in [
            "AirPods battery.", "air pods battery", "Check AirPods battery!",
            "check air pods battery",
        ] {
            XCTAssertTrue(VoiceMacroService.isAirPodsBatteryCommand(transcript: transcript))
        }
        XCTAssertFalse(VoiceMacroService.isAirPodsBatteryCommand(
            transcript: "Check AirPods Max battery"
        ))
    }

    func testAirPodsBatteryStatusParsesRegularAirPodsAndExcludesMax() throws {
        let json = """
        {
          "SPBluetoothDataType": [{
            "device_connected": [{
              "Kalen’s AirPods Max": {
                "device_address": "70:F9:4A:9D:98:BC",
                "device_batteryLevelLeft": "10%"
              }
            }],
            "device_not_connected": [{
              "Kalen’s AirPods Pro": {
                "device_address": "30:0E:43:33:94:9B",
                "device_batteryLevelCase": "92%",
                "device_batteryLevelLeft": "81%",
                "device_batteryLevelRight": "85%"
              }
            }]
          }]
        }
        """

        let status = VoiceMacroService.parseAirPodsBatteryStatus(from: Data(json.utf8))
        XCTAssertEqual(
            status,
            VoiceMacroService.AirPodsBatteryStatus(
                leftPercent: 81,
                rightPercent: 85,
                casePercent: 92
            )
        )
        XCTAssertEqual(status?.summary, "AirPods battery\nLeft 81% · Right 85% · Case 92%")
    }

    func testRestartCodexCommandIsExactAndHerdrScoped() {
        for transcript in [
            "Restart Codex.", "Restart codec", "Restart codecs",
            "Codex restart", "codec restart", "codecs restart",
        ] {
            XCTAssertTrue(VoiceMacroService.isRestartCodexCommand(
                transcript: transcript,
                bundleID: "com.mitchellh.ghostty"
            ))
        }
        XCTAssertFalse(VoiceMacroService.isRestartCodexCommand(
            transcript: "Please restart Codex",
            bundleID: "com.mitchellh.ghostty"
        ))
        XCTAssertFalse(VoiceMacroService.isRestartCodexCommand(
            transcript: "restart codex",
            bundleID: "com.openai.codex"
        ))
    }

    func testCodexReasoningCommandSupportsLowMediumAndHighInHerdr() {
        let bundleID = "com.mitchellh.ghostty"
        XCTAssertEqual(
            VoiceMacroService.codexReasoningLevelCommand(
                transcript: "Codex low.",
                bundleID: bundleID
            ),
            .low
        )
        XCTAssertEqual(
            VoiceMacroService.codexReasoningLevelCommand(
                transcript: "Codex medium.",
                bundleID: bundleID
            ),
            .medium
        )
        XCTAssertEqual(
            VoiceMacroService.codexReasoningLevelCommand(
                transcript: "Set codecs reasoning high",
                bundleID: bundleID
            ),
            .high
        )
        XCTAssertNil(VoiceMacroService.codexReasoningLevelCommand(
            transcript: "Codex minimal",
            bundleID: bundleID
        ))
        XCTAssertNil(VoiceMacroService.codexReasoningLevelCommand(
            transcript: "Codex high",
            bundleID: "com.openai.codex"
        ))
    }

    func testCodexReasoningShortcutAdjustmentUsesVisiblePaneStatus() {
        let paneText = """
        ╭─────────────────────────────────────────────────╮
        │ model:       gpt-5.6-sol low   /model to change │
        ╰─────────────────────────────────────────────────╯

          FluidVoice · gpt-5.6-sol high · Existing Thread
        """

        XCTAssertEqual(
            VoiceMacroService.codexReasoningShortcutAdjustment(
                paneText: paneText,
                requestedLevel: .medium
            ),
            -1
        )
        XCTAssertEqual(
            VoiceMacroService.codexReasoningShortcutAdjustment(
                paneText: paneText,
                requestedLevel: .high
            ),
            0
        )
    }

    func testCodexReasoningShortcutAdjustmentSupportsBrandNewPane() {
        let paneText = """
        │ model:       gpt-5.6-sol low   /model to change │
        │ directory:   ~/repos/FluidVoice                 │
        """

        XCTAssertEqual(
            VoiceMacroService.codexReasoningShortcutAdjustment(
                paneText: paneText,
                requestedLevel: .high
            ),
            2
        )
        XCTAssertNil(VoiceMacroService.codexReasoningShortcutAdjustment(
            paneText: "Codex is starting",
            requestedLevel: .low
        ))
    }

    func testCodexTabsLaunchWithPersistentShell() {
        XCTAssertEqual(
            VoiceMacroService.shellBackedCodexLaunchCommand,
            "zsh -il -c 'codex; exec zsh -il'"
        )
    }

    func testCodexResumeSessionIDParsesExitMessage() {
        let output = """
        Token usage: total=6,159 input=6,146 output=13
        To continue this session, run codex resume, then select General Testing Task (019fba37-bfea-7aa1-890a-d541c0f90e2f)
        """
        XCTAssertEqual(
            VoiceMacroService.newCodexResumeSessionID(beforeExit: "", afterExit: output),
            "019fba37-bfea-7aa1-890a-d541c0f90e2f"
        )
        XCTAssertNil(VoiceMacroService.newCodexResumeSessionID(
            beforeExit: output,
            afterExit: output + "\nBare Codex exited"
        ))
    }

    func testQuitApplicationCommandAcceptsExitOrQuitExactly() {
        for transcript in ["Exit.", "QUIT!", "  quit  "] {
            XCTAssertTrue(VoiceMacroService.isQuitApplicationCommand(
                transcript: transcript
            ))
        }
        XCTAssertFalse(VoiceMacroService.isQuitApplicationCommand(
            transcript: "quit application"
        ))
        XCTAssertFalse(VoiceMacroService.isQuitApplicationCommand(
            transcript: "please exit"
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
