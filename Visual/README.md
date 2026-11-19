# Unusual Changer

## 〢 💭 Overview

`unusual.lua` applies unusual-style ambient effects to supported hero cosmetic items. It provides hero/item selection, in-game testing, and menu-preview controls.

## 〢 ✨ Available Scripts

| Script | Description | Documentation |
|---|---|---|
| [Unusual Changer](./unusual.lua) | Applies unusual-style ambient effects to supported cosmetic items, with test and preview controls. | [Lua source](./unusual.lua) |

## 〢 📥 Installation

Move the Lua file into the Umbrella client's `scripts` folder, reload scripts, and enable it in the Umbrella menu. See the [main installation guide](../README.md#-installation-guide).

## 〢 ✨ Features

- Hero and cosmetic-item selection
- Multiple unusual-style ambient effects
- Item slots and effects that can be configured separately
- In-game testing on one or multiple heroes
- Menu preview mode
- Option to include hidden items
- Support for many named hero cosmetics

## 〢 📋 Requirements

- Umbrella Lua API
- Cosmetic items supported by the script's item table
- Access to particle and cosmetic-preview APIs

## 〢 ⚙️ Configuration

- Enable the changer
- Select one hero
- Enable individual cosmetic items
- Assign an unusual effect to each item
- Configure test-on-any-hero, item slot, effect, and hidden-item options
- Configure menu-preview slot, effect, and hidden-item options

## 〢 🎮 Usage

Enable the script and select a supported hero. Enable the desired cosmetic item and choose an effect from its gear menu. Test and preview switches provide separate testing modes.

## 〢 📝 Notes

The script menu is in Russian, while item and hero names remain in the source's original text. Supported item data is embedded in `unusual.lua`; compatibility may vary with cosmetic and patch updates.

## 〢 👤 Credits

Source header: **flatixxx**.