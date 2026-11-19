# Server Region

## 〢 💭 Overview

`server_region.lua` identifies the current Dota 2 game-server region from lobby coordinator data and draws a configurable region indicator on screen.

## 〢 ✨ Features

- Lobby-region parsing
- Region-name localization
- Optional game-coordinator request after loading mid-match
- Configurable horizontal and vertical position
- Configurable scale
- Region status indicator
- Region code display when available

## 〢 📋 Requirements

- Umbrella Lua API
- Game-coordinator lobby message access
- `CSODOTALobby` parsing support
- Render and menu APIs

## 〢 📥 Installation

Place `server_region.lua` in the Umbrella client's `scripts` folder, reload scripts, and enable it under Scripts. See the [main installation guide](../README.md#-installation-guide).

## 〢 ⚙️ Configuration

- Enabled switch
- Position X and Y as percentages
- Scale percentage
- Ask the coordinator if loaded mid-match

## 〢 🎮 Usage

Enable the script and, if desired, configure its position and scale. The panel displays “locating” until lobby region data is available.

## 〢 📝 Notes

Region data is available from the lobby object sent by the game coordinator. The script does not guarantee that a lobby message can be obtained after joining through every match flow.

## 〢 👤 Credits

Original author: Unknown. If you are the original creator, please open an issue to request proper attribution or removal.
