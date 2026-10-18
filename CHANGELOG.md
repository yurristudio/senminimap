# SenMinimap — Changelog & Guide

**Version:** 0.1.0  
**Author:** Yurri Gaming  
**Game target:** WoW Forever — Interface 16001  
**Release date:** 18 October 2026

This file replaces the README and documents the complete first release, its installation, controls and limitations.

## About SenMinimap

SenMinimap gives the live game minimap a square shape and a modern dark interface. A configurable status dock keeps the clock, mail, friends and day/night indicator together. Position, size, appearance and visibility are managed through the addon's own settings.

The addon uses the game's live minimap and tracking data. It does not replace map tiles or require external libraries, fonts or image downloads.

## Version 0.1.0 — First release

### Square minimap and appearance

- Square minimap mask with a dark frame and a thin accent line when the zone header is shown.
- Three accent palettes: Teal, Ice and Amber.
- Adjustable map size from 160 to 360 UI units.
- Adjustable overall scale from 0.65 to 1.50.
- Background opacity from fully transparent to opaque.
- Hide all backgrounds option covering the map frame, dock, borders, accent line, zone strip and SenMinimap button backgrounds.
- The map, labels and icons remain visible when backgrounds are hidden. The settings window and tracking menu retain their readable backgrounds.

### Zone name

- Show or hide the current zone name.
- Place the zone name in a header above the map or centered inside its bottom edge.
- The top header collapses when the zone name is hidden or placed inside the map.
- The inside-bottom label reserves space for controls on both sides. Long names may be truncated at small map sizes.

### Status dock

- Choose Top, Bottom, Left or Right.
- Horizontal docks fit the minimap's framed width.
- Side docks span the framed minimap's height and use the same 29-unit thickness as horizontal docks.
- The top dock sits immediately above the map when its header is collapsed, or above the zone header when enabled.
- Enabled modules share the available dock space. The dock disappears when all four modules are disabled.

#### Clock

- Server time by default, with an option to use local computer time.
- 24-hour display.
- Top/bottom docks use `HH:MM`.
- Left/right docks show larger hours above minutes on two centered lines.

#### Mail

- Show or hide the mail module.
- Choose a text label or envelope illustration.
- New mail highlights the text or icon.
- This is a status indicator; reading mail still requires a mailbox.

#### Friends

- Show or hide the friends module.
- Head illustration and online friend count.
- The count appears beside the icon in horizontal docks and below it in side docks.
- Clicking opens the game's friends window when its toggle API is available.
- The count covers in-game friends, excluding Battle.net friends. A question mark appears if the count API is unavailable.

#### Day and night

- Show or hide the module.
- Choose DAY/NIGHT text or sun/crescent illustrations.
- Warm gold sun and pale blue moon icons.
- Based on server time: day from 06:00 through 17:59, night otherwise. This is not a measurement of zone lighting or moon phases.

### Minimap controls

- Custom plus/minus zoom buttons at the bottom right, with a visibility option.
- Mouse-wheel zoom remains available when the zoom buttons are hidden.
- Binoculars button at the bottom left opens the tracking menu.
- Gold settings icon beside the binoculars toggles the settings window.
- Show/hide settings icon option; slash commands remain available when it is hidden.

### Tracking menu

- Custom compact dark popup to the right of the minimap, with clearance for a right-side dock.
- Borderless popup and flat rows with subtle hover highlighting.
- Tracking entries use their game-provided names and icons.
- Checkboxes with checkmarks show selected tracking options.
- Click a row to toggle it, or use Uncheck All.
- Displays up to 12 entries at once; scroll the mouse wheel for additional entries.
- Uses a flat list of the tracking entries exposed by the client API.
- Closes when clicking elsewhere, clicking the binoculars again, pressing Escape or entering combat.
- Tracking changes are made outside combat.

### Positioning and settings access

- Unlocking displays a tinted drag overlay over the map and dock.
- Drag anywhere in the overlay to move the layout; right-click it to lock again.
- Numeric X/Y position fields, applied with Enter.
- Reset Position returns the minimap to its default location (center anchor, X 400 / Y 0) without resetting appearance settings.
- Settings are saved account-wide through WoW SavedVariables.
- Layout changes requested during combat apply after combat ends.
- Available from Options → AddOns → SenMinimap → Open Settings.
- The options page includes version 0.1.0 and Yurri Gaming branding.

### Blizzard UI integration and fixes

- Hides the original minimap container, legacy decorations and default mail/day-night elements.
- Suppresses the original minimap Edit Mode selection area and its mouse interception.
- Hides default zoom buttons, including modern buttons that appear on hover.
- Replaces the native tracking launcher with the binoculars control.
- Relocates known queue/world-map controls while preserving their original click handlers.
- Retains the live map's normal click handling and map markers.
- Reapplies layout after relevant world/UI transitions.
- Restores the explicit screen anchor and saved scale, fixing the development revision in which the map disappeared.

### Final scope

- Renamed SenMap to SenMinimap; install folder and filenames are `senminimap`.
- Version remains **0.1.0**, with **Yurri Gaming** branding and no beta label in the addon.
- The experimental addon-icon collection drawer was removed. Other addons' minimap buttons are not collected or reparented by this release.
- This document replaces README.md.

## Installation

1. Exit the game completely.
2. Extract the ZIP and copy its `senminimap` folder into your Forever client's `Interface/AddOns` directory.
3. Confirm the path is `Interface/AddOns/senminimap/senminimap.toc`, without an extra nested folder.
4. If upgrading from SenMap, remove or disable the old `SenMap` addon folder. Do not run both versions together.
5. Start the game and enable **SenMinimap** at character selection.
6. Open `/senminimap`, or use Options → AddOns → SenMinimap → Open Settings.

For an existing installation, Lua-only updates normally need `/reload`; a newly named addon folder should be installed with the game closed.

### Keeping preferences when renaming from SenMap

Changing the addon folder name changes the SavedVariables filename WoW loads. Without migration, SenMinimap starts with defaults.

To retain earlier preferences, with WoW closed, back up the account's `WTF/Account/<account>/SavedVariables/SenMap.lua`, then copy it to `senminimap.lua` in the same directory. Do not overwrite an existing `senminimap.lua` unless you intend to replace those preferences. The internal `SenMapDB` table name is intentionally retained for this migration. This SavedVariables file is separate from the addon source file in `Interface/AddOns`.

## Commands

| Command | Action |
| --- | --- |
| `/senminimap` | Toggle settings |
| `/senminimap unlock` | Show the drag overlay |
| `/senminimap lock` | Lock the layout |
| `/senminimap reset` | Reset the minimap position |
| `/senmap` | Compatibility alias; supports the same arguments |

## Files included

| File | Contents |
| --- | --- |
| `senminimap.toc` | Addon metadata, interface target, version, author, saved-variable declaration and Lua load order |
| `senminimap.lua` | Complete addon implementation, settings panel, dock, icons, tracking menu and game-options integration |
| `CHANGELOG.md` | Full release notes, feature guide, installation, commands and compatibility notes |

There are no required additional asset files or external dependencies.

## Compatibility and verification

Targeted at Forever Interface 16001. Client updates can change frame names and APIs. Avoid running another minimap skin/mover at the same time. Other addons control their own launcher visibility and behavior.

Development validation includes Lua syntax checks and simulated behavior checks for selected layout, control and options-registration paths. These checks do not replace an in-game test. Before publishing, verify a fresh install, saved settings after reload, all four dock positions, tracking selections, outside-click dismissal, combat transitions and queue notifications on the intended client build.

## First-install defaults

- Map size 220; overall scale 1.00; background opacity 0.96.
- Teal accent; dock on the right; zone name inside bottom.
- Zone name, zoom buttons, clock, friends, mail, day/night and settings icon enabled.
- Mail and day/night use icons.
- Server time; backgrounds visible; position unlocked.
- Position X 400 / Y 0 relative to screen center. The reference screenshot did not expose its saved anchor.

These defaults apply to new settings or missing values; existing saved preferences are preserved.
