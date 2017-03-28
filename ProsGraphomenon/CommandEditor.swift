//
//  CommandEditor.swift
//  ProsGraphomenon
//
//  Created by Bryan Forbes on 3/27/17.
//  Copyright © 2017 Bryan Forbes. All rights reserved.
//

import Foundation

class CommandEditor: NSViewController {
	@IBOutlet weak var titleTextField: NSTextField!
	@IBOutlet weak var commandsTokenField: NSTokenField!

	@IBOutlet weak var meTokenField: NSTokenField!
	@IBOutlet weak var channelTokenField: NSTokenField!
	@IBOutlet weak var boldTokenField: NSTokenField!
	@IBOutlet weak var italicTokenField: NSTokenField!
	@IBOutlet weak var underlineTokenField: NSTokenField!
	@IBOutlet weak var colorTokenField: NSTokenField!
	@IBOutlet weak var resetTokenField: NSTokenField!
	@IBOutlet weak var promptTokenField: NSTokenField!

	class func create() -> CommandEditor? {
		if let bundle = Bundle(identifier: "net.reigndropsfall.ProsGraphomenon"),
			let editor = CommandEditor(nibName: "CommandEditorView", bundle: bundle) {
			return editor
		}
		return nil
	}
}

extension CommandEditor: NSTokenFieldDelegate {
	func tokenField(_ tokenField: NSTokenField, readFrom pboard: NSPasteboard) -> [Any]? {
		return nil
	}

	func tokenField(_ tokenField: NSTokenField, writeRepresentedObjects objects: [Any], to pboard: NSPasteboard) -> Bool {
		return false
	}
}
