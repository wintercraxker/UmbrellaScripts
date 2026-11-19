# Huskar Life Break Combo

## 〢 💭 Overview

`huskar_life_break.lua` breaks or cancels Huskar's Life Break leap using Blink variants or Hurricane Pike. It supports English, Russian, and Chinese menu localization.

## 〢 ✨ Features

- Optional automatic Life Break combo key
- Life Break interruption with the first ready selected breaker item
- Manual Life Break interception
- Blink-away directions: target, cursor, ally, or fountain
- Configurable leap delay and Blink distance
- Optional stop order after impact
- Localized menu text and tooltips

## 〢 📋 Requirements

- Umbrella Lua API
- Huskar
- One or more supported items: Blink, Swift/Arcane/Overwhelming Blink, or Hurricane Pike

## 〢 📥 Installation

Place `huskar_life_break.lua` in the Umbrella client's `scripts` folder, reload scripts, and enable it under Heroes. See the [main installation guide](../../README.md#-installation-guide).

## 〢 ⚙️ Configuration

The Life Break menu provides:

- Enable switch
- Combo key
- Multi-select for leap-breaking items
- Blink direction
- Blink distance
- Delay after leap starts
- Automatic handling for manual Life Break
- Stop-after-hit behavior

## 〢 🎮 Usage

Bind the combo key and press it while cursor-targeting an enemy. If Life Break is already in progress, the script attempts to cancel it immediately with the configured item. The manual-Ultimate switch enables the same interruption logic without the bind.

## 〢 📝 Notes

The source relies on Umbrella and Dota 2 APIs for item readiness, unit modifiers, and order preparation. Behavior may vary by patch and client build.

## 〢 👤 Credits

Original author: Unknown. The source includes localization support attributed to the qLocalization library by **qfun (qfun_g9s)**.
