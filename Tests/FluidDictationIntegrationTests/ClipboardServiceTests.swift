import XCTest
@testable import FluidVoice_Debug

final class ClipboardServiceTests: XCTestCase {
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

    func testAppendingClipboardTextFlattensWhitespace() {
        XCTAssertEqual(
            ClipboardService.appending(
                clipboardText: "first line\nsecond\tline",
                to: "Use this:"
            ),
            "Use this:\n\nfirst line second line"
        )
    }

    func testAppendingMissingClipboardTextLeavesSpeechUnchanged() {
        XCTAssertEqual(
            ClipboardService.appending(clipboardText: nil, to: "Spoken text"),
            "Spoken text"
        )
    }
}
