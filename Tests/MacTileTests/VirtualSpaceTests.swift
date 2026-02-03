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
        let spaceTooLow = VirtualSpace(number: 0, displayID: 1)
        let spaceTooHigh = VirtualSpace(number: 15, displayID: 1)

        XCTAssertEqual(spaceTooLow.number, 1, "Number should be clamped to minimum 1")
        XCTAssertEqual(spaceTooHigh.number, 9, "Number should be clamped to maximum 9")
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

final class VirtualSpaceZOrderTests: XCTestCase {

    func testWindowZOrderPreservation() {
        // Create windows with specific z-order
        let windows = [
            VirtualSpaceWindow(
                appBundleID: "com.apple.finder",
                windowTitle: "Topmost",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100),
                zIndex: 0  // Topmost
            ),
            VirtualSpaceWindow(
                appBundleID: "com.apple.Terminal",
                windowTitle: "Middle",
                frame: CGRect(x: 50, y: 50, width: 100, height: 100),
                zIndex: 1
            ),
            VirtualSpaceWindow(
                appBundleID: "com.apple.Safari",
                windowTitle: "Bottom",
                frame: CGRect(x: 100, y: 100, width: 100, height: 100),
                zIndex: 2  // Bottommost
            )
        ]

        let space = VirtualSpace(
            number: 1,
            windows: windows,
            displayID: 1
        )

        // Verify z-order is preserved
        let sortedByZ = space.windows.sorted { $0.zIndex < $1.zIndex }
        XCTAssertEqual(sortedByZ[0].windowTitle, "Topmost")
        XCTAssertEqual(sortedByZ[1].windowTitle, "Middle")
        XCTAssertEqual(sortedByZ[2].windowTitle, "Bottom")
    }

    func testRestoreOrderReversesZOrder() {
        // When restoring, we should raise from back to front
        // So a reverse sort by zIndex gives us the restoration order
        let windows = [
            VirtualSpaceWindow(appBundleID: "a", windowTitle: "A", frame: .zero, zIndex: 0),
            VirtualSpaceWindow(appBundleID: "b", windowTitle: "B", frame: .zero, zIndex: 1),
            VirtualSpaceWindow(appBundleID: "c", windowTitle: "C", frame: .zero, zIndex: 2)
        ]

        // Sort by zIndex descending (back to front for restoration)
        let restoreOrder = windows.sorted { $0.zIndex > $1.zIndex }

        XCTAssertEqual(restoreOrder[0].windowTitle, "C", "Should restore C first (bottom)")
        XCTAssertEqual(restoreOrder[1].windowTitle, "B", "Should restore B second (middle)")
        XCTAssertEqual(restoreOrder[2].windowTitle, "A", "Should restore A last (top)")
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
