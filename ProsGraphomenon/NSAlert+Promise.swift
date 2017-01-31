//
//  NSAlert+Promise.swift
//  ProsScripts
//
//  Created by Bryan Forbes on 1/18/17.
//  Copyright © 2017 AOMin. All rights reserved.
//

import Foundation
import PromiseKit

extension NSAlert {
	func beginSheetModal(for window: NSWindow) -> Promise<NSModalResponse> {
		return PromiseKit.wrap {
			self.beginSheetModal(for: window, completionHandler: $0)
		}
	}
}
