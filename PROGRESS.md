# BREW port progress — 2026-11-04

## Verified

- Separate BREW project created; the previous release and WolfMoon were not modified.
- Original English BREW release 7.0.41 obtained. BAR and MOD hashes recorded; MOD size and CRC exactly match the engine's supported build.
- Reconstructed C engine pinned to public revision 2e9c7bfb79694ffbd8e648513edd229ee212c10a. Native desktop build boots the original game.
- Browser host built using Emscripten 6.0.13. The C gameplay core runs in WebAssembly with the original 40 ms simulation step.
- All 115 original audio resources decoded successfully; browser host plays PCM through WebAudio.
- Prepared Godot UI widgets reused: theme/icons, HUD, dialog panel, lockpick panel, map and language picker. Gameplay comes only from BREW.
- Fixed-layout game view and modal dialog input blocking implemented. Read-only world and story captures exclude the original navigation overlays.
- Dedicated BREW save namespace with persistent browser filesystem implemented; exported input staging excludes saves.
- Native/WebAssembly replay passed 1140 comparisons over 1058 simulation ticks: complete exposed model, full-frame and world RGBA checksums match exactly. Covered startup, menus, story, travel, loading, exploration, dialogs, map, saving and the initial cinematic.
- Four generated binary save files (SD_0, SD_1, SD_2, SD_3) matched byte for byte. Loading resumed the saved level in both targets.
- Persistent browser storage tested in an isolated origin: a complete page reload restored the saved level, position, direction, health, weapon and ammunition.
- The same browser save was opened through the Godot UI's Continue flow. F5 saved without reloading the page; M opened the custom discovered-cell map.
- Browser gameplay visually confirmed with the custom HUD; the sampled scene logged 0.7–0.8 ms ordinary core ticks (observed maximum 22.3 ms including earlier work). This is not a whole-game performance claim.
- Godot imports and Web exports complete without parse errors. Browser language selection and custom menu transitions checked visually without console errors.

## Current scope

This is the first BREW browser foundation. The parity comparison is against the same reconstructed C engine on the native host, not a certification of all original ARM behavior. Full-game playthroughs and remaining presentation states still need validation.

Classic displays BREW graphics. The Remastered switch shares the same core and currently prepares the enlarged presentation layout. HD BREW resources remain future work; no HD claims are made for this prototype.

The interface has Russian/English selection. Original BREW story art and game text are English; a full BREW translation is outstanding.
