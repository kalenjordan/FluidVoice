import AppKit

enum AppRelauncher {
    static let suppressMainWindowLaunchArgument = "--fluidvoice-suppress-main-window"
    static let legacySuppressMainWindowOnNextLaunchKey = "SuppressMainWindowOnNextLaunch"

    private static let waitForExitScript = """
    while kill -0 "$1" 2>/dev/null; do
        sleep 0.1
    done
    exec /usr/bin/open -n "$2" --args "$3"
    """

    static func shouldSuppressMainWindow(arguments: [String]) -> Bool {
        arguments.contains(self.suppressMainWindowLaunchArgument)
    }

    static func isXCTestHost(environment: [String: String]) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil
            || environment["XCTestBundlePath"] != nil
    }

    @MainActor
    static func restartCurrentApp() -> Bool {
        let appPath = Bundle.main.bundlePath
        guard FileManager.default.fileExists(atPath: appPath) else {
            DebugLogger.shared.error(
                "Could not restart because the app bundle is missing: \(appPath)",
                source: "AppRelauncher"
            )
            return false
        }

        NotificationService.showAppRestarting {
            Task { @MainActor in
                self.launchRelaunchHelper(appPath: appPath)
            }
        }
        return true
    }

    @MainActor
    private static func launchRelaunchHelper(appPath: String) {
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = [
            "-c",
            self.waitForExitScript,
            "fluidvoice-relauncher",
            String(ProcessInfo.processInfo.processIdentifier),
            appPath,
            self.suppressMainWindowLaunchArgument,
        ]

        do {
            try helper.run()
            DebugLogger.shared.info(
                "Relaunch helper started; terminating current instance before opening replacement",
                source: "AppRelauncher"
            )
            NSApp.terminate(nil)
        } catch {
            DebugLogger.shared.error(
                "Could not start relaunch helper: \(error.localizedDescription)",
                source: "AppRelauncher"
            )
        }
    }
}
