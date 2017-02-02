//
//  ProsMenuParser.swift
//  ProsGraphomenon
//
//  Created by Bryan Forbes on 1/31/17.
//  Copyright © 2017 Bryan Forbes. All rights reserved.
//

import Foundation

internal protocol ProsMenuItem {
	var type: String { get }
}

internal protocol ProsMenuItemTitled: ProsMenuItem {
	var title: String { get set }
}

internal class ProsMenu: ProsMenuItemTitled {
	let type: String = "menu"
	var title: String = ""
	var items: [ProsMenuItem] = []

	init(title: String, items: [ProsMenuItem] = []) {
		self.title = title
		self.items = items
	}

	fileprivate init(dict: [String:Any]) {
		self.title = dict["title"] as! String
		self.items = parseMenuItems(items: dict["items"] as! [[String:Any]])
	}
}

internal class ProsCommand: ProsMenuItemTitled {
	let type: String = "item"
	var title: String = ""
	var commands: [String] = []

	init(title: String, commands: [String] = []) {
		self.title = title
		self.commands = commands
	}

	fileprivate init(dict: [String:Any]) {
		self.title = dict["title"] as! String
		self.commands = dict["commands"] as! [String]
	}
}

internal class ProsSeparator: ProsMenuItem {
	let type: String = "separator"
}

fileprivate func parseMenuItems(items: [[String: Any]]) -> [ ProsMenuItem ] {
	return items.flatMap { item in
		guard let type = item["type"] as? String else {
			return nil
		}

		if type == "menu" {
			return ProsMenu(dict: item)
		} else if type == "item" {
			return ProsCommand(dict: item)
		} else if type == "separator" {
			return ProsSeparator()
		}

		return nil
	}
}

internal class ProsMenuParser {
	class func read(name: String) -> [ ProsMenuItem ]? {
		guard let items = getSupportPlist(name: name) else {
			return nil
		}

		return parseMenuItems(items: items)
	}
}
