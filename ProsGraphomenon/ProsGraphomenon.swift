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

internal enum TextEffect: CustomStringConvertible {
	case bold
	case italic
	case underline
	case color(Int, Int)
	case end

	var description: String {
		switch self {
		case .bold:
			return "\u{2}"
		case .italic:
			return "\u{1d}"
		case .underline:
			return "\u{1f}"
		case .color(let fg, let bg):
			return "\u{3}\(fg),\(bg)"
		case .end:
			return "\u{f}"
		}
	}
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
	fileprivate var varsRE = "%%|%([^%]+)%".r!
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
		guard let (type, templates) = sender.representedObject as? (CommandType, [String]),
			let client = menuController?.selectedClient,
			let channel = menuController?.selectedChannel else {
				return
		}

		var commands: [String]? = nil

		switch type {
		case .User:
			commands = menuController!.selectedMembers(sender).flatMap { channelUser in
				return getUserCommands(client: client, channel: channel, user: channelUser.user, templates: templates)
			}
		case .Channel:
			commands = getChannelCommands(client: client, channel: channel, templates: templates)
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

		let replaced = commands.map { command -> String in
			return varsRE.replaceAll(in: command, using: formattingReplacer)
		}

		item.representedObject = (commandType, replaced)
		menu.addItem(item)
	}

	fileprivate func addCommandItem(menu: NSMenu, title: String, type commandType: CommandType, command: String) {
		addCommandItem(menu: menu, title: title, type: commandType, commands: [ command ])
	}

	fileprivate func formattingReplacer(match: Match) -> String? {
		guard let variable = match.group(at: 1) else {
			return "%%"
		}

		switch variable {
		case "bold": return TextEffect.bold.description
		case "italic": return TextEffect.italic.description
		case "underline": return TextEffect.underline.description
		case "end": return TextEffect.end.description
		case let color where color =~ "^color\\(.*\\)$":
			guard let match = colorsRE.findFirst(in: color),
				let fg = match.group(named: "fg") else {
					fallthrough
			}

			var bg = "0"

			if let possibleBg = match.group(named: "bg") {
				bg = possibleBg
			}

			return TextEffect.color(Int(fg)!, Int(bg)!).description
		default:
			return nil
		}
	}

	fileprivate func getUserCommands(client: IRCClient, channel: IRCChannel, user: IRCUser, templates: [String]) -> [String] {
		return templates.map { command -> String in
			return varsRE.replaceAll(in: command) { match in
				guard let variable = match.group(at: 1) else {
					return "%"
				}

				switch variable {
				case "user": return user.nickname
				case "banmask": return user.banMask
				default: return replaceCommonVars(match: match, client: client, channel: channel)
				}
			}
		}
	}

	fileprivate func getChannelCommands(client: IRCClient, channel: IRCChannel, templates: [String]) -> [String] {
		return templates.map { command -> String in
			return varsRE.replaceAll(in: command) { match in
				guard let variable = match.group(at: 1) else {
					return "%"
				}

				switch variable {
				default: return replaceCommonVars(match: match, client: client, channel: channel)
				}
			}
		}
	}

	fileprivate func replaceCommonVars(match: Match, client: IRCClient, channel: IRCChannel) -> String? {
		switch match.group(at: 1)! {
		case "channel": return channel.name
		case "me": return client.userNickname
		default: return nil
		}
	}
}
