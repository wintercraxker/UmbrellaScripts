# Phantom Lancer Illusion Controller

## 〢 💭 Overview

`pl_v2.lua` is an illusion-control utility for Phantom Lancer. It can manage Phantom Rush behavior, bait low-health illusions, follow the real hero, chase nearby enemies, bodyblock, retreat, and redirect split attacks.

## 〢 ✨ Features

- Auto Phantom Rush for controlled illusions
- Optional Illusion Rush control while farming
- Status display
- Rush and retreat distance settings
- Hold-key bait mode
- Auto-bait based on illusion health
- Auto-follow with configurable illusion count and radius
- Auto-chase
- Auto-bodyblock with ping threshold
- Force bodyblock key
- Auto-split attack with target count and enemy threshold

## 〢 📋 Requirements

- Umbrella Lua API
- Phantom Lancer
- The menu and API functions used in the source

## 〢 📥 Installation

Place `pl_v2.lua` in the Umbrella client's `scripts` folder, reload scripts, and enable it under the Phantom Lancer/General menu. See the [main installation guide](../../README.md#-installation-guide).

## 〢 ⚙️ Configuration

The script creates separate groups for main controls, illusions, settings, auto-bait, auto-follow, auto-chase, auto-split, and run-away behavior.

## 〢 🎮 Usage

Enable the desired modules and use the bait/bodyblock binds where configured. Most controls operate continuously while the script is enabled and Phantom Lancer is the local hero.

## 〢 📝 Notes

The source includes a comment describing its split and bodyblock logic as imperfect in some cases. Compatibility and in-game effectiveness may vary.

## 〢 👤 Credits

Original author: Unknown. The source thanks **qww**, **shz**, and other members of the `[ветра]` community. These names are preserved as source acknowledgements, not as confirmed original authorship.
