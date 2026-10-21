# Changelog

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
