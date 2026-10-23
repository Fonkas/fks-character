# fks-character

Multicharacter, character creator and starter experience for **RedM** with **VORP**.

- Character selection at a table inside the Lemoyne moonshine shack - the player's characters sit around it
- Intro cutscene: an NPC talks, a man and a woman step in front of the camera and the player picks one
- Creator with live preview: face shape, skin tone and marks, eyes, hair and beard, body, makeup, starter clothing
- Real height: 200 cm is a 2 m tall character, 130 cm is a dwarf
- Cinematic cameras (full body, face, head, torso, legs) with rotate, zoom, up / down and left / right
- Identity: first / last name, date of birth (age limits), height, nationality, birthplace, biography
- Starter kits chosen after creation (e.g. lumberjack, miner, farmer, civilian)
- Final portrait moment in black & white, then a train arrives at the chosen station
- Character slots: free, or unlocked with **Tebex** purchases
- Soft delete (admins can restore), optional renaming
- `/skinmenu [id]` to let a player redo their appearance without a new character
- Same appearance format as vorp_character: vorp_barbershop, clothing stores and the inventory keep working
- Everything validated on the server (names, dates, appearance hashes, clothing, slots, kits)
- English and Portuguese

---

## Requirements

| Resource | |
|---|---|
| [fks-core](https://github.com/Fonkas/fks-core) **2.1.0+** | interface (every FKS script shares one UI) |
| [vorp_core](https://github.com/VORPCORE/vorp_core) | framework |
| [vorp_inventory](https://github.com/VORPCORE/vorp_inventory) | starter kit items |
| [oxmysql](https://github.com/overextended/oxmysql) | database |
| [weathersync](https://github.com/kibook/weathersync) *(optional)* | time / weather of the scenes |
| [fks-hud](https://github.com/Fonkas/fks-hud) *(optional)* | hidden automatically during the scenes |

fks-character **replaces vorp_character** (the manifest declares `provide 'vorp_character'`,
so resources that depend on it keep starting).

---

## Installation

1. Put the `fks-character` folder in your `resources` folder.
2. In `server.cfg`, **remove** `ensure vorp_character` and start fks-character after vorp_core:
   ```cfg
   ensure oxmysql
   ensure fks-core
   ensure vorp_core
   ensure vorp_inventory
   ensure fks-character
   ```
3. **Database** - nothing to do: `fks_characters`, `fks_character_slots` and `fks_tebex_redeemed`
   are created on start. If your database user can't create tables, import `install/fks_characters.sql`.
   Missing the VORP `characters` table? Import `install/vorp_characters.sql`.
4. **Starter kit items** - the kits in `config.lua` use `hatchet`, `pickaxe`, `hoe`, `mapa`,
   `pocket_compass`, `consumable_water` and `bread`. Rename them to the items your server uses.
5. Restart the server.

> The vorp_character clothing stores / outfits are not included - use your own clothing store resource.

---

## Configuration

Everything is in `config.lua`. All texts are in `locales/*.lua`.

### Language
```lua
Config.Locale = "en" -- "en" or "pt"
```
The NPC lines and the kit names are locale keys too (`intro_line1`, `kit_miner`...), so they follow
the language. Writing plain text in the config instead of a key also works.

### Scenes and coordinates
The scenes use the moonshine shack interior in Lemoyne (`Config.Interior`); the script loads the
interior and its entity sets by itself.

| Setting | |
|---|---|
| `Config.SelectionScene.seats` | one chair per character (max characters = number of chairs) |
| `Config.SelectionScene.camera` | fixed camera that shows the whole table |
| `Config.CreatorScene.stage` | where the character stands while being customized (lit from above) |
| `Config.CreatorScene.Intro` | NPC, cameras, where the man and woman stand, subtitle lines |
| `Config.CreatorScene.Photo` | portrait spot, pose, effect and time |
| `Config.FirstSpawn.Locations` | starting towns (platform point + optional train camera) |
| `Config.Arrival` | train arrival cutscene |
| `Config.Cameras` | creator camera presets |

To measure your own points, set `Config.DevMode = true` and use the tools below. Turn it off again
on a live server.

| Dev command | |
|---|---|
| `/fks_coords` | your position and heading, ready to paste |
| `/fks_aim` | the exact point you are aiming the camera at (e.g. a chair seat) |
| `/fks_camcoords` | the current camera (position, rotation, fov), ready to paste |
| `/fks_arrival [n]` | plays the train arrival of starting town `n` |
| `/fkschars` | reopens the character selection |

### Height
The chosen height is the real height: `scale = height / BaseHeight` of the model.
If characters look slightly taller / shorter than the value, adjust `Config.Identity.BaseHeight`.

### Slots and Tebex
```lua
Config.DefaultCharacterSlots = 3   -- free slots in "free" mode
Config.MaximumCharacterSlots = 4   -- absolute limit
Config.Slots = { Mode = "free" }   -- or "tebex"
```
- `"free"`: every player has `DefaultCharacterSlots` (+ extra slots given by admins or ACE).
- `"tebex"`: only `Tebex.FreeSlots` are free; players unlock more by pasting their Tebex
  transaction ID (`tbx-...`) or receipt link in the selection menu.
  1. Put your package IDs in `Config.Slots.Tebex.Packages` (`[packageId] = slots`).
  2. Add your secret key to `server.cfg` (never in `config.lua`, it is sent to the clients):
     ```cfg
     set fks_tebex_secret "your_tebex_secret_key"
     ```
  The purchase is checked on the Tebex Plugin API (must be complete and include the package);
  each transaction can only be used once.

### Starter kits
```lua
Config.StarterKits = { Enabled = true, Kits = { ... } }
```
`Enabled = false` removes the kit screen. Items are given once per character.

### Other HUDs
`Config.ExternalHud` lists the HUDs hidden during the scenes (fks-hud and the VORP UI by default).

---

## Commands

| Command | Who | |
|---|---|---|
| `/skinmenu [id]` | admins | reopen the appearance editor for a player (name and gender stay) |
| `/fks_addslots [id\|steam:...] [n]` | admins | set the extra slots of a player |
| `/fks_deletedchars [id\|steam:...]` | admins | list soft-deleted characters |
| `/fks_restorechar [charidentifier]` | admins | restore a soft-deleted character |
| `/rc` | everyone | reload your saved appearance |

Admins: ACE `fks.characters.admin` or a VORP group in `Config.AdminGroups`.

---

## For developers

### Server events
```lua
AddEventHandler("fks-character:server:characterCreated", function(source, charId) end)
AddEventHandler("fks-character:server:characterSelected", function(source, charId) end)
AddEventHandler("fks-character:server:characterDeleted", function(source, charId, mode) end)
```
`vorp_NewCharacter` is still triggered for scripts that give starter items.

### Server exports
```lua
exports["fks-character"]:GetCharacterIdentity(charId) -- birthdate, height, nationality, birthplace, biography
exports["fks-character"]:GetCharacterSlots(source)
```

### Client
```lua
AddEventHandler("fks-character:client:characterLoaded", function(charId, isNew) end)
exports["fks-character"]:GetPlayerComponent(category)
exports["fks-character"]:GetAllPlayerComponents()
exports["fks-character"]:GetPlayerSkin()
exports["fks-character"]:ApplyAppearance(ped, skin, comps)
```
Compatible vorp_character events: `vorpcharacter:savenew`, `vorpcharacter:updateCache`,
`vorpcharacter:reloadafterdeath`.

---

## Updates

On start (and every `Config.VersionCheck.interval` hours) the server checks the latest
release on GitHub and prints a warning in the server console when your version is outdated:

```lua
Config.VersionCheck = { enabled = true, repo = "Fonkas/fks-character", interval = 12 }
```

To update: download the new release and replace everything **except** your `config.lua`
(check the changelog for new config options).

---

## Credits

- Clothing and hair hash tables (`shared/data/`): [VORP vorp_character](https://github.com/VORPCORE/vorp_character-lua) - GPL-2.0
- Interface: drawn by [fks-core](https://github.com/Fonkas/fks-core) (fonts and their licenses live there)
- Native, scenario and interior references: [femga/rdr3_discoveries](https://github.com/femga/rdr3_discoveries)

---

## License

fks-character - multicharacter and character creator for RedM (VORP)
Copyright (C) 2026 Fonkas

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 2 of the License.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program (see [`LICENSE`](LICENSE)). If not, see <https://www.gnu.org/licenses/>.

