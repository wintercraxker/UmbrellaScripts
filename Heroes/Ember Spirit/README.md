# Ember Spirit Sticky Combo

## 〢 💭 Overview

`EMBERSCP.lua` provides a configurable Ember Spirit combo and escape helper under a separate Umbrella Heroes menu entry. It includes state-based targeting and sequences for Searing Chains, Sleight of Fist, Flame Guard, Fire Remnant, and Dancing Ember behavior.

## 〢 ✨ Features

- Cursor-based target acquisition and target locking
- Sticky-combo and Dancing Ember key binds
- Escape behavior using Blink direction, Sleight of Fist, and Fire Remnants
- Configurable ability and support-item use
- Sliders for targeting, timing, chase, and Remnant safety
- A target highlight and status panel
- Explicit blocking outside authorized map/lobby conditions

The script is designed to fail closed outside the documented hero-demo map. Public matchmaking is blocked, and private-lobby use requires the separate menu option to be enabled.

## 〢 📋 Requirements

- Umbrella's Lua API
- Ember Spirit
- The documented Umbrella API functions used by the script

The source identifies an integration with the Umbrella/UCZone API; compatibility with other or older builds is not guaranteed.

## 〢 📥 Installation

Move `EMBERSCP.lua` into the Umbrella client's `scripts` folder. Reload scripts and enable the entry from the Heroes menu. See the [main installation guide](../../README.md#-installation-guide).

## 〢 ⚙️ Configuration

The script creates an **Ember Spirit (кастом)** entry under Heroes and Hero List with settings for:

- Combo, Dancing Ember, and escape key binds
- Target mode and cursor acquisition radius
- Chase and decision timing
- Fire Remnant, activate, Flame Guard, Searing Chains, and Sleight of Fist
- Support items, including BKB, Satanic, Shiva's Guard, and selectable targeted items
- Escape destination, charge count, threat scan radius, and Remnant waiting behavior
- Target and display options

Use of the Umbrella built-in Ember Spirit combo should be disabled if both scripts use the same key.

## 〢 🎮 Usage

Enable the script, bind a combo key, and hold it to start the configured state machine. The escape key and Dancing Ember key operate separately. Target selection follows the cursor unless configured to use lock behavior.

## 〢 📝 Notes

- The source explicitly describes hero-demo-only default authorization.
- Private-lobby use is opt-in and labeled unsafe.
- Public matchmaking and undetermined lobby types remain blocked by the script logic.
- The script should not be assumed to be tested against every Dota 2 or Umbrella build.

## 〢 👤 Credits

Original author: Unknown. If you are the original creator, please open an issue to request proper attribution or removal.
