import Foundation
import MacTileCore

/// Manages persistence and access to MacTile settings
class SettingsManager {
    static let shared = SettingsManager()

    private let userDefaults = UserDefaults.standard
    private let settingsKey = "MacTileSettings"

    /// Current settings (cached in memory)
    private(set) var settings: MacTileSettings {
        didSet {
            saveSettings()
            NotificationCenter.default.post(name: .settingsDidChange, object: self)
        }
    }

    private init() {
        settings = Self.loadSettings() ?? .default
    }

    // MARK: - Persistence

    private static func loadSettings() -> MacTileSettings? {
        guard let data = UserDefaults.standard.data(forKey: "MacTileSettings") else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(MacTileSettings.self, from: data)
        } catch {
            print("Failed to decode settings: \(error)")
            return nil
        }
    }

    private func saveSettings() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(settings)
            userDefaults.set(data, forKey: settingsKey)
        } catch {
            print("Failed to encode settings: \(error)")
        }
    }

    // MARK: - Update Methods

    func updateSettings(_ newSettings: MacTileSettings) {
        settings = newSettings
    }

    func updateGridSizes(_ sizes: [GridSize]) {
        var newSettings = settings
        newSettings = MacTileSettings(
            gridSizes: sizes,
            windowSpacing: settings.windowSpacing,
            insets: settings.insets,
            autoClose: settings.autoClose,
            showMenuBarIcon: settings.showMenuBarIcon,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            overlayKeyboard: settings.overlayKeyboard,
            appearance: settings.appearance
        )
        settings = newSettings
    }

    func updateWindowSpacing(_ spacing: CGFloat) {
        settings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: spacing,
            insets: settings.insets,
            autoClose: settings.autoClose,
            showMenuBarIcon: settings.showMenuBarIcon,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            overlayKeyboard: settings.overlayKeyboard,
            appearance: settings.appearance
        )
    }

    func updateInsets(_ insets: EdgeInsets) {
        settings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: settings.windowSpacing,
            insets: insets,
            autoClose: settings.autoClose,
            showMenuBarIcon: settings.showMenuBarIcon,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            overlayKeyboard: settings.overlayKeyboard,
            appearance: settings.appearance
        )
    }

    func updateAutoClose(_ autoClose: Bool) {
        settings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: settings.windowSpacing,
            insets: settings.insets,
            autoClose: autoClose,
            showMenuBarIcon: settings.showMenuBarIcon,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            overlayKeyboard: settings.overlayKeyboard,
            appearance: settings.appearance
        )
    }

    func updateShowMenuBarIcon(_ show: Bool) {
        settings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: settings.windowSpacing,
            insets: settings.insets,
            autoClose: settings.autoClose,
            showMenuBarIcon: show,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            overlayKeyboard: settings.overlayKeyboard,
            appearance: settings.appearance
        )
    }

    func updateToggleOverlayShortcut(_ shortcut: KeyboardShortcut) {
        settings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: settings.windowSpacing,
            insets: settings.insets,
            autoClose: settings.autoClose,
            showMenuBarIcon: settings.showMenuBarIcon,
            toggleOverlayShortcut: shortcut,
            overlayKeyboard: settings.overlayKeyboard,
            appearance: settings.appearance
        )
    }

    func updateOverlayKeyboard(_ keyboard: OverlayKeyboardSettings) {
        settings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: settings.windowSpacing,
            insets: settings.insets,
            autoClose: settings.autoClose,
            showMenuBarIcon: settings.showMenuBarIcon,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            overlayKeyboard: keyboard,
            appearance: settings.appearance
        )
    }

    func updateAppearance(_ appearance: AppearanceSettings) {
        settings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: settings.windowSpacing,
            insets: settings.insets,
            autoClose: settings.autoClose,
            showMenuBarIcon: settings.showMenuBarIcon,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            overlayKeyboard: settings.overlayKeyboard,
            appearance: appearance
        )
    }

    func resetToDefaults() {
        settings = .default
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let settingsDidChange = Notification.Name("MacTileSettingsDidChange")
}
