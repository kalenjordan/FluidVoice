import Foundation

/// Accessibility metadata captured for the control that owned focus when dictation began.
struct DictationFocusedControlContext: Equatable {
    let bundleID: String
    let role: String?
    let subrole: String?
    let title: String?
    let accessibilityDescription: String?
    let identifier: String?
    let help: String?
}

/// Field-specific exceptions layered on top of the existing app-level AI routing.
enum DictationAIFieldPolicy {
    static func allowsEnhancement(in context: DictationFocusedControlContext?) -> Bool {
        guard let context else { return true }
        return !self.isChromeAddressBar(context)
    }

    static func isChromeAddressBar(_ context: DictationFocusedControlContext) -> Bool {
        guard context.bundleID.caseInsensitiveCompare("com.google.Chrome") == .orderedSame else {
            return false
        }

        let values = [
            context.title,
            context.accessibilityDescription,
            context.identifier,
            context.help,
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        return values.contains { value in
            value == "address and search bar" ||
                value == "address bar" ||
                value == "location bar" ||
                value == "omnibox"
        }
    }
}

enum DictationEnhancementSuffix {
    static func strippingTrigger(from text: String) -> String? {
        let pattern = #"(?i)(?:^|\s)(?:polish|enhance)[\p{P}\p{S}]*\s*$"#
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }

        return String(text[..<range.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum DictationAutomaticSubmissionSuffix {
    static func strippingTrigger(from text: String) -> String? {
        let pattern = #"(?i)(?:[,;:]?\s+)(?:don['’]?t|do\s+not)\s+submit[.!?]*\s*$"#
        guard let range = text.range(of: pattern, options: .regularExpression) else { return nil }

        return String(text[..<range.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
