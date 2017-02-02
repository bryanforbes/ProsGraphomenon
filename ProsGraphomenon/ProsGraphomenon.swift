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
	var pluginPreferencesPaneMenuItemName: String = "ProsGraphomenon"
	var pluginPreferencesPaneView: NSView {
		get {
			return prefsController.view
		}
	}

	fileprivate var prefsController: ProsPreferences
	fileprivate var varsRE = "%(%)|%([^%]+)%".r!
	fileprivate var colorsRE = try! Regex(pattern: "^color\\((\\d+)(?:, *(\\d+))?\\)$", groupNames: "fg", "bg")

	fileprivate var menuController: TXMenuController? {
		get {
			return masterController().menuController
		}
	}

	override init() {
		let bundle = Bundle(identifier: "net.reigndropsfall.ProsGraphomenon")!
		prefsController = ProsPreferences(nibName: "PreferencesView", bundle: bundle)!

		super.init()
	}

	func pluginLoadedIntoMemory() {
		if let menu = menuController?.userControlMenu,
			let usersItems = ProsMenuParser.read(name: "UsersMenu") {
			menu.addItem(NSMenuItem.separator())
			addMenuItems(type: .User, menu: menu, items: usersItems)
		}
		if let menu = menuController?.channelViewDefaultMenu,
			let channelItems = ProsMenuParser.read(name: "ChannelMenu") {
			addMenuItems(type: .Channel, menu: menu, items: channelItems)
		}
	}

	dynamic func handleCommand(sender: NSMenuItem) {
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

	fileprivate func addMenuItems(type commandType: CommandType, menu: NSMenu, items: [ ProsMenuItem ]) {
		items.forEach { item in
			if let menuItem = item as? ProsMenu {
				let subMenu = NSMenu(title: menuItem.title)

				addMenuItems(type: commandType, menu: subMenu, items: menuItem.items)

				let subMenuItem = NSMenuItem(title: menuItem.title, action: nil, keyEquivalent: "")
				subMenuItem.submenu = subMenu
				menu.addItem(subMenuItem)
			} else if let commandItem = item as? ProsCommand {
				addCommandItem(menu: menu, type: commandType, commandItem: commandItem)
			} else if item is ProsSeparator {
				menu.addItem(NSMenuItem.separator())
			}
		}
	}

	fileprivate func addCommandItem(menu: NSMenu, type commandType: CommandType, commandItem: ProsCommand) {
		let item = NSMenuItem(title: commandItem.title, target: self, action: #selector(ProsGraphomenonPrincipalClass.handleCommand(sender:)))

		let replaced = commandItem.commands.map { command -> Any in
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
