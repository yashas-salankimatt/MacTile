import Foundation
import AppKit

/// Handles sketchybar integration setup, file deployment, and service management
class SketchybarIntegration {
    static let shared = SketchybarIntegration()

    private let fileManager = FileManager.default

    /// Sketchybar config directory
    private var sketchybarConfigDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/sketchybar")
    }

    /// Plugins directory
    private var pluginsDir: URL {
        sketchybarConfigDir.appendingPathComponent("plugins")
    }

    /// Helpers directory
    private var helpersDir: URL {
        sketchybarConfigDir.appendingPathComponent("helpers")
    }

    /// User fonts directory
    private var userFontsDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Fonts")
    }

    /// sketchybarrc path
    private var sketchybarrcPath: URL {
        sketchybarConfigDir.appendingPathComponent("sketchybarrc")
    }

    /// MacTile plugin files to deploy
    private let mactilePluginFiles = [
        "mactile.sh",
        "mactile_click.sh",
        "mactile_space_name.sh"
    ]

    /// Basic plugin files to deploy (only if they don't exist)
    private let basicPluginFiles = [
        "front_app.sh",
        "clock.sh"
    ]

    private init() {}

    // MARK: - Public Methods

    /// Enable sketchybar integration
    /// - Returns: Result indicating success or error message
    func enableIntegration() -> Result<Void, IntegrationError> {
        print("[SketchybarIntegration] Enabling integration...")

        // 1. Create directories if needed
        do {
            try createDirectoriesIfNeeded()
        } catch {
            return .failure(.directoryCreationFailed(error.localizedDescription))
        }

        // 2. Deploy MacTile plugin scripts
        do {
            try deployPluginScripts()
        } catch {
            return .failure(.pluginDeploymentFailed(error.localizedDescription))
        }

        // 3. Deploy helper scripts (icon_map.sh)
        do {
            try deployHelperScripts()
        } catch {
            print("[SketchybarIntegration] Warning: Failed to deploy helpers: \(error)")
            // Non-fatal - continue without helpers
        }

        // 4. Install font if needed
        do {
            try installFontIfNeeded()
        } catch {
            print("[SketchybarIntegration] Warning: Failed to install font: \(error)")
            // Non-fatal - continue without font
        }

        // 5. Check/deploy sketchybarrc
        let sketchybarrcResult = handleSketchybarrc()

        // 6. Restart sketchybar
        restartSketchybar()

        return sketchybarrcResult
    }

    /// Disable sketchybar integration
    func disableIntegration() {
        print("[SketchybarIntegration] Disabling integration...")
        // Just restart sketchybar to reload config
        restartSketchybar()
    }

    /// Check if sketchybarrc is configured for MacTile
    func isSketchybarrcConfigured() -> Bool {
        guard fileManager.fileExists(atPath: sketchybarrcPath.path) else {
            return false
        }

        do {
            let content = try String(contentsOf: sketchybarrcPath, encoding: .utf8)
            // Check for the MacTile event registration
            return content.contains("mactile_space_change")
        } catch {
            return false
        }
    }

    // MARK: - Private Methods

    private func createDirectoriesIfNeeded() throws {
        // Create .config/sketchybar if it doesn't exist
        if !fileManager.fileExists(atPath: sketchybarConfigDir.path) {
            try fileManager.createDirectory(at: sketchybarConfigDir, withIntermediateDirectories: true)
        }

        // Create plugins directory if it doesn't exist
        if !fileManager.fileExists(atPath: pluginsDir.path) {
            try fileManager.createDirectory(at: pluginsDir, withIntermediateDirectories: true)
        }
    }

    private func deployPluginScripts() throws {
        // Get the bundle resource URL for plugins
        guard let pluginsResourceURL = Bundle.main.resourceURL?.appendingPathComponent("plugins") else {
            throw IntegrationError.resourceNotFound("plugins directory")
        }

        print("[SketchybarIntegration] Looking for plugins at: \(pluginsResourceURL.path)")

        // Deploy MacTile plugins (always overwrite to ensure latest version)
        for filename in mactilePluginFiles {
            let sourceURL = pluginsResourceURL.appendingPathComponent(filename)
            let destURL = pluginsDir.appendingPathComponent(filename)

            if fileManager.fileExists(atPath: sourceURL.path) {
                // Remove existing file first
                if fileManager.fileExists(atPath: destURL.path) {
                    try fileManager.removeItem(at: destURL)
                }
                try fileManager.copyItem(at: sourceURL, to: destURL)
                // Make executable
                try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destURL.path)
                print("[SketchybarIntegration] Deployed: \(filename)")
            } else {
                print("[SketchybarIntegration] Warning: Plugin not found in bundle: \(filename)")
            }
        }

        // Deploy basic plugins only if they don't exist
        for filename in basicPluginFiles {
            let sourceURL = pluginsResourceURL.appendingPathComponent(filename)
            let destURL = pluginsDir.appendingPathComponent(filename)

            if !fileManager.fileExists(atPath: destURL.path) {
                if fileManager.fileExists(atPath: sourceURL.path) {
                    try fileManager.copyItem(at: sourceURL, to: destURL)
                    try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: destURL.path)
                    print("[SketchybarIntegration] Deployed basic plugin: \(filename)")
                }
            }
        }
    }

    private func deployHelperScripts() throws {
        // Create helpers directory if it doesn't exist
        if !fileManager.fileExists(atPath: helpersDir.path) {
            try fileManager.createDirectory(at: helpersDir, withIntermediateDirectories: true)
        }

        // Get the bundle resource URL for helpers
        guard let helpersResourceURL = Bundle.main.resourceURL?.appendingPathComponent("helpers") else {
            print("[SketchybarIntegration] Helpers directory not found in bundle")
            return
        }

        // Deploy icon_map.sh (always overwrite to ensure latest version)
        let iconMapSource = helpersResourceURL.appendingPathComponent("icon_map.sh")
        let iconMapDest = helpersDir.appendingPathComponent("icon_map.sh")

        if fileManager.fileExists(atPath: iconMapSource.path) {
            if fileManager.fileExists(atPath: iconMapDest.path) {
                try fileManager.removeItem(at: iconMapDest)
            }
            try fileManager.copyItem(at: iconMapSource, to: iconMapDest)
            try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: iconMapDest.path)
            print("[SketchybarIntegration] Deployed: icon_map.sh")
        } else {
            print("[SketchybarIntegration] Warning: icon_map.sh not found in bundle")
        }
    }

    private func installFontIfNeeded() throws {
        let fontName = "sketchybar-app-font.ttf"
        let fontDestPath = userFontsDir.appendingPathComponent(fontName)

        // Check if font is already installed
        if fileManager.fileExists(atPath: fontDestPath.path) {
            print("[SketchybarIntegration] Font already installed: \(fontName)")
            return
        }

        // Get the bundle resource URL for fonts
        guard let fontsResourceURL = Bundle.main.resourceURL?.appendingPathComponent("fonts") else {
            print("[SketchybarIntegration] Fonts directory not found in bundle")
            return
        }

        let fontSourcePath = fontsResourceURL.appendingPathComponent(fontName)

        if fileManager.fileExists(atPath: fontSourcePath.path) {
            // Create Fonts directory if it doesn't exist (unlikely but just in case)
            if !fileManager.fileExists(atPath: userFontsDir.path) {
                try fileManager.createDirectory(at: userFontsDir, withIntermediateDirectories: true)
            }

            try fileManager.copyItem(at: fontSourcePath, to: fontDestPath)
            print("[SketchybarIntegration] Installed font: \(fontName)")
            print("[SketchybarIntegration] Note: You may need to restart applications to use the new font")
        } else {
            print("[SketchybarIntegration] Warning: Font not found in bundle: \(fontName)")
        }
    }

    private func handleSketchybarrc() -> Result<Void, IntegrationError> {
        if fileManager.fileExists(atPath: sketchybarrcPath.path) {
            // sketchybarrc exists - check if configured
            if isSketchybarrcConfigured() {
                print("[SketchybarIntegration] sketchybarrc already configured for MacTile")
                return .success(())
            } else {
                print("[SketchybarIntegration] sketchybarrc exists but not configured for MacTile")
                return .failure(.sketchybarrcNotConfigured)
            }
        } else {
            // sketchybarrc doesn't exist - deploy our template
            guard let sketchybarrcResourceURL = Bundle.main.resourceURL?.appendingPathComponent("sketchybarrc") else {
                return .failure(.resourceNotFound("sketchybarrc"))
            }

            do {
                if fileManager.fileExists(atPath: sketchybarrcResourceURL.path) {
                    try fileManager.copyItem(at: sketchybarrcResourceURL, to: sketchybarrcPath)
                    try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: sketchybarrcPath.path)
                    print("[SketchybarIntegration] Deployed sketchybarrc template")
                    return .success(())
                } else {
                    return .failure(.resourceNotFound("sketchybarrc template"))
                }
            } catch {
                return .failure(.sketchybarrcDeploymentFailed(error.localizedDescription))
            }
        }
    }

    private func restartSketchybar() {
        print("[SketchybarIntegration] Restarting sketchybar...")

        DispatchQueue.global(qos: .utility).async {
            // Try brew services first
            let stopProcess = Process()
            stopProcess.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
            stopProcess.arguments = ["services", "stop", "sketchybar"]
            stopProcess.standardOutput = FileHandle.nullDevice
            stopProcess.standardError = FileHandle.nullDevice

            do {
                try stopProcess.run()
                stopProcess.waitUntilExit()
            } catch {
                // Try /usr/local/bin/brew for Intel Macs
                let intelStopProcess = Process()
                intelStopProcess.executableURL = URL(fileURLWithPath: "/usr/local/bin/brew")
                intelStopProcess.arguments = ["services", "stop", "sketchybar"]
                intelStopProcess.standardOutput = FileHandle.nullDevice
                intelStopProcess.standardError = FileHandle.nullDevice
                try? intelStopProcess.run()
                intelStopProcess.waitUntilExit()
            }

            // Small delay before starting
            Thread.sleep(forTimeInterval: 0.5)

            let startProcess = Process()
            startProcess.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
            startProcess.arguments = ["services", "start", "sketchybar"]
            startProcess.standardOutput = FileHandle.nullDevice
            startProcess.standardError = FileHandle.nullDevice

            do {
                try startProcess.run()
                startProcess.waitUntilExit()
                print("[SketchybarIntegration] Sketchybar restarted via brew services")
            } catch {
                // Try /usr/local/bin/brew for Intel Macs
                let intelStartProcess = Process()
                intelStartProcess.executableURL = URL(fileURLWithPath: "/usr/local/bin/brew")
                intelStartProcess.arguments = ["services", "start", "sketchybar"]
                intelStartProcess.standardOutput = FileHandle.nullDevice
                intelStartProcess.standardError = FileHandle.nullDevice
                try? intelStartProcess.run()
                intelStartProcess.waitUntilExit()
            }
        }
    }

    // MARK: - Error Types

    enum IntegrationError: Error {
        case directoryCreationFailed(String)
        case pluginDeploymentFailed(String)
        case resourceNotFound(String)
        case sketchybarrcNotConfigured
        case sketchybarrcDeploymentFailed(String)

        var localizedDescription: String {
            switch self {
            case .directoryCreationFailed(let msg):
                return "Failed to create directories: \(msg)"
            case .pluginDeploymentFailed(let msg):
                return "Failed to deploy plugins: \(msg)"
            case .resourceNotFound(let resource):
                return "Resource not found: \(resource)"
            case .sketchybarrcNotConfigured:
                return "sketchybarrc exists but is not configured for MacTile"
            case .sketchybarrcDeploymentFailed(let msg):
                return "Failed to deploy sketchybarrc: \(msg)"
            }
        }
    }
}

// MARK: - Modal Helpers

extension SketchybarIntegration {
    /// Show a modal explaining that sketchybarrc needs manual configuration
    func showConfigurationRequiredAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Sketchybar Configuration Required"
            alert.informativeText = """
            Your existing sketchybarrc file doesn't contain the MacTile configuration.

            MacTile's plugin scripts have been installed to:
            ~/.config/sketchybar/plugins/

            To complete the setup, you need to add the MacTile sections to your sketchybarrc.

            Please check the MacTile GitHub repository for configuration instructions, or copy the relevant sections from:
            ~/.config/sketchybar/sketchybarrc.mactile-example

            After updating your config, restart sketchybar with:
            brew services restart sketchybar
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open GitHub")
            alert.addButton(withTitle: "OK")

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                // Open GitHub page
                if let url = URL(string: "https://github.com/your-repo/MacTile#sketchybar-integration") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    /// Deploy an example sketchybarrc alongside the user's existing one
    func deployExampleSketchybarrc() {
        let examplePath = sketchybarConfigDir.appendingPathComponent("sketchybarrc.mactile-example")

        guard let sketchybarrcResourceURL = Bundle.main.resourceURL?.appendingPathComponent("sketchybarrc") else {
            return
        }

        do {
            if fileManager.fileExists(atPath: examplePath.path) {
                try fileManager.removeItem(at: examplePath)
            }
            if fileManager.fileExists(atPath: sketchybarrcResourceURL.path) {
                try fileManager.copyItem(at: sketchybarrcResourceURL, to: examplePath)
                print("[SketchybarIntegration] Deployed example config: sketchybarrc.mactile-example")
            }
        } catch {
            print("[SketchybarIntegration] Failed to deploy example config: \(error)")
        }
    }
}
