//
//  ProsMenuEditor.swift
//  ProsGraphomenon
//
//  Created by Bryan Forbes on 1/31/17.
//  Copyright © 2017 Bryan Forbes. All rights reserved.
//

import Foundation

class ProsMenuEditor: NSViewController {
	@IBOutlet weak var outline: NSOutlineView!

	@IBOutlet weak var titleField: NSTextField!
	@IBOutlet var commandsView: NSTextView!
	@IBOutlet weak var addButton: NSButton!
	@IBOutlet weak var removeButton: NSButton!
	@IBOutlet var addMenu: NSMenu!

	var plistName: String?

	var menuData: [ ProsMenuItem ] = []

	var commandsViewEnabled: Bool {
		get {
			return commandsView.isEditable
		}

		set(value) {
			commandsView.isEditable = value
			commandsView.isSelectable = value
			commandsView.scrollView!.borderType = value ? .bezelBorder : .noBorder
		}
	}

	init?(plistName: String) {
		self.plistName = plistName

		let bundle = Bundle(identifier: "net.reigndropsfall.ProsGraphomenon")!
		
		super.init(nibName: "MenuEditorView", bundle: bundle)
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		outline.headerView = nil

		removeButton.isEnabled = false

		titleField.isEnabled = false

		commandsViewEnabled = false

		commandsView.font = NSFont.userFixedPitchFont(ofSize: 0)
		commandsView.textContainer!.containerSize = NSMakeSize(CGFloat.greatestFiniteMagnitude, CGFloat.greatestFiniteMagnitude)
		commandsView.textContainer!.widthTracksTextView = false
		commandsView.textContainer!.heightTracksTextView = false
		commandsView.autoresizingMask = .viewNotSizable
		commandsView.maxSize = NSMakeSize(CGFloat.greatestFiniteMagnitude, CGFloat.greatestFiniteMagnitude)
		commandsView.isHorizontallyResizable = true
		commandsView.isVerticallyResizable = true
	}

	override func viewWillAppear() {
		super.viewWillAppear()

		if plistName != nil, let items = ProsMenuParser.read(name: plistName!) {
			menuData = items
		} else {
			menuData = []
		}

		outline.reloadData()
	}

	@IBAction func onAddClick(_ sender: NSButton) {
		if let event = NSApplication.shared().currentEvent {
			NSMenu.popUpContextMenu(addMenu, with: event, for: sender)
		}
	}

	@IBAction func onRemoveClick(_ sender: NSButton) {
		/*let outlineItem = outline.item(atRow: outline.selectedRow)

		if let outlineItem = outline.item(atRow: outline.selectedRow) as? ProsMenuItem {

		}*/
	}

	fileprivate func addNewItem(item: ProsMenuItem, index: Int, parent: ProsMenu?) {
		if parent != nil {
			parent!.items.insert(item, at: index)
		} else {
			menuData.insert(item, at: index)
		}
		outline.insertItems(at: [ index ], inParent: parent, withAnimation: [ .slideDown ])
	}

	@IBAction func onAddMenu(_ sender: NSMenuItem) {
		let outlineItem = outline.item(atRow: outline.selectedRow)

		let newMenu = ProsMenu(title: "New Menu")

		outline.beginUpdates()

		var parent: ProsMenu?
		var index = 0

		if let item = outlineItem as? ProsMenuItem {
			if outline.isItemExpanded(item) {
				parent = item as? ProsMenu
			} else {
				parent = outline.parent(forItem: item) as? ProsMenu
				index = outline.childIndex(forItem: item) + 1
			}
		}

		addNewItem(item: newMenu, index: index, parent: parent)

		outline.endUpdates()
	}

	@IBAction func onAddCommand(_ sender: NSMenuItem) {
	}

	@IBAction func onAddSeparator(_ sender: NSMenuItem) {
	}
}

extension ProsMenuEditor: NSOutlineViewDelegate {
	func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
		return false
	}

	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		if let menuItem = item as? ProsMenuItem {
			let cell = outlineView.make(withIdentifier: "itemCell", owner: self) as! NSTableCellView

			if let titledItem = menuItem as? ProsMenuItemTitled {
				cell.textField?.stringValue = titledItem.title
			} else {
				cell.textField?.stringValue = "-"
			}

			return cell
		}
		return nil
	}

	func outlineViewSelectionDidChange(_ notification: Notification) {
		let outlineItem = outline.item(atRow: outline.selectedRow)

		if let item = outlineItem as? ProsMenuItem {
			removeButton.isEnabled = true

			if let titled = item as? ProsMenuItemTitled {
				titleField.isEnabled = true
				titleField.stringValue = titled.title

				if let command = item as? ProsCommand {
					commandsView.breakUndoCoalescing()
					commandsView.string = command.commands.joined(separator: "\n")
					commandsViewEnabled = true
				} else {
					commandsView.breakUndoCoalescing()
					commandsView.string = ""
					commandsViewEnabled = false
				}
			}
		} else {
			removeButton.isEnabled = false
			titleField.stringValue = ""
			titleField.isEnabled = false
			commandsView.breakUndoCoalescing()
			commandsView.string = ""
			commandsViewEnabled = false
		}
	}
}

extension ProsMenuEditor: NSOutlineViewDataSource {
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		if item is ProsMenu {
			return true
		}
		return false
	}

	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		if let menu = item as? ProsMenu {
			return menu.items.count;
		} else if item == nil {
			return menuData.count
		}
		return 0
	}

	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		if let menu = item as? ProsMenu {
			return menu.items[index]
		}
		return menuData[index]
	}
}
