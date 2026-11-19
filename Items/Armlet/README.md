# Smart Armlet Abuse

## 〢 💭 Overview

`smart_armlet_abuse.lua` dynamically adjusts Umbrella's built-in Armlet Abuse Health Threshold. It estimates nearby enemy threat and survival probability, but does not toggle Armlet directly.

## 〢 ✨ Features

- Adaptive threshold between configurable minimum and maximum values
- Estimated survival chance for the next one to two seconds
- Nearby hero, tower, summon, creep, and illusion damage analysis
- Critical-hit and ready ultimate/nuke sensitivity
- Draggable panel and compact indicator
- State notifications and top-of-screen toast notifications
- World-space danger-zone rings
- Built-in Armlet Abuse threshold discovery
- Debug output

## 〢 📋 Requirements

- Umbrella Lua API
- Armlet of Mordiggian
- Umbrella's built-in Armlet Abuse feature
- Access to Umbrella menu, render, entity, NPC, and network APIs

The script is designed to adjust a built-in threshold slider. It does not replace Umbrella's toggling implementation.

## 〢 📥 Installation

Place `smart_armlet_abuse.lua` in the Umbrella client's `scripts` folder, reload scripts, and enable it. See the [main installation guide](../../README.md#-installation-guide).

## 〢 ⚙️ Configuration

The script menu provides:

- Enable switch
- Analysis radius
- Base HP threshold
- Panel and toast switches
- Compact notifications
- World rings
- Compact panel hotkey
- Debug logging
- Survival-chance notification step
- Notify-on-state-change switch

The source also documents an explicit built-in slider path: Miscellaneous > In Game > Armlet Abuse > Main > Health Threshold. Menu-name variants are attempted if the exact path cannot be found.

## 〢 🎮 Usage

Enable Umbrella's built-in Armlet Abuse and then enable this script. The script recalculates the built-in threshold according to detected threats and draws optional status feedback.

## 〢 📝 Notes

- The script does not issue Armlet toggles.
- Damage values and patch-dependent timing are approximate and require user adjustment as Dota 2 changes.
- Compatibility depends on Umbrella exposing the expected threshold menu and API functions.
- The source does not claim that the estimates guarantee survival.

## 〢 👤 Credits

Original author: Unknown. If you are the original creator, please open an issue to request proper attribution or removal.
