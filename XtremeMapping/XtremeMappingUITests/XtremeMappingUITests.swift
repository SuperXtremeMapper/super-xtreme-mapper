//
//  XtremeMappingUITests.swift
//  XtremeMappingUITests
//
//  UI tests for SuperXtremeMapping
//

import XCTest

final class XtremeMappingUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper Methods

    /// Creates a new document from the welcome window
    private func createNewDocument() {
        // Click "New Mapping" on welcome window
        let newButton = app.buttons["New Mapping"]
        if newButton.waitForExistence(timeout: 5) {
            newButton.click()
        }

        // Wait for document window to appear
        let toolbar = app.toolbars.firstMatch
        XCTAssertTrue(toolbar.waitForExistence(timeout: 5), "Document window should appear")
    }

    /// Adds a mapping to the current document by clicking the + button
    private func addMapping() {
        // Look for the Add button in the action bar
        let addButton = app.buttons["Add Input"].firstMatch
        if addButton.waitForExistence(timeout: 3) {
            addButton.click()
        } else {
            // Try alternate - might be a menu
            let addMenu = app.popUpButtons["Add"].firstMatch
            if addMenu.waitForExistence(timeout: 2) {
                addMenu.click()
                app.menuItems["Add Input"].click()
            }
        }

        // Give time for the mapping to be added
        sleep(1)
    }

    /// Selects the first row in the mappings table
    private func selectFirstMapping() {
        let table = app.tables.firstMatch
        if table.waitForExistence(timeout: 3) {
            let firstRow = table.tableRows.firstMatch
            if firstRow.exists {
                firstRow.click()
            }
        }
    }

    // MARK: - Save Prompt Tests

    @MainActor
    func testSavePromptAppearsWhenClosingModifiedDocument() throws {
        // Create new document
        createNewDocument()

        // Add a mapping to make it dirty
        addMapping()

        // Try to close the window
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists, "Document window should exist")

        // Use keyboard shortcut to close (Cmd+W)
        app.typeKey("w", modifierFlags: .command)

        // Check for save dialog/sheet
        let saveSheet = app.sheets.firstMatch
        let saveAlert = app.dialogs.firstMatch

        let sheetAppeared = saveSheet.waitForExistence(timeout: 3)
        let alertAppeared = saveAlert.waitForExistence(timeout: 1)

        XCTAssertTrue(sheetAppeared || alertAppeared, "Save prompt should appear when closing modified document")

        // Dismiss the dialog by clicking "Don't Save" or "Discard"
        let discardButton = app.buttons["Discard"].firstMatch
        let dontSaveButton = app.buttons["Don't Save"].firstMatch

        if discardButton.exists {
            discardButton.click()
        } else if dontSaveButton.exists {
            dontSaveButton.click()
        }
    }

    @MainActor
    func testNoSavePromptWhenClosingUnmodifiedDocument() throws {
        // Create new document
        createNewDocument()

        // Don't modify it - just close immediately
        let window = app.windows.firstMatch
        XCTAssertTrue(window.exists, "Document window should exist")

        // Close the window
        app.typeKey("w", modifierFlags: .command)

        // Brief wait
        sleep(1)

        // No save sheet should appear - window should just close
        let saveSheet = app.sheets.firstMatch
        XCTAssertFalse(saveSheet.exists, "No save prompt should appear for unmodified document")
    }

    // MARK: - Clipboard Menu Tests

    @MainActor
    func testCopyMappedToMenuItemExists() throws {
        createNewDocument()
        addMapping()
        selectFirstMapping()

        // Open Edit menu
        let menuBar = app.menuBars.firstMatch
        let editMenu = menuBar.menuBarItems["Edit"]
        XCTAssertTrue(editMenu.waitForExistence(timeout: 3), "Edit menu should exist")
        editMenu.click()

        // Look for Copy Mapped to menu item
        let copyMappedTo = app.menuItems["Copy Mapped to"]
        XCTAssertTrue(copyMappedTo.waitForExistence(timeout: 2), "Copy Mapped to menu item should exist")

        // Press Escape to close menu
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testCopyModifiersMenuItemExists() throws {
        createNewDocument()
        addMapping()
        selectFirstMapping()

        // Open Edit menu
        let menuBar = app.menuBars.firstMatch
        let editMenu = menuBar.menuBarItems["Edit"]
        editMenu.click()

        // Look for Copy Modifiers menu item
        let copyModifiers = app.menuItems["Copy Modifiers"]
        XCTAssertTrue(copyModifiers.waitForExistence(timeout: 2), "Copy Modifiers menu item should exist")

        // Press Escape to close menu
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testPasteMenuItemsDisabledWhenClipboardEmpty() throws {
        createNewDocument()
        addMapping()
        selectFirstMapping()

        // Open Edit menu
        let menuBar = app.menuBars.firstMatch
        let editMenu = menuBar.menuBarItems["Edit"]
        editMenu.click()

        // Paste Mapped to should be disabled (nothing copied yet)
        let pasteMappedTo = app.menuItems["Paste Mapped to"]
        if pasteMappedTo.waitForExistence(timeout: 2) {
            XCTAssertFalse(pasteMappedTo.isEnabled, "Paste Mapped to should be disabled when clipboard is empty")
        }

        // Press Escape to close menu
        app.typeKey(.escape, modifierFlags: [])
    }

    @MainActor
    func testCopyPasteMappedToWorkflow() throws {
        createNewDocument()
        addMapping()
        addMapping() // Add second mapping

        // Select first mapping
        let table = app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 3))

        let rows = table.tableRows
        guard rows.count >= 2 else {
            XCTFail("Need at least 2 mappings for this test")
            return
        }

        // Select first row and copy
        rows.element(boundBy: 0).click()

        // Use keyboard shortcut to copy mapped to (Option+Cmd+C)
        app.typeKey("c", modifierFlags: [.command, .option])

        // Select second row
        rows.element(boundBy: 1).click()

        // Paste mapped to (Option+Cmd+V)
        app.typeKey("v", modifierFlags: [.command, .option])

        // If we get here without crash, the workflow works
        // (Verifying actual data would require accessing the model which isn't possible in UI tests)
    }

    @MainActor
    func testCopyPasteModifiersWorkflow() throws {
        createNewDocument()
        addMapping()
        addMapping() // Add second mapping

        let table = app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 3))

        let rows = table.tableRows
        guard rows.count >= 2 else {
            XCTFail("Need at least 2 mappings for this test")
            return
        }

        // Select first row and copy modifiers
        rows.element(boundBy: 0).click()

        // Use keyboard shortcut to copy modifiers (Shift+Cmd+C)
        app.typeKey("c", modifierFlags: [.command, .shift])

        // Select second row
        rows.element(boundBy: 1).click()

        // Paste modifiers (Shift+Cmd+V)
        app.typeKey("v", modifierFlags: [.command, .shift])

        // If we get here without crash, the workflow works
    }

    // MARK: - Launch Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
