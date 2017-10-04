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
	@IBOutlet weak var userField: NSTokenField!
	@IBOutlet weak var banMaskField: NSTokenField!

	let type: Type;

	enum `Type` {
		case Channel
		case User
	}

	init?(type: Type) {
		self.type = type

		let bundle = Bundle(identifier: "net.reigndropsfall.ProsGraphomenon")

		super.init(nibName: NSNib.Name(rawValue: "CommandEditorView"), bundle: bundle!)
	}

	required init?(coder: NSCoder) {
		self.type = .Channel

		super.init(coder: coder)
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		commandsTokenField.font = NSFont.userFixedPitchFont(ofSize: 0)

		userField.isHidden = type != .User
		banMaskField.isHidden = type != .User
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
