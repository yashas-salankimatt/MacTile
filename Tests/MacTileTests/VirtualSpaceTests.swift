import XCTest
@testable import MacTileCore

// MARK: - VirtualSpaceWindow Tests

final class VirtualSpaceWindowTests: XCTestCase {

    func testVirtualSpaceWindowInitialization() {
        let window = VirtualSpaceWindow(
            appBundleID: "com.apple.finder",
            windowTitle: "Documents",
            frame: CGRect(x: 100, y: 200, width: 800, height: 600),
            zIndex: 0
        )

        XCTAssertEqual(window.appBundleID, "com.apple.finder")
        XCTAssertEqual(window.windowTitle, "Documents")
        XCTAssertEqual(window.frame, CGRect(x: 100, y: 200, width: 800, height: 600))
        XCTAssertEqual(window.zIndex, 0)
    }

    func testVirtualSpaceWindowEquality() {
        let window1 = VirtualSpaceWindow(
            appBundleID: "com.apple.finder",
            windowTitle: "Documents",
            frame: CGRect(x: 100, y: 200, width: 800, height: 600),
            zIndex: 0
        )

        let window2 = VirtualSpaceWindow(
            appBundleID: "com.apple.finder",
            windowTitle: "Documents",
            frame: CGRect(x: 100, y: 200, width: 800, height: 600),
            zIndex: 0
        )

        let window3 = VirtualSpaceWindow(
            appBundleID: "com.apple.finder",
            windowTitle: "Downloads",
            frame: CGRect(x: 100, y: 200, width: 800, height: 600),
            zIndex: 0
        )

        XCTAssertEqual(window1, window2)
        XCTAssertNotEqual(window1, window3)
    }

    func testVirtualSpaceWindowCodable() throws {
        let window = VirtualSpaceWindow(
            appBundleID: "com.apple.finder",
            windowTitle: "Documents",
            frame: CGRect(x: 100, y: 200, width: 800, height: 600),
            zIndex: 2
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(window)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VirtualSpaceWindow.self, from: data)

        XCTAssertEqual(window, decoded)
    }
}

// MARK: - VirtualSpace Tests

final class VirtualSpaceTests: XCTestCase {

    func testVirtualSpaceInitialization() {
        let space = VirtualSpace(
            number: 3,
            name: "Development",
            windows: [],
            displayID: 12345
        )

        XCTAssertEqual(space.number, 3)
        XCTAssertEqual(space.name, "Development")
        XCTAssertTrue(space.windows.isEmpty)
        XCTAssertEqual(space.displayID, 12345)
    }

    func testVirtualSpaceNumberClamping() {
        let spaceTooLow = VirtualSpace(number: -1, displayID: 1)
        let spaceTooHigh = VirtualSpace(number: 15, displayID: 1)
        let spaceZero = VirtualSpace(number: 0, displayID: 1)

        XCTAssertEqual(spaceTooLow.number, 0, "Number should be clamped to minimum 0")
        XCTAssertEqual(spaceTooHigh.number, 9, "Number should be clamped to maximum 9")
        XCTAssertEqual(spaceZero.number, 0, "Number 0 should be valid")
    }

    func testVirtualSpaceDisplayName() {
        let namedSpace = VirtualSpace(number: 1, name: "Work", displayID: 1)
        let unnamedSpace = VirtualSpace(number: 2, displayID: 1)
        let emptyNameSpace = VirtualSpace(number: 3, name: "", displayID: 1)

        XCTAssertEqual(namedSpace.displayName, "1: Work")
        XCTAssertEqual(unnamedSpace.displayName, "2")
        XCTAssertEqual(emptyNameSpace.displayName, "3")
    }

    func testVirtualSpaceIsEmpty() {
        let emptySpace = VirtualSpace(number: 1, windows: [], displayID: 1)
        let nonEmptySpace = VirtualSpace(
            number: 2,
            windows: [
                VirtualSpaceWindow(
                    appBundleID: "com.apple.finder",
                    windowTitle: "Test",
                    frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                    zIndex: 0
                )
            ],
            displayID: 1
        )

        XCTAssertTrue(emptySpace.isEmpty)
        XCTAssertFalse(nonEmptySpace.isEmpty)
    }

    func testVirtualSpaceEmpty() {
        let space = VirtualSpace.empty(number: 5, displayID: 999)

        XCTAssertEqual(space.number, 5)
        XCTAssertNil(space.name)
        XCTAssertTrue(space.windows.isEmpty)
        XCTAssertEqual(space.displayID, 999)
    }

    func testVirtualSpaceCodable() throws {
        let windows = [
            VirtualSpaceWindow(
                appBundleID: "com.apple.finder",
                windowTitle: "Documents",
                frame: CGRect(x: 100, y: 200, width: 800, height: 600),
                zIndex: 0
            ),
            VirtualSpaceWindow(
                appBundleID: "com.apple.Terminal",
                windowTitle: "Terminal",
                frame: CGRect(x: 200, y: 300, width: 600, height: 400),
                zIndex: 1
            )
        ]

        let space = VirtualSpace(
            number: 3,
            name: "Development",
            windows: windows,
            displayID: 12345
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(space)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VirtualSpace.self, from: data)

        XCTAssertEqual(space, decoded)
    }
}

// MARK: - VirtualSpacesStorage Tests

final class VirtualSpacesStorageTests: XCTestCase {

    func testVirtualSpacesStorageInitialization() {
        let storage = VirtualSpacesStorage()
        XCTAssertTrue(storage.spacesByMonitor.isEmpty)
    }

    func testSetAndGetSpace() {
        var storage = VirtualSpacesStorage()

        let space = VirtualSpace(
            number: 1,
            name: "Test Space",
            windows: [],
            displayID: 100
        )

        storage.setSpace(space, displayID: 100)

        let retrieved = storage.getSpace(displayID: 100, number: 1)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.name, "Test Space")
        XCTAssertEqual(retrieved?.number, 1)
    }

    func testGetSpaceNotFound() {
        let storage = VirtualSpacesStorage()

        let retrieved = storage.getSpace(displayID: 999, number: 5)
        XCTAssertNil(retrieved)
    }

    func testGetSpacesForMonitor() {
        var storage = VirtualSpacesStorage()

        // Add a few spaces for monitor 100
        storage.setSpace(VirtualSpace(number: 1, name: "One", displayID: 100), displayID: 100)
        storage.setSpace(VirtualSpace(number: 3, name: "Three", displayID: 100), displayID: 100)
        storage.setSpace(VirtualSpace(number: 5, name: "Five", displayID: 100), displayID: 100)

        // Add a space for different monitor
        storage.setSpace(VirtualSpace(number: 1, name: "Other", displayID: 200), displayID: 200)

        let spaces = storage.getSpaces(displayID: 100)
        XCTAssertEqual(spaces.count, 3)

        // Verify they're in order
        let numbers = spaces.map { $0.number }
        XCTAssertEqual(numbers, [1, 3, 5])
    }

    func testGetNonEmptySpaces() {
        var storage = VirtualSpacesStorage()

        // Add an empty space
        storage.setSpace(VirtualSpace(number: 1, windows: [], displayID: 100), displayID: 100)

        // Add a non-empty space
        let window = VirtualSpaceWindow(
            appBundleID: "com.test",
            windowTitle: "Test",
            frame: CGRect(x: 0, y: 0, width: 100, height: 100),
            zIndex: 0
        )
        storage.setSpace(VirtualSpace(number: 2, windows: [window], displayID: 100), displayID: 100)

        let nonEmpty = storage.getNonEmptySpaces(displayID: 100)
        XCTAssertEqual(nonEmpty.count, 1)
        XCTAssertEqual(nonEmpty.first?.number, 2)
    }

    func testMultipleMonitors() {
        var storage = VirtualSpacesStorage()

        // Set spaces for two different monitors
        storage.setSpace(VirtualSpace(number: 1, name: "Monitor1-Space1", displayID: 100), displayID: 100)
        storage.setSpace(VirtualSpace(number: 1, name: "Monitor2-Space1", displayID: 200), displayID: 200)

        let space1 = storage.getSpace(displayID: 100, number: 1)
        let space2 = storage.getSpace(displayID: 200, number: 1)

        XCTAssertEqual(space1?.name, "Monitor1-Space1")
        XCTAssertEqual(space2?.name, "Monitor2-Space1")
    }

    func testVirtualSpacesStorageCodable() throws {
        var storage = VirtualSpacesStorage()

        let window = VirtualSpaceWindow(
            appBundleID: "com.test",
            windowTitle: "Test",
            frame: CGRect(x: 100, y: 200, width: 300, height: 400),
            zIndex: 0
        )

        storage.setSpace(
            VirtualSpace(number: 1, name: "Encoded Space", windows: [window], displayID: 100),
            displayID: 100
        )
        storage.setSpace(
            VirtualSpace(number: 3, name: "Another", windows: [], displayID: 200),
            displayID: 200
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(storage)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VirtualSpacesStorage.self, from: data)

        XCTAssertEqual(storage, decoded)

        // Verify the decoded data is correct
        let decodedSpace = decoded.getSpace(displayID: 100, number: 1)
        XCTAssertEqual(decodedSpace?.name, "Encoded Space")
        XCTAssertEqual(decodedSpace?.windows.count, 1)
        XCTAssertEqual(decodedSpace?.windows.first?.appBundleID, "com.test")
    }

    func testOverwriteExistingSpace() {
        var storage = VirtualSpacesStorage()

        // Set initial space
        storage.setSpace(VirtualSpace(number: 1, name: "Original", displayID: 100), displayID: 100)

        // Overwrite with new space
        storage.setSpace(VirtualSpace(number: 1, name: "Updated", displayID: 100), displayID: 100)

        let space = storage.getSpace(displayID: 100, number: 1)
        XCTAssertEqual(space?.name, "Updated")
    }
}

// MARK: - MacTileSettings VirtualSpaces Integration Tests

final class MacTileSettingsVirtualSpacesTests: XCTestCase {

    func testDefaultSettingsHasEmptyVirtualSpaces() {
        let settings = MacTileSettings.default
        XCTAssertTrue(settings.virtualSpaces.spacesByMonitor.isEmpty)
    }

    func testSettingsWithVirtualSpacesCodable() throws {
        var storage = VirtualSpacesStorage()
        storage.setSpace(
            VirtualSpace(number: 1, name: "Test", displayID: 123),
            displayID: 123
        )

        let settings = MacTileSettings(
            gridSizes: [GridSize(cols: 8, rows: 2)],
            windowSpacing: 0,
            insets: .zero,
            autoClose: true,
            showMenuBarIcon: true,
            launchAtLogin: false,
            confirmOnClickWithoutDrag: true,
            showHelpText: true,
            showMonitorIndicator: true,
            toggleOverlayShortcut: .defaultToggleOverlay,
            secondaryToggleOverlayShortcut: nil,
            overlayKeyboard: .default,
            tilingPresets: [],
            focusPresets: [],
            appearance: .default,
            virtualSpaces: storage
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MacTileSettings.self, from: data)

        // Verify virtual spaces were preserved
        let space = decoded.virtualSpaces.getSpace(displayID: 123, number: 1)
        XCTAssertNotNil(space)
        XCTAssertEqual(space?.name, "Test")
    }
}

// MARK: - VirtualSpace Z-Order Tests

/// Tests for VirtualSpaceWindow comparators and VirtualSpace z-order properties.
/// VirtualSpaceManager.restoreWindows() uses VirtualSpaceWindow.restoreOrderComparator
/// to sort windows within each app during restore. These tests validate that shared logic.
final class VirtualSpaceZOrderTests: XCTestCase {

    // MARK: - Comparator Tests (directly testing production sorting logic)

    func testRestoreOrderComparator_HigherZIndexComesFirst() {
        let back = VirtualSpaceWindow(appBundleID: "a", windowTitle: "Back", frame: .zero, zIndex: 2)
        let front = VirtualSpaceWindow(appBundleID: "a", windowTitle: "Front", frame: .zero, zIndex: 0)

        // In restore order, higher zIndex (back) should come before lower zIndex (front)
        XCTAssertTrue(VirtualSpaceWindow.restoreOrderComparator(back, front))
        XCTAssertFalse(VirtualSpaceWindow.restoreOrderComparator(front, back))
    }

    func testZOrderComparator_LowerZIndexComesFirst() {
        let back = VirtualSpaceWindow(appBundleID: "a", windowTitle: "Back", frame: .zero, zIndex: 2)
        let front = VirtualSpaceWindow(appBundleID: "a", windowTitle: "Front", frame: .zero, zIndex: 0)

        // In z-order, lower zIndex (front) should come before higher zIndex (back)
        XCTAssertTrue(VirtualSpaceWindow.zOrderComparator(front, back))
        XCTAssertFalse(VirtualSpaceWindow.zOrderComparator(back, front))
    }

    func testRestoreOrderComparator_EqualZIndex() {
        let w1 = VirtualSpaceWindow(appBundleID: "a", windowTitle: "W1", frame: .zero, zIndex: 1)
        let w2 = VirtualSpaceWindow(appBundleID: "b", windowTitle: "W2", frame: .zero, zIndex: 1)

        // Equal zIndex: neither should be "before" the other
        XCTAssertFalse(VirtualSpaceWindow.restoreOrderComparator(w1, w2))
        XCTAssertFalse(VirtualSpaceWindow.restoreOrderComparator(w2, w1))
    }

    // MARK: - Property Tests (using the comparators)

    func testWindowsByZOrder_ReturnsCorrectOrder() {
        // Create windows in random order with specific z-indices
        let windows = [
            VirtualSpaceWindow(appBundleID: "com.apple.Terminal", windowTitle: "Middle", frame: .zero, zIndex: 1),
            VirtualSpaceWindow(appBundleID: "com.apple.finder", windowTitle: "Topmost", frame: .zero, zIndex: 0),
            VirtualSpaceWindow(appBundleID: "com.apple.Safari", windowTitle: "Bottom", frame: .zero, zIndex: 2)
        ]

        let space = VirtualSpace(number: 1, windows: windows, displayID: 1)

        // Test the production windowsByZOrder property
        let byZOrder = space.windowsByZOrder
        XCTAssertEqual(byZOrder.count, 3)
        XCTAssertEqual(byZOrder[0].windowTitle, "Topmost", "zIndex 0 should be first (topmost)")
        XCTAssertEqual(byZOrder[1].windowTitle, "Middle", "zIndex 1 should be second")
        XCTAssertEqual(byZOrder[2].windowTitle, "Bottom", "zIndex 2 should be last (bottommost)")
    }

    func testWindowsInRestoreOrder_ReturnsBackToFront() {
        // When restoring, we raise windows from back to front so the topmost window ends up on top
        let windows = [
            VirtualSpaceWindow(appBundleID: "a", windowTitle: "A", frame: .zero, zIndex: 0),  // Topmost
            VirtualSpaceWindow(appBundleID: "b", windowTitle: "B", frame: .zero, zIndex: 1),
            VirtualSpaceWindow(appBundleID: "c", windowTitle: "C", frame: .zero, zIndex: 2)   // Bottommost
        ]

        let space = VirtualSpace(number: 1, windows: windows, displayID: 1)

        // Test the production windowsInRestoreOrder property
        let restoreOrder = space.windowsInRestoreOrder
        XCTAssertEqual(restoreOrder.count, 3)
        XCTAssertEqual(restoreOrder[0].windowTitle, "C", "Should restore C first (it's at the bottom)")
        XCTAssertEqual(restoreOrder[1].windowTitle, "B", "Should restore B second (middle)")
        XCTAssertEqual(restoreOrder[2].windowTitle, "A", "Should restore A last (so it ends up on top)")
    }

    func testWindowsInRestoreOrder_EmptySpace() {
        let space = VirtualSpace(number: 1, windows: [], displayID: 1)
        XCTAssertTrue(space.windowsInRestoreOrder.isEmpty)
    }

    func testWindowsInRestoreOrder_SingleWindow() {
        let windows = [
            VirtualSpaceWindow(appBundleID: "a", windowTitle: "Only", frame: .zero, zIndex: 0)
        ]
        let space = VirtualSpace(number: 1, windows: windows, displayID: 1)

        let restoreOrder = space.windowsInRestoreOrder
        XCTAssertEqual(restoreOrder.count, 1)
        XCTAssertEqual(restoreOrder[0].windowTitle, "Only")
    }

    func testWindowsByZOrder_ManyWindows() {
        // Test with more windows to ensure sorting is stable
        let windows = (0..<10).map { i in
            VirtualSpaceWindow(appBundleID: "app\(i)", windowTitle: "Window \(i)", frame: .zero, zIndex: i)
        }.shuffled()  // Shuffle to ensure the property actually sorts

        let space = VirtualSpace(number: 1, windows: windows, displayID: 1)

        let byZOrder = space.windowsByZOrder
        for (index, window) in byZOrder.enumerated() {
            XCTAssertEqual(window.zIndex, index, "Window at position \(index) should have zIndex \(index)")
        }
    }
}

// MARK: - Frame Persistence Tests

final class VirtualSpaceFramePersistenceTests: XCTestCase {

    func testFramePersistence() throws {
        let frame = CGRect(x: 123.5, y: 456.75, width: 789.25, height: 1011.5)
        let window = VirtualSpaceWindow(
            appBundleID: "test",
            windowTitle: "Test",
            frame: frame,
            zIndex: 0
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(window)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VirtualSpaceWindow.self, from: data)

        // CGRect should be preserved exactly
        XCTAssertEqual(decoded.frame.origin.x, 123.5, accuracy: 0.001)
        XCTAssertEqual(decoded.frame.origin.y, 456.75, accuracy: 0.001)
        XCTAssertEqual(decoded.frame.width, 789.25, accuracy: 0.001)
        XCTAssertEqual(decoded.frame.height, 1011.5, accuracy: 0.001)
    }

    func testMultipleWindowFrames() throws {
        let windows = [
            VirtualSpaceWindow(
                appBundleID: "app1",
                windowTitle: "Left",
                frame: CGRect(x: 0, y: 0, width: 960, height: 1080),
                zIndex: 0
            ),
            VirtualSpaceWindow(
                appBundleID: "app2",
                windowTitle: "Right",
                frame: CGRect(x: 960, y: 0, width: 960, height: 1080),
                zIndex: 1
            )
        ]

        let space = VirtualSpace(number: 1, windows: windows, displayID: 1)

        let encoder = JSONEncoder()
        let data = try encoder.encode(space)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(VirtualSpace.self, from: data)

        // Verify both windows preserved
        XCTAssertEqual(decoded.windows.count, 2)

        let leftWindow = decoded.windows.first { $0.windowTitle == "Left" }
        let rightWindow = decoded.windows.first { $0.windowTitle == "Right" }

        XCTAssertNotNil(leftWindow)
        XCTAssertNotNil(rightWindow)
        XCTAssertEqual(leftWindow?.frame.width, 960)
        XCTAssertEqual(rightWindow?.frame.origin.x, 960)
    }
}

// MARK: - Virtual Spaces Settings Tests

final class VirtualSpacesSettingsTests: XCTestCase {

    func testVirtualSpacesEnabledDefaultValue() {
        let defaults = MacTileSettings.default
        XCTAssertTrue(defaults.virtualSpacesEnabled, "Virtual spaces should be enabled by default")
    }

    func testVirtualSpaceSaveModifiersDefaultValue() {
        let defaults = MacTileSettings.default
        // Default: Control + Option + Shift
        let expectedModifiers = KeyboardShortcut.Modifiers.control |
                               KeyboardShortcut.Modifiers.option |
                               KeyboardShortcut.Modifiers.shift
        XCTAssertEqual(defaults.virtualSpaceSaveModifiers, expectedModifiers)
    }

    func testVirtualSpaceRestoreModifiersDefaultValue() {
        let defaults = MacTileSettings.default
        // Default: Control + Option
        let expectedModifiers = KeyboardShortcut.Modifiers.control |
                               KeyboardShortcut.Modifiers.option
        XCTAssertEqual(defaults.virtualSpaceRestoreModifiers, expectedModifiers)
    }

    func testVirtualSpacesSettingsCodable() throws {
        var settings = MacTileSettings.default
        settings.virtualSpacesEnabled = false
        settings.virtualSpaceSaveModifiers = KeyboardShortcut.Modifiers.command | KeyboardShortcut.Modifiers.shift
        settings.virtualSpaceRestoreModifiers = KeyboardShortcut.Modifiers.command

        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(MacTileSettings.self, from: data)

        XCTAssertEqual(decoded.virtualSpacesEnabled, false)
        XCTAssertEqual(decoded.virtualSpaceSaveModifiers, KeyboardShortcut.Modifiers.command | KeyboardShortcut.Modifiers.shift)
        XCTAssertEqual(decoded.virtualSpaceRestoreModifiers, KeyboardShortcut.Modifiers.command)
    }
}

// MARK: - Default Tiling Presets Tests

final class DefaultTilingPresetsTests: XCTestCase {

    func testDefaultTilingPresetsExist() {
        let presets = MacTileSettings.defaultTilingPresets
        XCTAssertEqual(presets.count, 4, "Should have 4 default presets (R, E, F, C)")
    }

    func testRightPreset() {
        let presets = MacTileSettings.defaultTilingPresets
        guard let rightPreset = presets.first(where: { $0.keyString == "R" }) else {
            XCTFail("R preset not found")
            return
        }

        XCTAssertEqual(rightPreset.keyCode, 15, "R key code should be 15")
        XCTAssertEqual(rightPreset.modifiers, KeyboardShortcut.Modifiers.none, "R should have no modifiers")
        XCTAssertEqual(rightPreset.positions.count, 3, "R should have 3 cycling positions")
        XCTAssertTrue(rightPreset.autoConfirm, "R should auto-confirm")

        // First position: right half
        XCTAssertEqual(rightPreset.positions[0].startX, 0.5, accuracy: 0.01)
        XCTAssertEqual(rightPreset.positions[0].endX, 1.0, accuracy: 0.01)
    }

    func testLeftPreset() {
        let presets = MacTileSettings.defaultTilingPresets
        guard let leftPreset = presets.first(where: { $0.keyString == "E" }) else {
            XCTFail("E preset not found")
            return
        }

        XCTAssertEqual(leftPreset.keyCode, 14, "E key code should be 14")
        XCTAssertEqual(leftPreset.modifiers, KeyboardShortcut.Modifiers.none, "E should have no modifiers")
        XCTAssertEqual(leftPreset.positions.count, 3, "E should have 3 cycling positions")
        XCTAssertTrue(leftPreset.autoConfirm, "E should auto-confirm")

        // First position: left half
        XCTAssertEqual(leftPreset.positions[0].startX, 0.0, accuracy: 0.01)
        XCTAssertEqual(leftPreset.positions[0].endX, 0.5, accuracy: 0.01)
    }

    func testFullScreenPreset() {
        let presets = MacTileSettings.defaultTilingPresets
        guard let fullPreset = presets.first(where: { $0.keyString == "F" }) else {
            XCTFail("F preset not found")
            return
        }

        XCTAssertEqual(fullPreset.keyCode, 3, "F key code should be 3")
        XCTAssertEqual(fullPreset.modifiers, KeyboardShortcut.Modifiers.none, "F should have no modifiers")
        XCTAssertEqual(fullPreset.positions.count, 1, "F should have 1 position")
        XCTAssertTrue(fullPreset.autoConfirm, "F should auto-confirm")

        // Full screen position
        XCTAssertEqual(fullPreset.positions[0].startX, 0.0, accuracy: 0.01)
        XCTAssertEqual(fullPreset.positions[0].startY, 0.0, accuracy: 0.01)
        XCTAssertEqual(fullPreset.positions[0].endX, 1.0, accuracy: 0.01)
        XCTAssertEqual(fullPreset.positions[0].endY, 1.0, accuracy: 0.01)
    }

    func testCenterPreset() {
        let presets = MacTileSettings.defaultTilingPresets
        guard let centerPreset = presets.first(where: { $0.keyString == "C" }) else {
            XCTFail("C preset not found")
            return
        }

        XCTAssertEqual(centerPreset.keyCode, 8, "C key code should be 8")
        XCTAssertEqual(centerPreset.modifiers, KeyboardShortcut.Modifiers.none, "C should have no modifiers")
        XCTAssertEqual(centerPreset.positions.count, 2, "C should have 2 cycling positions")
        XCTAssertTrue(centerPreset.autoConfirm, "C should auto-confirm")

        // First position: center third
        XCTAssertEqual(centerPreset.positions[0].startX, 0.333, accuracy: 0.01)
        XCTAssertEqual(centerPreset.positions[0].endX, 0.667, accuracy: 0.01)
    }

    func testDefaultPresetsAllHaveAutoConfirm() {
        let presets = MacTileSettings.defaultTilingPresets
        for preset in presets {
            XCTAssertTrue(preset.autoConfirm, "Preset \(preset.keyString) should have autoConfirm enabled")
        }
    }

    func testDefaultPresetsAllHaveNoModifiers() {
        let presets = MacTileSettings.defaultTilingPresets
        for preset in presets {
            XCTAssertEqual(preset.modifiers, KeyboardShortcut.Modifiers.none,
                          "Preset \(preset.keyString) should have no modifiers")
        }
    }
}
