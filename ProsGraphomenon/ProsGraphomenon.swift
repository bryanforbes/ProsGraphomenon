//
//  ProsGraphomenon.swift
//  ProsGraphomenon
//
//  Created by Bryan Forbes on 1/30/17.
//  Copyright © 2017 Bryan Forbes. All rights reserved.
//

import Foundation
import PromiseKit
import Regex

internal struct Token {
	var text: String
}

internal func getSupportDirectory() -> URL? {
	guard let path = TPCPathInfo.applicationSupportFolderPathInLocalContainer() else {
		return nil
	}

	let url = URL(fileURLWithPath: path, isDirectory: true)
	return url.appendingPathComponent("ProsGraphomenon", isDirectory: true)
}

internal func getSupportPlist(name: String) -> [[String: Any]]? {
	let fm = FileManager()

	guard let supportDir = getSupportDirectory() else {
		return nil
	}

	if !fm.directoryExists(atPath: supportDir.path) {
		try! fm.createDirectory(at: supportDir, withIntermediateDirectories: true, attributes: nil)
	}

	let plistUrl = supportDir.appendingPathComponent(name).appendingPathExtension("plist")

	if !fm.fileExists(atPath: plistUrl.path) {
		return nil
	}

	return NSArray(contentsOf: plistUrl) as! [[String: Any]]?
}

fileprivate enum CommandType {
	case User
	case Channel
}

class ProsGraphomenonPrincipalClass: NSObject, THOPluginProtocol {
	fileprivate var varsRE = "%(%)|%([^%]+)%".r!
	fileprivate var colorsRE = try! Regex(pattern: "^color\\((\\d+)(?:, *(\\d+))?\\)$", groupNames: "fg", "bg")

	fileprivate var menuController: TXMenuController? {
		get {
			return masterController().menuController
		}
	}

	func pluginLoadedIntoMemory() {
		if let usersPlist = getSupportPlist(name: "UsersMenu"),
			let menu = menuController?.userControlMenu {
			addMenuItems(type: .User, menu: menu, items: usersPlist)
		}
		if let channelPlist = getSupportPlist(name: "ChannelMenu"),
			let menu = menuController?.channelViewDefaultMenu {
			addMenuItems(type: .Channel, menu: menu, items: channelPlist)
		}
	}

	@objc func handleCommand(sender: NSMenuItem) {
		guard let (type, templates) = sender.representedObject as? (CommandType, [Any]),
			let client = menuController?.selectedClient,
			let channel = menuController?.selectedChannel else {
				return
		}

		var commands: [String]? = nil

		switch type {
		case .User:
			commands = menuController!.selectedMembers(sender).flatMap { channelUser in
				return getCommands(templates: templates) { token -> String in
					return getUserCommands(token: token, client: client, channel: channel, user: channelUser.user)
				}
			}
		case .Channel:
			commands = getCommands(templates: templates) { token -> String in
				return getChannelCommands(token: token, client: client, channel: channel)
			}
		}

		if commands != nil {
			commands!.forEach { command in
				performBlock(onMainThread: {
					client.sendCommand(command)
				})
			}
		}
	}

	fileprivate func addMenuItems(type commandType: CommandType, menu: NSMenu, items: [[String: Any]]) {
		items.forEach { dict in
			guard let itemType = dict["type"] as? String,
				let title = dict["title"] as? String else {
					return
			}

			var menuItem: NSMenuItem? = nil;

			if itemType == "menu", let subItems = dict["items"] as? [[String: Any]] {
				let subMenu = NSMenu(title: title)

				addMenuItems(type: commandType, menu: subMenu, items: subItems)

				menuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
				menuItem!.submenu = subMenu
			} else if itemType == "item", let commandsValue = dict["commands"] {
				if let command = commandsValue as? String {
					addCommandItem(menu: menu, title: title, type: commandType, command: command)
				} else if let commands = commandsValue as? [String] {
					addCommandItem(menu: menu, title: title, type: commandType, commands: commands)
				}
			}

			if menuItem != nil {
				menu.addItem(menuItem!)
			}
		}
	}

	fileprivate func addCommandItem(menu: NSMenu, title: String, type commandType: CommandType, commands: [String]) {
		let item = NSMenuItem(title: title, target: self, action: #selector(ProsGraphomenonPrincipalClass.handleCommand(sender:)))

		let replaced = commands.map { command -> Any in
			let template = command.split(using: varsRE).enumerated().map { (index, text) -> Any in
				if index % 2 == 0 {
					return text
				}

				switch text {
				case "%": return text
				case "bold": return "\u{2}"
				case "italic": return "\u{1d}"
				case "underline": return "\u{1f}"
				case "end": return "\u{f}"
				case let color where color =~ "^color\\(":
					guard let match = colorsRE.findFirst(in: color),
						let fg = match.group(named: "fg") else {
							fallthrough
					}

					var bg = "0"

					if let possibleBg = match.group(named: "bg") {
						bg = possibleBg
					}

					return "\u{3}\(fg),\(bg)"
				default:
					return Token(text: text)
				}
			}

			if let strings = template as? [String] {
				return strings.joined(separator: "")
			}

			return template
		}

		item.representedObject = (commandType, replaced)
		menu.addItem(item)
	}

	fileprivate func addCommandItem(menu: NSMenu, title: String, type commandType: CommandType, command: String) {
		addCommandItem(menu: menu, title: title, type: commandType, commands: [ command ])
	}

	fileprivate func getCommands(templates: [Any], transform: (Token) -> String) -> [String] {
		if let strings = templates as? [String] {
			return strings
		}

		return templates.map { template -> String in
			guard let parts = template as? [Any] else {
				return template as! String
			}

			let transformed = parts.map { part -> String in
				guard let token = part as? Token else {
					return part as! String
				}

				return transform(token)
			}

			return transformed.joined(separator: "")
		}
	}

	fileprivate func getUserCommands(token: Token, client: IRCClient, channel: IRCChannel, user: IRCUser) -> String {
		switch token.text {
		case "user": return user.nickname
		case "banmask": return user.banMask
		default: return replaceCommonVars(token: token, client: client, channel: channel)
		}
	}

	fileprivate func getChannelCommands(token: Token, client: IRCClient, channel: IRCChannel) -> String {
		switch token.text {
		default: return replaceCommonVars(token: token, client: client, channel: channel)
		}
	}

	fileprivate func replaceCommonVars(token: Token, client: IRCClient, channel: IRCChannel) -> String {
		switch token.text {
		case "channel": return channel.name
		case "me": return client.userNickname
		default: return "Token(\(token.text))"
		}
	}
}
