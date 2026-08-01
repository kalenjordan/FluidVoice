import XCTest
@testable import FluidVoice_Debug

final class ClipboardServiceTests: XCTestCase {
    func testRecentActionTroubleshootingTextIncludesActionResultTimeAndContext() {
        let entry = RecentActionEntry(
            id: UUID(),
            timestamp: Date(timeIntervalSinceReferenceDate: 123_456),
            command: "Edit Fluid Voice",
            succeeded: false,
            context: """
            Target App: Ghostty
            Target Bundle ID: com.mitchellh.ghostty
            Workspace Query: Fluid Voice
            """
        )

        let text = entry.troubleshootingClipboardText

        XCTAssertTrue(text.hasPrefix("Voice Action Troubleshooting Context\n\n"))
        XCTAssertTrue(text.contains("Action: Edit Fluid Voice"))
        XCTAssertTrue(text.contains("Result: Failed"))
        XCTAssertTrue(text.contains("Time:"))
        XCTAssertTrue(text.contains("Target App: Ghostty"))
        XCTAssertTrue(text.contains("Target Bundle ID: com.mitchellh.ghostty"))
        XCTAssertTrue(text.contains("Workspace Query: Fluid Voice"))
    }

    func testAppendingClipboardTextAddsItAfterTwoNewlines() {
        XCTAssertEqual(
            ClipboardService.appending(
                clipboardText: "Copied context",
                to: "Here is the context:"
            ),
            "Here is the context:\n\nCopied context"
        )
    }

    func testAppendingClipboardTextUsesClipboardWhenSpeechIsEmpty() {
        XCTAssertEqual(
            ClipboardService.appending(clipboardText: "Copied context", to: " \n"),
            "Copied context"
        )
    }

    func testAppendingClipboardTextPreservesWhitespace() {
        XCTAssertEqual(
            ClipboardService.appending(
                clipboardText: "first line\nsecond\tline",
                to: "Use this:"
            ),
            "Use this:\n\nfirst line\nsecond\tline"
        )
    }

    func testAppendingMissingClipboardTextLeavesSpeechUnchanged() {
        XCTAssertEqual(
            ClipboardService.appending(clipboardText: nil, to: "Spoken text"),
            "Spoken text"
        )
    }
}
