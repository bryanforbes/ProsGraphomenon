//
//  Preferences.swift
//  ProsGraphomenon
//
//  Created by Bryan Forbes on 1/31/17.
//  Copyright © 2017 Bryan Forbes. All rights reserved.
//

import Foundation

class Preferences: NSViewController {
	@IBOutlet weak var usersView: NSView!
	@IBOutlet weak var channelView: NSView!

	var usersEditor: MenuEditor!
	var channelEditor: MenuEditor!

	override func viewDidLoad() {
		super.viewDidLoad()

		usersEditor = MenuEditor(plistName: "UsersMenu")
		channelEditor = MenuEditor(plistName: "ChannelMenu")

		addSubview(subview: usersEditor.view, to: usersView)
		addSubview(subview: channelEditor.view, to: channelView)
	}

	fileprivate func addSubview(subview: NSView, to: NSView) {
		to.subviews.removeAll()
		to.addSubview(subview)

		view.translatesAutoresizingMaskIntoConstraints = false

		let width = NSLayoutConstraint(item: subview, attribute: .width, relatedBy: .equal, toItem: to, attribute: .width, multiplier: 1.0, constant: 0)
		let height = NSLayoutConstraint(item: subview, attribute: .height, relatedBy: .equal, toItem: to, attribute: .height, multiplier: 1.0, constant: 0)
		let top = NSLayoutConstraint(item: subview, attribute: .top, relatedBy: .equal, toItem: to, attribute: .top, multiplier: 1.0, constant: 0)
		let leading = NSLayoutConstraint(item: subview, attribute: .leading, relatedBy: .equal, toItem: to, attribute: .leading, multiplier: 1.0, constant: 0)

		to.addConstraints([ width, height, top, leading ])
	}
}

