# Timbersaw Combo

## 〢 💭 Overview

`timbersaw_combo.lua` provides a held-key combo for Timbersaw. It finds a suitable tree, casts Timber Chain, Blinks behind or near the cursor-selected enemy, uses selected items, and can cast Chakram.

## 〢 ✨ Features

- Enable switch and configurable combo key
- Multi-select item usage
- Blink, Timber Chain, selectable items, and Chakram sequence
- Farthest reachable-tree selection
- Enemy and behind-target position selection
- Bounded retries for linked abilities
- Compact on-screen combo toast

## 〢 📋 Requirements

- Umbrella Lua API
- Timbersaw
- A ready Timber Chain ability
- Optional Blink Dagger variants and selected combo items

## 〢 📥 Installation

Place `timbersaw_combo.lua` in the Umbrella client's `scripts` folder, reload scripts, and enable it under Heroes. See the [main installation guide](../../README.md#-installation-guide).

## 〢 ⚙️ Configuration

The **BOOM COMBO** menu provides an enable switch, combo key, and item-usage selection for BKB, Hex, Bloodthorn, Orchid, Nullifier, Lotus Orb, Ethereal Blade, Veil, Dagon, Spirit Vessel, Urn, Gleipnir, Rod of Atos, Heaven's Halberd, Phase Boots, Drums, Disperser, and Soul Ring.

## 〢 🎮 Usage

Hold the combo key after selecting an enemy near the cursor. The script executes the fixed state sequence and remains active until the bounded attempt window completes.

## 〢 📝 Notes

The source derives from the same Lua API pattern mentioned in its header as the Techies combo helper. Compatibility with the exact Umbrella build and current Dota 2 patch is not verified.

## 〢 👤 Credits

Original author: Unknown. If you are the original creator, please open an issue to request proper attribution or removal.
