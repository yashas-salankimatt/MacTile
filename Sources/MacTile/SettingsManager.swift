import Foundation
import MacTileCore

/// Manages persistence and access to MacTile settings
class SettingsManager {
    static let shared = SettingsManager()

    private let userDefaults = UserDefaults.standard
    private let settingsKey = "MacTileSettings"

    /// Backing storage for settings (allows modification without triggering didSet)
    private var _settings: MacTileSettings

    /// Current settings (cached in memory)
    var settings: MacTileSettings {
        get { _settings }
        set {
            _settings = newValue
            saveSettings()
            NotificationCenter.default.post(name: .settingsDidChange, object: self)
        }
    }

    private init() {
        _settings = Self.loadSettings() ?? .default
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
            launchAtLogin: settings.launchAtLogin,
            confirmOnClickWithoutDrag: settings.confirmOnClickWithoutDrag,
            showHelpText: settings.showHelpText,
            showMonitorIndicator: settings.showMonitorIndicator,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            secondaryToggleOverlayShortcut: settings.secondaryToggleOverlayShortcut,
            overlayKeyboard: settings.overlayKeyboard,
            tilingPresets: settings.tilingPresets,
            focusPresets: settings.focusPresets,
            appearance: settings.appearance,
            virtualSpaces: settings.virtualSpaces
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
            launchAtLogin: settings.launchAtLogin,
            confirmOnClickWithoutDrag: settings.confirmOnClickWithoutDrag,
            showHelpText: settings.showHelpText,
            showMonitorIndicator: settings.showMonitorIndicator,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            secondaryToggleOverlayShortcut: settings.secondaryToggleOverlayShortcut,
            overlayKeyboard: settings.overlayKeyboard,
            tilingPresets: settings.tilingPresets,
            focusPresets: settings.focusPresets,
            appearance: settings.appearance,
            virtualSpaces: settings.virtualSpaces
        )
    }

    func updateInsets(_ insets: EdgeInsets) {
        settings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: settings.windowSpacing,
            insets: insets,
            autoClose: settings.autoClose,
            showMenuBarIcon: settings.showMenuBarIcon,
            launchAtLogin: settings.launchAtLogin,
            confirmOnClickWithoutDrag: settings.confirmOnClickWithoutDrag,
            showHelpText: settings.showHelpText,
            showMonitorIndicator: settings.showMonitorIndicator,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            secondaryToggleOverlayShortcut: settings.secondaryToggleOverlayShortcut,
            overlayKeyboard: settings.overlayKeyboard,
            tilingPresets: settings.tilingPresets,
            focusPresets: settings.focusPresets,
            appearance: settings.appearance,
            virtualSpaces: settings.virtualSpaces
        )
    }

    func updateAutoClose(_ autoClose: Bool) {
        settings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: settings.windowSpacing,
            insets: settings.insets,
            autoClose: autoClose,
            showMenuBarIcon: settings.showMenuBarIcon,
            launchAtLogin: settings.launchAtLogin,
            confirmOnClickWithoutDrag: settings.confirmOnClickWithoutDrag,
            showHelpText: settings.showHelpText,
            showMonitorIndicator: settings.showMonitorIndicator,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            secondaryToggleOverlayShortcut: settings.secondaryToggleOverlayShortcut,
            overlayKeyboard: settings.overlayKeyboard,
            tilingPresets: settings.tilingPresets,
            focusPresets: settings.focusPresets,
            appearance: settings.appearance,
            virtualSpaces: settings.virtualSpaces
        )
    }

    func updateShowMenuBarIcon(_ show: Bool) {
        settings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: settings.windowSpacing,
            insets: settings.insets,
            autoClose: settings.autoClose,
            showMenuBarIcon: show,
            launchAtLogin: settings.launchAtLogin,
            confirmOnClickWithoutDrag: settings.confirmOnClickWithoutDrag,
            showHelpText: settings.showHelpText,
            showMonitorIndicator: settings.showMonitorIndicator,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            secondaryToggleOverlayShortcut: settings.secondaryToggleOverlayShortcut,
            overlayKeyboard: settings.overlayKeyboard,
            tilingPresets: settings.tilingPresets,
            focusPresets: settings.focusPresets,
            appearance: settings.appearance,
            virtualSpaces: settings.virtualSpaces
        )
    }

    func updateLaunchAtLogin(_ launch: Bool) {
        settings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: settings.windowSpacing,
            insets: settings.insets,
            autoClose: settings.autoClose,
            showMenuBarIcon: settings.showMenuBarIcon,
            launchAtLogin: launch,
            confirmOnClickWithoutDrag: settings.confirmOnClickWithoutDrag,
            showHelpText: settings.showHelpText,
            showMonitorIndicator: settings.showMonitorIndicator,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            secondaryToggleOverlayShortcut: settings.secondaryToggleOverlayShortcut,
            overlayKeyboard: settings.overlayKeyboard,
            tilingPresets: settings.tilingPresets,
            focusPresets: settings.focusPresets,
            appearance: settings.appearance,
            virtualSpaces: settings.virtualSpaces
        )
    }

    func updateConfirmOnClickWithoutDrag(_ confirm: Bool) {
        settings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: settings.windowSpacing,
            insets: settings.insets,
            autoClose: settings.autoClose,
            showMenuBarIcon: settings.showMenuBarIcon,
            launchAtLogin: settings.launchAtLogin,
            confirmOnClickWithoutDrag: confirm,
            showHelpText: settings.showHelpText,
            showMonitorIndicator: settings.showMonitorIndicator,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            secondaryToggleOverlayShortcut: settings.secondaryToggleOverlayShortcut,
            overlayKeyboard: settings.overlayKeyboard,
            tilingPresets: settings.tilingPresets,
            focusPresets: settings.focusPresets,
            appearance: settings.appearance,
            virtualSpaces: settings.virtualSpaces
        )
    }

    func updateToggleOverlayShortcut(_ shortcut: KeyboardShortcut) {
        settings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: settings.windowSpacing,
            insets: settings.insets,
            autoClose: settings.autoClose,
            showMenuBarIcon: settings.showMenuBarIcon,
            launchAtLogin: settings.launchAtLogin,
            confirmOnClickWithoutDrag: settings.confirmOnClickWithoutDrag,
            showHelpText: settings.showHelpText,
            showMonitorIndicator: settings.showMonitorIndicator,
            toggleOverlayShortcut: shortcut,
            secondaryToggleOverlayShortcut: settings.secondaryToggleOverlayShortcut,
            overlayKeyboard: settings.overlayKeyboard,
            tilingPresets: settings.tilingPresets,
            focusPresets: settings.focusPresets,
            appearance: settings.appearance,
            virtualSpaces: settings.virtualSpaces
        )
    }

    func updateSecondaryToggleOverlayShortcut(_ shortcut: KeyboardShortcut?) {
        settings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: settings.windowSpacing,
            insets: settings.insets,
            autoClose: settings.autoClose,
            showMenuBarIcon: settings.showMenuBarIcon,
            launchAtLogin: settings.launchAtLogin,
            confirmOnClickWithoutDrag: settings.confirmOnClickWithoutDrag,
            showHelpText: settings.showHelpText,
            showMonitorIndicator: settings.showMonitorIndicator,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            secondaryToggleOverlayShortcut: shortcut,
            overlayKeyboard: settings.overlayKeyboard,
            tilingPresets: settings.tilingPresets,
            focusPresets: settings.focusPresets,
            appearance: settings.appearance,
            virtualSpaces: settings.virtualSpaces
        )
    }

    func updateOverlayKeyboard(_ keyboard: OverlayKeyboardSettings) {
        settings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: settings.windowSpacing,
            insets: settings.insets,
            autoClose: settings.autoClose,
            showMenuBarIcon: settings.showMenuBarIcon,
            launchAtLogin: settings.launchAtLogin,
            confirmOnClickWithoutDrag: settings.confirmOnClickWithoutDrag,
            showHelpText: settings.showHelpText,
            showMonitorIndicator: settings.showMonitorIndicator,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            secondaryToggleOverlayShortcut: settings.secondaryToggleOverlayShortcut,
            overlayKeyboard: keyboard,
            tilingPresets: settings.tilingPresets,
            focusPresets: settings.focusPresets,
            appearance: settings.appearance,
            virtualSpaces: settings.virtualSpaces
        )
    }

    func updateTilingPresets(_ presets: [TilingPreset]) {
        settings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: settings.windowSpacing,
            insets: settings.insets,
            autoClose: settings.autoClose,
            showMenuBarIcon: settings.showMenuBarIcon,
            launchAtLogin: settings.launchAtLogin,
            confirmOnClickWithoutDrag: settings.confirmOnClickWithoutDrag,
            showHelpText: settings.showHelpText,
            showMonitorIndicator: settings.showMonitorIndicator,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            secondaryToggleOverlayShortcut: settings.secondaryToggleOverlayShortcut,
            overlayKeyboard: settings.overlayKeyboard,
            tilingPresets: presets,
            focusPresets: settings.focusPresets,
            appearance: settings.appearance,
            virtualSpaces: settings.virtualSpaces
        )
    }

    func updateFocusPresets(_ presets: [FocusPreset]) {
        settings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: settings.windowSpacing,
            insets: settings.insets,
            autoClose: settings.autoClose,
            showMenuBarIcon: settings.showMenuBarIcon,
            launchAtLogin: settings.launchAtLogin,
            confirmOnClickWithoutDrag: settings.confirmOnClickWithoutDrag,
            showHelpText: settings.showHelpText,
            showMonitorIndicator: settings.showMonitorIndicator,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            secondaryToggleOverlayShortcut: settings.secondaryToggleOverlayShortcut,
            overlayKeyboard: settings.overlayKeyboard,
            tilingPresets: settings.tilingPresets,
            focusPresets: presets,
            appearance: settings.appearance,
            virtualSpaces: settings.virtualSpaces
        )
    }

    func updateAppearance(_ appearance: AppearanceSettings) {
        settings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: settings.windowSpacing,
            insets: settings.insets,
            autoClose: settings.autoClose,
            showMenuBarIcon: settings.showMenuBarIcon,
            launchAtLogin: settings.launchAtLogin,
            confirmOnClickWithoutDrag: settings.confirmOnClickWithoutDrag,
            showHelpText: settings.showHelpText,
            showMonitorIndicator: settings.showMonitorIndicator,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            secondaryToggleOverlayShortcut: settings.secondaryToggleOverlayShortcut,
            overlayKeyboard: settings.overlayKeyboard,
            tilingPresets: settings.tilingPresets,
            focusPresets: settings.focusPresets,
            appearance: appearance,
            virtualSpaces: settings.virtualSpaces
        )
    }

    func updateShowHelpText(_ show: Bool) {
        settings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: settings.windowSpacing,
            insets: settings.insets,
            autoClose: settings.autoClose,
            showMenuBarIcon: settings.showMenuBarIcon,
            launchAtLogin: settings.launchAtLogin,
            confirmOnClickWithoutDrag: settings.confirmOnClickWithoutDrag,
            showHelpText: show,
            showMonitorIndicator: settings.showMonitorIndicator,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            secondaryToggleOverlayShortcut: settings.secondaryToggleOverlayShortcut,
            overlayKeyboard: settings.overlayKeyboard,
            tilingPresets: settings.tilingPresets,
            focusPresets: settings.focusPresets,
            appearance: settings.appearance,
            virtualSpaces: settings.virtualSpaces
        )
    }

    func updateShowMonitorIndicator(_ show: Bool) {
        settings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: settings.windowSpacing,
            insets: settings.insets,
            autoClose: settings.autoClose,
            showMenuBarIcon: settings.showMenuBarIcon,
            launchAtLogin: settings.launchAtLogin,
            confirmOnClickWithoutDrag: settings.confirmOnClickWithoutDrag,
            showHelpText: settings.showHelpText,
            showMonitorIndicator: show,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            secondaryToggleOverlayShortcut: settings.secondaryToggleOverlayShortcut,
            overlayKeyboard: settings.overlayKeyboard,
            tilingPresets: settings.tilingPresets,
            focusPresets: settings.focusPresets,
            appearance: settings.appearance,
            virtualSpaces: settings.virtualSpaces
        )
    }

    func updateVirtualSpaces(_ spaces: VirtualSpacesStorage) {
        settings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: settings.windowSpacing,
            insets: settings.insets,
            autoClose: settings.autoClose,
            showMenuBarIcon: settings.showMenuBarIcon,
            launchAtLogin: settings.launchAtLogin,
            confirmOnClickWithoutDrag: settings.confirmOnClickWithoutDrag,
            showHelpText: settings.showHelpText,
            showMonitorIndicator: settings.showMonitorIndicator,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            secondaryToggleOverlayShortcut: settings.secondaryToggleOverlayShortcut,
            overlayKeyboard: settings.overlayKeyboard,
            tilingPresets: settings.tilingPresets,
            focusPresets: settings.focusPresets,
            appearance: settings.appearance,
            virtualSpaces: spaces
        )
    }

    /// Save virtual spaces without triggering settings change notification.
    /// This avoids unnecessary hotkey re-registration which can cause timing issues.
    func saveVirtualSpacesQuietly(_ spaces: VirtualSpacesStorage) {
        // Directly modify the underlying storage without triggering didSet
        let newSettings = MacTileSettings(
            gridSizes: settings.gridSizes,
            windowSpacing: settings.windowSpacing,
            insets: settings.insets,
            autoClose: settings.autoClose,
            showMenuBarIcon: settings.showMenuBarIcon,
            launchAtLogin: settings.launchAtLogin,
            confirmOnClickWithoutDrag: settings.confirmOnClickWithoutDrag,
            showHelpText: settings.showHelpText,
            showMonitorIndicator: settings.showMonitorIndicator,
            toggleOverlayShortcut: settings.toggleOverlayShortcut,
            secondaryToggleOverlayShortcut: settings.secondaryToggleOverlayShortcut,
            overlayKeyboard: settings.overlayKeyboard,
            tilingPresets: settings.tilingPresets,
            focusPresets: settings.focusPresets,
            appearance: settings.appearance,
            virtualSpaces: spaces
        )

        // Save directly to UserDefaults without triggering the didSet notification
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(newSettings)
            userDefaults.set(data, forKey: settingsKey)

            // Update the cached settings without triggering didSet by using a separate internal setter
            _settings = newSettings
        } catch {
            print("Failed to encode settings: \(error)")
        }
    }

    func resetToDefaults() {
        settings = .default
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let settingsDidChange = Notification.Name("MacTileSettingsDidChange")
}
