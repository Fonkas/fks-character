# Changelog

## 1.1.4
- **Invisible character after spawning:** on some servers something hides the player again right after the
  character enters the world. The old check showed the character only 3 times and then gave up. For 60 s after
  spawning (`Config.Session.VisibilityGuard`) the character is now shown again every time it goes invisible.
  This also undoes the spawnmanager freeze (frozen, no collision, no control) and network concealment.
  The routing bucket is confirmed with the server, and the console prints what was seen so the resource doing it can be found.
- **Fixed: clothes looking wrong after taking a piece off and putting it back on** (shirt over the vest, puffy
  sleeves...) until `/rc`. The clothing commands now rebuild the whole outfit the same way `/rc` does.
- **New: clothing style commands**: `/sleeves`, `/collar`, `/bootstyle` (alias `/tuck`) and `/bandana`.
  If the piece doesn't have that style, the player is told. Styles are kept after `/rc`, death and the clothing commands.
  Configure them in `Config.ClothingCommands.Styles`.
- New export `ToggleClothingStyle(style)`.

## 1.1.3
- **Fixed: character spawning invisible and then being sent back to the moonshine bar** (slow PCs / connections).
  On those clients `vorp:playerSpawn` can reach the server twice; the second selection request could finish
  *after* the character was picked, moving the player back to the selection bucket (invisible to everyone) and
  teleporting them to the bar. Selection requests are now de-duplicated and re-checked after every wait, and the
  client ignores a late selection request once the character is in the world.
- The spawnmanager auto-spawn now goes through fks-character (`setAutoSpawnCallback`): the late `forceRespawn`
  from basic-gamemode is dropped while a character is loaded instead of racing to switch auto-spawn off.
- Late-spawn recovery no longer needs a saved position: it starts from the coordinates the character spawned at.
  It waits for vorp_core, checks the position stuck (up to 3 tries) and confirms the routing bucket with the server.
  The server also resets the routing bucket by itself when vorp_core moves an in-game player.
- Appearance loading checks the ped is really ready (model + components) and retries before handing over to
  vorp_core; for 20 s after spawning a missing appearance / invisible ped is fixed automatically.
- `/rc` (and the late-spawn fix) also reload the model when it does not match the character's gender.
- `Config.Debug = true` prints a timeline of map start, auto-spawn, playerSpawned, appearance and routing bucket.
- **New: clothing commands** `/hat`, `/jacket`, `/shirt`, `/vest`, `/pants`, `/shoes`, `/gloves`, `/mask`, ... take a
  piece off and put it back on; `/clothes` puts everything back. Configure in `Config.ClothingCommands`.

## 1.1.2
- **Fixed: character loading invisible and then being teleported to the default spawn.** On slow clients the map can finish loading after the character is already in the world; basic-gamemode then forces a spawnmanager respawn (invisible player, teleport to the map spawn) and vorp_core moves the player to another routing bucket. fks-character now keeps the auto-spawn off once the character is loaded, and if a late spawn still happens it puts the character back where it was (position, appearance, visibility, screen, radar and routing bucket).

## 1.1.1
- **Starter kits can give weapons**: use `weapon = "WEAPON_..."` instead of `item` (optional `ammo = { AMMO_REVOLVER = 24 }`). Weapons are created with vorp_inventory `createWeapon`, so they no longer fail with "does not exist in DB".
- On start, the server console warns about kit items that don't exist in your `items` table.
- **Fixed: characters sometimes spawning at the default spawn instead of where they logged out.** The last position is now read from the database when the character is selected (not from the copy loaded when the player joined), and invalid positions (0, 0, 0) are ignored.
- VORP no longer saves the position while the player is in the portrait / train / `/skinmenu` scenes.

## 1.1.0
- **The interface is now drawn by fks-core** (shared FKS UI). fks-character no longer ships its own HTML, CSS,
  JS or fonts, so the server runs one NUI for every FKS script and the look follows `Config.Theme` in fks-core.
- **Requires fks-core 2.1.0+**: add `ensure fks-core` before `ensure fks-character` in server.cfg.
- Same screens and flow as before (selection, creator, kits, intro, photo, train). The identity form errors now
  jump to the field, and the gender pick also accepts the arrow keys and A / D.

## 1.0.0
- First release.
- Multicharacter selection: the player's characters sit at a table inside the Lemoyne moonshine shack.
- Character creator with real-time preview: face, skin, eyes, hair, body, makeup and starter clothing.
- Intro cutscene: an NPC talks (subtitles), a man and a woman stand in front of the camera, TAB / ENTER (or mouse) picks the gender.
- Real height: the chosen height (cm) is the character's height in game (`SetPedScale`).
- Cinematic camera presets (full body, face, head, torso, legs) with rotate, zoom, up / down and left / right controls.
- Starter kits chosen after creating the character (items given once per character).
- Final portrait moment (black & white, "take a screenshot") followed by a train arriving at the chosen station.
- Character slots: free mode or unlocked with Tebex purchases (transaction ID validated server-side).
- Soft delete (recoverable by admins), optional renaming.
- `/skinmenu [id]`: admins reopen the appearance editor for a player without a new character.
- Same appearance format as vorp_character (works with vorp_barbershop, clothing stores, inventory).
- Hides other HUDs (fks-hud, VORP UI) during selection / creation / cutscenes.
- Update checker: warns in the server console when a newer GitHub release exists.
- English and Portuguese.
