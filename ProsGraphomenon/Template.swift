//
//  Template.swift
//  ProsGraphomenon
//
//  Created by Bryan Forbes on 2/19/17.
//  Copyright © 2017 Bryan Forbes. All rights reserved.
//

import Foundation
import PromiseKit

internal class Template {
	fileprivate let delimiters = VariableDelimiters(start: "${", end: "}")
	fileprivate let nodes: [TemplateASTNode]

	init(templateString: String) {
		nodes = TemplateParser.parse(templateString: templateString)
	}

	func render(callback: @escaping (String, String?) -> Promise<String?>) -> Promise<String> {
		return asyncMap(items: nodes, transform: { node in
			switch node {
			case .textNode(let text):
				return Promise(value: text)
			case .substitutionNode(let name):
				return callback(name, nil)
			case .parameterizedNode(let name, let parameter):
				return callback(name, parameter)
			}
		}).then { values in
			return values.flatMap({ value in value }).joined(separator: "")
		}
	}
}

fileprivate class TemplateParser {
	class func parse(templateString: String) -> [TemplateASTNode] {
		var state: State = .start
		var nodes: [TemplateASTNode] = []

		let delimiters = VariableDelimiters(start: "${", end: "}")

		let atString = { (index: String.Index, string: String?) -> Bool in
			guard let string = string else {
				return false
			}
			return templateString[index...].hasPrefix(string)
		}

		var index = templateString.startIndex
		let endIndex = templateString.endIndex

		let advanceEscaped = { (character: Character) -> Bool in
			if character == "\\" {
				let next = templateString.index(after: index)
				if atString(next, "\\") {
					index = templateString.index(next, offsetBy: 1)
					return true
				} else if atString(next, delimiters.start) {
					index = templateString.index(next, offsetBy: delimiters.startLength)
					return true
				} else if atString(next, delimiters.end) {
					index = templateString.index(next, offsetBy: delimiters.endLength)
					return true
				}
			}
			return false
		}

		while (index < endIndex) {
			let character = templateString[index]

			switch state {
			case .start:
				if atString(index, delimiters.start) {
					index = templateString.index(index, offsetBy: delimiters.startLength)
					state = .substitution(startIndex: index)
					continue
				} else {
					state = .text(startIndex: index)

					if advanceEscaped(character) {
						continue
					}
				}
			case .substitution(let startIndex):
				if character == ":" {
					let name = templateString[startIndex..<index]
					index = templateString.index(after: index)
					state = .parameterized(startIndex: index, name: String(name))
					continue
				} else if atString(index, delimiters.end) {
					if startIndex != index {
						nodes.append(TemplateASTNode.substitution(name: String(templateString[startIndex..<index])))
					}
					index = templateString.index(index, offsetBy: delimiters.endLength)
					state = .start
					continue
				} else if advanceEscaped(character) {
					continue
				}
			case .parameterized(let startIndex, let name):
				if atString(index, delimiters.end) {
					if startIndex != index {
						nodes.append(TemplateASTNode.parameterized(name: name, parameter: String(templateString[startIndex..<index])))
					}
					index = templateString.index(index, offsetBy: delimiters.endLength)
					state = .start
					continue
				} else if advanceEscaped(character) {
					continue
				}
			case .text(let startIndex):
				if atString(index, delimiters.start) {
					if startIndex != index {
						nodes.append(TemplateASTNode.text(text: String(templateString[startIndex..<index]), delimiters: delimiters))
					}
					index = templateString.index(index, offsetBy: delimiters.startLength)
					state = .substitution(startIndex: index)
					continue
				} else if advanceEscaped(character) {
					continue
				}
			}

			index = templateString.index(after: index)
		}

		switch state {
		case .start:
			break
		case .text(let startIndex):
			nodes.append(TemplateASTNode.text(text: String(templateString[startIndex..<endIndex]), delimiters: delimiters))
		default:
			break
		}

		return nodes
	}

	fileprivate enum State {
		case start
		case text(startIndex: String.Index)
		case substitution(startIndex: String.Index)
		case parameterized(startIndex: String.Index, name: String)
	}
}

fileprivate struct VariableDelimiters {
	let start: String
	let startLength: Int
	let end: String
	let endLength: Int

	init(start: String, end: String) {
		self.start = start
		self.end = end

		startLength = start.characters.distance(from: start.startIndex, to: start.endIndex)
		endLength = end.characters.distance(from: end.startIndex, to: end.endIndex)
	}
}

fileprivate enum TemplateASTNode {
	case textNode(String)
	case substitutionNode(String)
	case parameterizedNode(String, String)

	static func text(text: String, delimiters: VariableDelimiters) -> TemplateASTNode {
		return .textNode(
			text.replacingOccurrences(of: "\\\(delimiters.start)", with: delimiters.start)
				.replacingOccurrences(of: "\\\(delimiters.end)", with: delimiters.end)
				.replacingOccurrences(of: "\\\\", with: "\\")
		)
	}

	static func substitution(name: String) -> TemplateASTNode {
		return .substitutionNode(name)
	}

	static func parameterized(name: String, parameter: String) -> TemplateASTNode {
		return .parameterizedNode(name, parameter)
	}
}
