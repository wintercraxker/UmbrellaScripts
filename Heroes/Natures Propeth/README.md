# Nature's Prophet Treant Block

## 〢 💭 Overview

`furion_treant_block.lua` provides a localized Treant block-control menu for Nature's Prophet. The source includes English, Russian, and Chinese menu definitions and configurable icon/debug presentation.

## 〢 ✨ Features

- Enable switch and configurable key
- Hold or press behavior
- Optional visual icons
- Icon size and height sliders
- Debug switch
- English, Russian, and Chinese localization

## 〢 📋 Requirements

- Umbrella Lua API
- Nature's Prophet
- The localization library `qLocalization`

The source does not identify a separate dependency file, but the `qLocalization.new` implementation is embedded in this Lua file.

## 〢 📥 Installation

Place `furion_treant_block.lua` in the Umbrella client's `scripts` folder, reload scripts, and enable it under the Heroes menu. See the [main installation guide](../../README.md#-installation-guide).

## 〢 ⚙️ Configuration

The script provides localized options for enable state, key binding, hold mode, icon display, icon size, icon height, and debug output.

## 〢 🎮 Usage

Enable the script and assign or activate the configured key. Hold or press behavior follows the menu setting.

## 〢 📝 Notes

Detailed in-game behavior is state-based and may depend on the Umbrella API version. The script has not been independently verified for every Dota 2 build.

## 〢 👤 Credits

Original author: **qfun (qfun_g9s)**. This attribution is preserved from the source header.
