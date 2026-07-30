import AppKit
import CoreGraphics
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers

enum WindowScreenshotService {
    enum CaptureError: LocalizedError {
        case permissionRequired
        case windowNotFound
        case desktopUnavailable
        case saveFailed

        var errorDescription: String? {
            switch self {
            case .permissionRequired:
                return "Allow Screen & System Audio Recording for FluidVoice, then try again."
            case .windowNotFound:
                return "Could not find the selected window."
            case .desktopUnavailable:
                return "Could not access the Desktop."
            case .saveFailed:
                return "Could not save the window screenshot."
            }
        }
    }

    @MainActor
    static func captureSelectedWindow(targetPID: pid_t) async throws -> URL {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw CaptureError.permissionRequired
        }

        let windowID = try self.frontmostWindowID(for: targetPID)
        let shareableContent = try await SCShareableContent.excludingDesktopWindows(
            true,
            onScreenWindowsOnly: true
        )
        guard let window = shareableContent.windows.first(where: {
            $0.windowID == windowID
        }) else {
            throw CaptureError.windowNotFound
        }

        let configuration = SCStreamConfiguration()
        let scale = self.backingScale(for: window.frame)
        configuration.width = Int(window.frame.width * scale)
        configuration.height = Int(window.frame.height * scale)
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: configuration
        )
        let destinationURL = try self.destinationURL()
        try self.writePNG(image, to: destinationURL)
        return destinationURL
    }

    private static func frontmostWindowID(for targetPID: pid_t) throws -> CGWindowID {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(
            options,
            kCGNullWindowID
        ) as? [[String: Any]] else {
            throw CaptureError.windowNotFound
        }

        for window in windows {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == targetPID,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let windowID = window[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let width = bounds["Width"] as? CGFloat,
                  let height = bounds["Height"] as? CGFloat,
                  width > 1,
                  height > 1
            else {
                continue
            }
            return windowID
        }
        throw CaptureError.windowNotFound
    }

    @MainActor
    private static func backingScale(for windowFrame: CGRect) -> CGFloat {
        NSScreen.screens.first(where: { $0.frame.intersects(windowFrame) })?
            .backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }

    private static func destinationURL() throws -> URL {
        guard let desktop = FileManager.default.urls(
            for: .desktopDirectory,
            in: .userDomainMask
        ).first else {
            throw CaptureError.desktopUnavailable
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let basename = "Screenshot \(formatter.string(from: Date()))"
        var destination = desktop.appendingPathComponent(
            "\(basename).png",
            isDirectory: false
        )
        var suffix = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = desktop.appendingPathComponent(
                "\(basename) \(suffix).png",
                isDirectory: false
            )
            suffix += 1
        }
        return destination
    }

    private static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw CaptureError.saveFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CaptureError.saveFailed
        }
    }
}
