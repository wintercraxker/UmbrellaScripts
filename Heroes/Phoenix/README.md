# Phoenix Supernova Survival Panel

## 〢 💭 Overview

`Phoenix_Supernova.lua` shows a configurable on-screen panel when Phoenix enters Supernova. It estimates whether the egg will survive incoming attacks and displays a verdict and progress information.

## 〢 ✨ Features

- Optional survival verdict panel
- Configurable panel size and position
- Configurable panel opacity
- Optional progress bar and subtext
- Attack timelines accounting for range, movement, turning, stun, hex, and disarm states
- Ranged projectile travel estimation

## 〢 📋 Requirements

- Umbrella Lua API
- Phoenix
- Access to Render, NPC, Ability, and related game APIs

## 〢 📥 Installation

Place `Phoenix_Supernova.lua` in the Umbrella client's `scripts` folder, reload scripts, and enable it under Heroes. See the [main installation guide](../../README.md#-installation-guide).

## 〢 ⚙️ Configuration

- Show if the egg can survive Supernova
- Panel size
- Horizontal and vertical offsets
- Opacity
- Progress bar
- Subtext

## 〢 🎮 Usage

Enable the panel and tune its position and size. The panel appears during Supernova and evaluates nearby enemy attackers.

## 〢 📝 Notes

The displayed result is an estimate based on source calculations, not a guaranteed survival prediction. Dota 2 patch changes can alter relevant values and behavior.

## 〢 👤 Credits

Original author: Unknown. If you are the original creator, please open an issue to request proper attribution or removal.
