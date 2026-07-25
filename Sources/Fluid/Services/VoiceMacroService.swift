import AppKit
import Carbon.HIToolbox
import Foundation

enum VoiceMacroService {
    private static let openCommsPhrase = "open comms"
    private static let herdrBundleIDs = ["com.mitchellh.ghostty"]
    private static let herdrAppNames = ["ghostty", "herdr"]

    static func matchesOpenComms(
        transcript: String,
        appName: String,
        bundleID: String,
        windowTitle: String
    ) -> Bool {
        guard self.normalizedPhrase(transcript) == self.openCommsPhrase else { return false }

        let normalizedAppName = appName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedBundleID = bundleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedWindowTitle = windowTitle.lowercased()

        return self.herdrBundleIDs.contains(normalizedBundleID)
            || self.herdrAppNames.contains(normalizedAppName)
            || normalizedWindowTitle.contains("herdr")
    }

    @MainActor
    static func runOpenComms(targetPID: pid_t) async -> Bool {
        guard self.isTargetFrontmost(targetPID) else { return false }
        guard self.postKey(CGKeyCode(kVK_ANSI_K), flags: .maskCommand, to: targetPID) else { return false }

        try? await Task.sleep(nanoseconds: 150_000_000)
        guard self.isTargetFrontmost(targetPID) else { return false }
        guard self.postText("COMMS", to: targetPID) else { return false }

        try? await Task.sleep(nanoseconds: 100_000_000)
        guard self.isTargetFrontmost(targetPID) else { return false }
        return self.postKey(CGKeyCode(kVK_Return), to: targetPID)
    }

    private static func normalizedPhrase(_ transcript: String) -> String {
        let lowercased = transcript.lowercased()
        let words = lowercased.split { character in
            character.isWhitespace || character.isPunctuation
        }
        return words.joined(separator: " ")
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
