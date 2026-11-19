# Invoker Auto Sun Strike

## 〢 💭 Overview

`Auto_Sunstrike_On_TP.lua` monitors enemy teleport actions and attempts to invoke and cast Sun Strike at an enemy's predicted arrival location.

## 〢 ✨ Features

- Enable/disable switch
- Adjustable teleport-arrival delay
- Exort/Invoke sequence for preparing Sun Strike
- Enemy teleport tracking
- Basic lethal-damage and health-regeneration estimation
- Arrival-time preparation and cancellation of stale targets

## 〢 📋 Requirements

- Umbrella Lua API
- Invoker
- The Exort and Invoke abilities
- Access to the repository's `LIB_HEROES_DATA` teleport information

The source depends on teleport library data and Umbrella API callbacks. Availability and compatibility are not verified for every client version.

## 〢 📥 Installation

Place `Auto_Sunstrike_On_TP.lua` in the Umbrella client's `scripts` folder, reload scripts, and enable it under the Invoker menu. See the [main installation guide](../../README.md#-installation-guide).

## 〢 ⚙️ Configuration

- **Use on teleport:** Enables automatic processing.
- **Teleport Arrive Delay:** Adjusts the target arrival time by zero to half a second.

## 〢 🎮 Usage

Enable the script and configure the arrival delay. When the script detects an enemy teleport, it acquires the target, prepares Sun Strike, and casts when the estimated arrival time and damage conditions are met.

## 〢 📝 Notes

The script uses a fixed Sun Strike travel estimate and approximate health prediction. This is a targeting aid, not a verified in-game success guarantee.

## 〢 👤 Credits

Original author: Unknown. If you are the original creator, please open an issue to request proper attribution or removal.
