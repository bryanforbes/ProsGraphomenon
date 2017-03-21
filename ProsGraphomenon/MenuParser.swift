//
//  MenuParser.swift
//  ProsGraphomenon
//
//  Created by Bryan Forbes on 1/31/17.
//  Copyright © 2017 Bryan Forbes. All rights reserved.
//

import Foundation

internal enum MenuItem {
	case menu(title: String, items: [MenuItem])
	case command(title: String, commands: [String])
	case separator
}

internal class MenuParser {
	class func parse(plist: String) -> [MenuItem]? {
		guard let items = getSupportPlist(name: plist) else {
			return nil
		}

		return MenuParser.parse(items: items)
	}

	class func parse(items: [[String:Any]]) -> [MenuItem] {
		return items.flatMap(MenuParser.parse(dictionary:))
	}

	class func parse(dictionary item: [String:Any]) -> MenuItem? {
		guard let type = item["type"] as? String else {
			return nil
		}

		switch type {
		case "menu":
			let subItems = MenuParser.parse(items: item["items"] as! [[String:Any]])
			return .menu(title: item["title"] as! String, items: subItems)
		case "item":
			return .command(title: item["title"] as! String, commands: item["commands"] as! [String])
		default:
			return .separator
		}
	}
}
