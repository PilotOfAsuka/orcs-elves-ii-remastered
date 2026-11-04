# BREW port progress — 2026-11-04

## Verified

- Separate BREW project created; the previous source project and WolfMoon were not modified.
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

## GitHub publication — 2026-11-04

- BREW source published in `PilotOfAsuka/orcs-elves-ii-remastered`, branch `codex/brew-port`, now the repository's default branch.
- Public game: https://pilotofasuka.github.io/orcs-elves-ii-remastered/brew/
- Pages deployment `804cc66b6f0e0d9e92d19d954d4921c1cfda2d1a` completed successfully. The preview manifest records source `74e9d658f80ec2b3d210587042658bc6698032ec` and exported file hashes.
- Live page checked in the browser: Russian UI selection, startup menus, original story pages, first level, custom modal dialog and return to the world view. No console errors were reported.
- Published HTML, UI pack, browser host, BREW loader, BREW WebAssembly and BREW resource package were verified against the deployment manifest.
- The existing Pages root is preserved; the repository homepage and README point directly to the BREW preview. QA pages and local saves are excluded from publication.

## Current scope

This is the first BREW browser foundation. The parity comparison is against the same reconstructed C engine on the native host, not a certification of all original ARM behavior. Full-game playthroughs and remaining presentation states still need validation.

Both modes display original BREW art. Remastered now adds point lighting and geometric ray shadows, with the same core and saves. The user chose this direction instead of generated HD replacements.

The interface has Russian/English selection. Original BREW story art and game text are English; a full BREW translation is outstanding.

## Original-art lighting and interface revision — 2026-11-04

- Surveyed and decoded all 220 wall variants, 24 floor/ceiling materials and 1057 sprite frames (205 sprite identities), using all 507 palettes. Local contact sheets were visually checked. Sources, candidates and limits are recorded in docs/LIGHTING.md.
- Added an independent Remastered buffer: warm fire/torch/candle light, coloured magical effects, molten floor light and a held magical light. Wall/door segments block shadow rays. Classic pixels, simulation, RNG and binary saves are untouched by the getter.
- Lowered ambient light slightly at the user's request; retained all original BREW textures and sprites.
- Fixed the cinematic capture path: the separate camera renderer and post-fade/particle image now reach the browser before native captions/letterbox overlays. The replay now observes 105 distinct cinematic world frames.
- Enemy HP and event text now overlay the top of a framed game view. Removed the gameplay title and BREW footer. Menu/map/inventory are compact top icons; native Options contains language/fullscreen instead of permanent menu footer buttons.
- The graphics switch is a fourth compact icon with a Classic/Remastered caption; the selection persists locally. Lower touch controls now expand vertically into the available screen space, with larger icons and no visible keyboard-letter captions.
- Updated replay passed 1140 model/Classic pixel checks over 1058 ticks and byte-identical SD_0–SD_3 saves. Geometric shadow tests cover blocked, parallel, above-wall and opened-wall rays. Lighting getter purity is checked for model, Classic pixels and saves.
- Measured 912 lit replay frames: mean 3.30 ms, p95 8.60 ms, maximum 11.52 ms in this desktop run. A live narrow-browser scene logged lighting around 1.6–3.7 ms and ordinary simulation ticks around 0.5–1.3 ms; this is not a whole-game/mobile performance guarantee.
- Local browser visually verified the darker Remastered view, compact graphics icon, enlarged lower buttons and fixed HUD. No warning/error console entries were reported.
- Publication now targets the existing Pages root; `/brew/` redirects to it. Content-named UI packs and versioned core/runtime requests prevent older cached root assets from masking the new build.

- Extended shadows to enemy/object alpha silhouettes; tests cover opaque pixels, transparent gaps, moving casters and hidden casters. Fire on the spit (116/118) follows the original meat-present bit; before/after emission tests pass. Violet decorative bones are no longer misidentified as an emitter.
- Added soft shadow interpolation, visible-emitter halos, contact shading and subtle depth haze. Magical projectile sources follow their live sprite coordinates and expire with them.
- Added persisted Remastered quality in Options: Low 176×164, Medium 352×328, High 704×656. Higher qualities replay resolved raster commands on an independent framebuffer, without replaying game logic. The visible UI frame remains independent of render resolution.
- All 1140 comparisons over 1058 native simulation ticks still pass with High getters sampled during the replay. Extra Staff/menu fixtures use 16 ticks. Getters at all three resolutions preserve the model, canonical world image and saved files. Measured sampled resolution-pass means: Low 1.71 ms, Medium 8.18 ms, High 32.18 ms. Live browser High measured about 29.6–32 ms in a different saved scene.
- Corrected the Staff presentation’s 7-source-pixel gap using a separate background/weapon layer; canonical native captures stay unchanged. Tested actual 704×656 output and the Options dropdown in the browser without warning/error logs.

- Corrected shadow height intervals for multi-piece upper walls (64..ceiling) and added upper-wall/below-opening regression rays.

- At the user’s request for a much stronger lighting influence, lowered unlit ambient to 0.17/0.20/0.27, increased direct-light gain to 2.1× and strengthened emitter halos. Classic and UI brightness remain unchanged.

## Contact AO, Russian presentation, saves and HUD — 2026-11-05

- Added stronger smooth contact AO at floor/wall and ceiling/wall seams and perpendicular wall corners. Separate height-aware distance fields prevent a false floor seam beneath floating upper wall pieces. The effect retains world-space size at all three render qualities. A wall-column cache preserves exact rendered pixels while reducing repeated distance lookups.
- Corrected billboard lighting normals, quality-scaled emitter halos, held magic colors and Flaming Sword light. Original art and the 40 ms simulation remain unchanged.
- Added a complete separate Russian presentation catalog: 1690 of 1690 original text records, with exact/static and formatted combat/stat checks, argument validation, actor case forms and sampled runtime text checks. Full linguistic playthrough review remains outstanding.
- Original parchment artwork now has separate Cyrillic intro/ending text masks. Travel place names, complete notebook entries, item descriptions, help and credits use the custom presentation. Wrapped confirmations are reassembled before translating; new dialogue resets its text scroll. English keeps original game strings and story masks, with browser-control help.
- Replaced the HP/armor panel with fixed-height bronze instruments, separate red/blue bars, readable counts, weapon/ammo strip and a low-health pulse. Verified it in the browser at desktop size and 390×844, with large lower controls and modal dialogue overlay.
- The persistent browser filesystem stays at /oe2-brew-v1 across releases. Added Settings download/import backups with per-file checksums, staged replacement and rollback. Actual browser download produced Config and SD_0..SD_3; all checksums verified. The same backup was imported through the file picker and resumed the level. A full reload after rebuilding the UI also restored position/orientation and HP/armor 100/100, Wand and 10 charges. Corrupted backup rejection and exact binary restoration pass in the isolated replay.
- Native/WASM replay again passed 1140 full model/frame/world comparisons over 1058 simulation ticks, with 16 extra Staff/menu fixture ticks. All saved SD_0..SD_3 files match exactly. All quality getters preserve the model, canonical world image and save bytes. All 105 cinematic frames remain distinct in the replay. Synthetic contact tests cover the seams, clear centres, perpendicular corners and upper-wall gap.
- Sampled resolution-pass means in the final desktop replay: Low 2.01 ms, Medium 9.43 ms, High 39.80 ms. Across 912 lit replay frames, mean 3.68 ms, p95 9.51 ms. These are scene-specific CPU measurements, not a whole-game/mobile guarantee.
- Final browser Low scene logged lighting 2.3–2.4 ms and ordinary core ticks 0.6 ms (observed maximum 14.2 ms including loading). RU story texture, travel label, initial dialogue, notebook, runtime RU/EN changes, quality dropdown and backup flow were checked visually. No warning/error console entries were reported.
- Godot import/export, strict catalog build, clean-checkout catalog rebuild equivalence, translator checks and diff whitespace checks pass.
