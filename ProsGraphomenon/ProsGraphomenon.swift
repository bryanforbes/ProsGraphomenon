//
//  ProsGraphomenon.swift
//  ProsGraphomenon
//
//  Created by Bryan Forbes on 1/30/17.
//  Copyright © 2017 Bryan Forbes. All rights reserved.
//

import Foundation
import PromiseKit

internal struct Token {
	var text: String
}

internal enum ProsError: Error {
	case PromptCancel
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

internal func asyncMap<T, U>(items: [T], transform: @escaping (_ item: T) -> Promise<U>) -> Promise<[U]> {
	return items.reduce(Promise(value: Array<U>()), { lastPromise, item in
		return lastPromise.then(execute: { result in
			return transform(item).then(execute: { transformed in
				return result + [transformed]
			})
		})
	})
}

class PrincipalClass: NSObject, THOPluginProtocol {
	/*var pluginPreferencesPaneMenuItemName: String = "ProsGraphomenon"
	var pluginPreferencesPaneView: NSView {
		get {
			return prefsController.view
		}
	}

	fileprivate var prefsController: Preferences*/

	var subscribedUserInputCommands: [String] {
		get {
			return ["say"]
		}
	}

	fileprivate var menuController: TXMenuController? {
		get {
			return masterController().menuController
		}
	}

	/*override init() {
		let bundle = Bundle(identifier: "net.reigndropsfall.ProsGraphomenon")!
		prefsController = Preferences(nibName: "PreferencesView", bundle: bundle)!

		super.init()
	}*/

	func pluginLoadedIntoMemory() {
		if let menu = menuController?.userControlMenu,
			let usersItems = MenuParser.parse(plist: "UsersMenu") {
			menu.addItem(NSMenuItem.separator())
			addMenuItems(type: .User, menu: menu, items: usersItems)
		}
		if let menu = menuController?.channelViewDefaultMenu,
			let channelItems = MenuParser.parse(plist: "ChannelMenu") {
			menu.addItem(NSMenuItem.separator())
			addMenuItems(type: .Channel, menu: menu, items: channelItems)
		}
	}

	func userInputCommandInvoked(on client: IRCClient, command commandString: String, messageString: String) {
		let mainWindow = masterController().mainWindow

		if commandString == "SAY" {
			performBlock(onMainThread: {
				client.sendPrivmsg(messageString, to: mainWindow.selectedChannel!)
			})
		}
	}

	dynamic func handleCommand(sender: NSMenuItem) {
		guard let (type, templates) = sender.representedObject as? (CommandType, [Template]),
			let client = menuController?.selectedClient,
			let channel = menuController?.selectedChannel else {
				return
		}

		var commands: Promise<[String]>? = nil

		switch type {
		case .User:
			commands = asyncMap(items: menuController!.selectedMembers(sender), transform: { channelUser in
				return self.getCommands(templates: templates, transform: { (name, parameter) in
					if parameter != nil {
						return self.replaceParameterized(name: name, parameter: parameter!)
					} else {
						return self.replaceUserVars(key: name, client: client, channel: channel, user: channelUser.user)
					}
				})
			}).then(execute: { commands in
				return commands.flatMap({ commands in commands })
			})
		case .Channel:
			commands = getCommands(templates: templates) { (name, parameter) in
				if parameter != nil {
					return self.replaceParameterized(name: name, parameter: parameter!)
				} else {
					return self.replaceChannelVars(key: name, client: client, channel: channel)
				}
			}
		}

		if commands != nil {
			let _ = commands!.then(execute: { commands in
				self.runCommands(client: client, commands: commands)
			}).catch(execute: { error in
				return
			})
		}
	}

	fileprivate func runCommands(client: IRCClient, commands: [String]) {
		commands.forEach { command in
			performBlock(onMainThread: {
				client.sendCommand(command)
			})
		}
	}

	fileprivate func addMenuItems(type commandType: CommandType, menu: NSMenu, items: [MenuItem]) {
		items.forEach { item in
			switch item {
			case .menu(let title, let items):
				let subMenu = NSMenu(title: title)

				addMenuItems(type: commandType, menu: subMenu, items: items)

				let subMenuItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
				subMenuItem.submenu = subMenu
				menu.addItem(subMenuItem)
			case .command(let title, let commands):
				let commandItem = NSMenuItem(title: title, target: self, action: #selector(PrincipalClass.handleCommand(sender:)))
				let commandTemplates = commands.map({ command in Template(templateString: command) })
				commandItem.representedObject = (commandType, commandTemplates)
				menu.addItem(commandItem)
			case .separator:
				menu.addItem(NSMenuItem.separator())
			}
		}
	}

	fileprivate func getCommands(templates: [Template], transform: @escaping (String, String?) -> Promise<String?>) -> Promise<[String]> {
		return asyncMap(items: templates, transform: { template in
			return template.render(callback: transform)
		})
	}

	fileprivate func replaceParameterized(name: String, parameter: String) -> Promise<String?> {
		var value: String? = nil

		switch name {
		case "color":
			let colors = parameter.components(separatedBy: ",").map({ c in c.trimmingCharacters(in: .whitespaces) })
			if colors.count > 0 {
				let fg = Int(colors[0])!
				value = String(format: "\u{3}%02d", fg)

				if colors.count > 1 {
					let bg = Int(colors[1])!
					value = String(format: "\(value!),%02d", bg)
				}
			}
		case "prompt":
			return displayCommandPrompt(messageText: parameter)
		default:
			break
		}

		return Promise(value: value)
	}

	fileprivate func replaceUserVars(key: String, client: IRCClient, channel: IRCChannel, user: IRCUser) -> Promise<String?> {
		var value: String? = nil

		switch key {
		case "user": value = user.nickname
		case "banmask": value = user.banMask
		default: return self.replaceCommonVars(key: key, client: client, channel: channel)
		}

		return Promise(value: value)
	}

	fileprivate func replaceChannelVars(key: String, client: IRCClient, channel: IRCChannel) -> Promise<String?> {
		return self.replaceCommonVars(key: key, client: client, channel: channel)
	}

	fileprivate func replaceCommonVars(key: String, client: IRCClient, channel: IRCChannel) -> Promise<String?> {
		var value: String? = nil

		switch key {
		case "bold": value = "\u{2}"
		case "italic": value = "\u{1d}"
		case "underline": value = "\u{1f}"
		case "end": value = "\u{f}"
		case "color": value = "\u{3}"
		case "channel": value = channel.name
		case "me": value = client.userNickname
		default: break
		}

		return Promise(value: value)
	}

	fileprivate func displayCommandPrompt(messageText: String) -> Promise<String?> {
		return Promise(resolvers: { resolve, reject in
			DispatchQueue.main.async {
				let alert = NSAlert()
				alert.messageText = messageText
				alert.addButton(withTitle: "Ok")
				alert.addButton(withTitle: "Cancel")

				let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
				alert.accessoryView = input

				alert.beginSheetModal(for: self.masterController().mainWindow, completionHandler: { response in
					if response == NSAlertFirstButtonReturn {
						resolve(input.stringValue)
					} else {
						reject(ProsError.PromptCancel)
					}
				})
			}
		})
	}
}
