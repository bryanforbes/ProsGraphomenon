# ProsGraphomenon (toward scripting)

A plugin for [Textual](https://www.codeux.com/textual/) to add mIRC-like scripting capabilities.

## Features

* Customizable menus for the channel users list and channel view
* Executing multiple commands for users and channels from one menu item
* Ability to prompt the user for input

## TODO

* Aliases
* Command/alias editor
* Tests

## Building

* Clone this repository
* Run `carthage bootstrap --platform macOS`
* Open `ProsGraphomenon.xcodeproj` in Xcode
* Build the project (`Projects -> Build` or `⌘ B`)
* Right click on `ProsGraphomenon.bundle` in the Project Navigator and select `Show in Finder`
* Double click `ProsGraphomenon.bundle` in Finder
* Restart Textual

## Menu Plist Format

The root element of the menu plists must be an `<array>`. This array can contain three types of dictionaries: item, menu, or separator.

### Command Items

Command items execute commands. The dictionary **MUST** contain the following keys:

| Key      | Type     | Description                            |
| ---------|----------|----------------------------------------|
| type     | string   | **MUST** be "item"                     |
| title    | string   | The text of the menu item              |
| commands | array    | An array of strings of commands to run |

### Menu Items

Menu items display a sub-menu. The dictionary **MUST** contain the following keys:

| Key      | Type     | Description                            |
| ---------|----------|----------------------------------------|
| type     | string   | **MUST** be "menu"                     |
| title    | string   | The text of the menu item              |
| items    | array    | An array of dictionaries               |

### Separator Items

Separators display a horizontal line in a menu. The dictionary **MUST** contain the following keys:

| Key      | Type     | Description                            |
| ---------|----------|----------------------------------------|
| type     | string   | **MUST** be "separator"                |

## Command Syntax

TODO
