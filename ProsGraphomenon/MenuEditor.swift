//
//  MenuEditor.swift
//  ProsGraphomenon
//
//  Created by Bryan Forbes on 1/31/17.
//  Copyright © 2017 Bryan Forbes. All rights reserved.
//

import Foundation

class MenuEditor: NSViewController {
	@IBOutlet weak var outline: NSOutlineView!

	@IBOutlet weak var titleField: NSTextField!
	@IBOutlet var commandsView: NSTextView!
	@IBOutlet weak var addButton: NSButton!
	@IBOutlet weak var removeButton: NSButton!
	@IBOutlet var addMenu: NSMenu!

	var plistName: String?

	var menuData: [MenuItem] = []

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
		
		super.init(nibName: NSNib.Name(rawValue: "MenuEditorView"), bundle: bundle)
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
		commandsView.autoresizingMask = NSView.AutoresizingMask.none
		commandsView.maxSize = NSMakeSize(CGFloat.greatestFiniteMagnitude, CGFloat.greatestFiniteMagnitude)
		commandsView.isHorizontallyResizable = true
		commandsView.isVerticallyResizable = true
	}

	override func viewWillAppear() {
		super.viewWillAppear()

		if plistName != nil, let items = MenuParser.parse(plist: plistName!) {
			menuData = items
		} else {
			menuData = []
		}

		outline.reloadData()
	}

	@IBAction func onAddClick(_ sender: NSButton) {
		if let event = NSApplication.shared.currentEvent {
			NSMenu.popUpContextMenu(addMenu, with: event, for: sender)
		}
	}

	@IBAction func onRemoveClick(_ sender: NSButton) {
		/*let outlineItem = outline.item(atRow: outline.selectedRow)

		if let outlineItem = outline.item(atRow: outline.selectedRow) as? ProsMenuItem {

		}*/
	}

	fileprivate func addNewItem(item: MenuItem, index: Int, parent: MenuItem?) {
		if parent != nil {
			switch parent! {
			case .menu(_, var items):
				items.insert(item, at: index)
			default:
				break
			}
		} else {
			menuData.insert(item, at: index)
		}
		outline.insertItems(at: [ index ], inParent: parent, withAnimation: [ NSTableView.AnimationOptions.slideDown ])
	}

	@IBAction func onAddMenu(_ sender: NSMenuItem) {
		let outlineItem = outline.item(atRow: outline.selectedRow)

		let newMenu = MenuItem.menu(title: "New Menu", items: [])

		outline.beginUpdates()

		var parent: MenuItem?
		var index = 0

		if let item = outlineItem as? MenuItem {
			if outline.isItemExpanded(item) {
				parent = item
			} else {
				parent = outline.parent(forItem: item) as? MenuItem
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

extension MenuEditor: NSOutlineViewDelegate {
	func outlineView(_ outlineView: NSOutlineView, isGroupItem item: Any) -> Bool {
		return false
	}

	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
		if let menuItem = item as? MenuItem {
			let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "itemCell"), owner: self) as! NSTableCellView

			switch menuItem {
			case .command(let title, _),
			     .menu(let title, _):
				cell.textField?.stringValue = title
			case .separator:
				cell.textField?.stringValue = "-"
			}

			return cell
		}
		return nil
	}

	func outlineViewSelectionDidChange(_ notification: Notification) {
		let outlineItem = outline.item(atRow: outline.selectedRow)

		if let menuItem = outlineItem as? MenuItem {
			removeButton.isEnabled = true

			switch menuItem {
			case .command(let title, _),
			     .menu(let title, _):
				titleField.isEnabled = true
				titleField.stringValue = title
				commandsView.breakUndoCoalescing()
			default:
				break
			}

			switch menuItem {
			case .command(_, let commands):
				commandsView.string = commands.joined(separator: "\n")
				commandsViewEnabled = true
			default:
				commandsView.string = ""
				commandsViewEnabled = false
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

extension MenuEditor: NSOutlineViewDataSource {
	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
		if let menuItem = item as? MenuItem {
			switch menuItem {
			case .menu(_, _):
				return true
			default:
				break
			}
		}
		return false
	}

	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		if let menuItem = item as? MenuItem {
			switch menuItem {
			case .menu(_, let items):
				return items.count
			default:
				break
			}
		} else if item == nil {
			return menuData.count
		}
		return 0
	}

	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
		if let menuItem = item as? MenuItem {
			switch menuItem {
			case .menu(_, let items):
				return items[index]
			default:
				break
			}
		}
		return menuData[index]
	}
}
