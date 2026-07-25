import XCTest
@testable import FluidVoice_Debug

final class ClipboardServiceTests: XCTestCase {
    func testAppendingClipboardTextAddsItAfterSpokenText() {
        XCTAssertEqual(
            ClipboardService.appending(
                clipboardText: "Copied context",
                to: "Here is the context:"
            ),
            "Here is the context: Copied context"
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
            "Use this: first line second line"
        )
    }

    func testAppendingMissingClipboardTextLeavesSpeechUnchanged() {
        XCTAssertEqual(
            ClipboardService.appending(clipboardText: nil, to: "Spoken text"),
            "Spoken text"
        )
    }
}
