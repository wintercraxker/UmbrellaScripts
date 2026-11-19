# MMR Tracker Ultimate

## 〢 💭 Overview

`MMRTracker_Ultimate.lua` is an on-screen MMR session tracker for Umbrella. It calculates current session wins, losses, MMR change, rank status, tilt conditions, and estimated games remaining.

## 〢 ✨ Features

- On-screen MMR panel
- Movable and lockable panel position
- Session win/loss and MMR tracking
- Persistent database-backed session values
- Session reset control
- Configurable average MMR gained or lost per game
- Optional game calculator
- Custom MMR target and rank-icon display
- Configurable tilt guard and alert threshold
- Match result detection and Steam ID/session handling

## 〢 📋 Requirements

- Umbrella Lua API
- Access to the Umbrella database API
- Access to game information, match-result, and draw APIs

## 〢 📥 Installation

Place `MMRTracker_Ultimate.lua` in the Umbrella client's `scripts` folder, reload scripts, and enable it under Scripts. See the [main installation guide](../README.md#-installation-guide).

## 〢 ⚙️ Configuration

- Enable the panel
- Lock or reset its position
- Set panel X/Y position
- Show or reset the session
- Set average MMR change
- Show the games calculator
- Set a custom target MMR
- Show rank icon
- Enable Tilt Guard and set its loss-limit threshold

## 〢 🎮 Usage

Enable the script from Umbrella and use the menu controls to display or reset the session. The panel can be locked or moved through the configured settings.

## 〢 📝 Notes

Menu text is partly in Russian and partly in English. The script stores session data using Umbrella's `db["x"]` database interface; MMR and match information availability depends on the client API.

## 〢 👤 Credits

Original author: Unknown. If you are the original creator, please open an issue to request proper attribution or removal.
