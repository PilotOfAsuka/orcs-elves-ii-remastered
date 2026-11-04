# BREW development

This is a separate project at `/Users/ilyayepifanov/Documents/ChatGPT/orcsElves2Brew`.
The previous published build and WolfMoon are separate projects.

The engine is pinned in `engine/UPSTREAM_COMMIT`; provenance and input checksums are in SOURCES.md.
Original game files go in `gamedata/`. They are excluded from source control.

## Build

Native dependencies: CMake, C17 compiler, pkg-config, SDL2, zlib, libavcodec and libavutil.

```sh
cmake -S engine -B build/native
cmake --build build/native -j4
clang -O2 -Iengine/src host/audio_export.c build/native/src/liboe2core.a $(pkg-config --cflags --libs zlib libavcodec libavutil) -o build/audio_export
mkdir -p gamedata/audio
build/audio_export gamedata/orcsandelves2.bar gamedata/audio
```

The exporter decodes all 115 original CMF/QCELP clips to explicit little-endian mono PCM.
Browser playback identifies the exact source clip by CRC32 and byte length.

Install the official Emscripten SDK locally under `tools/vendor/emsdk`, version 6.0.13.
On this Mac its platform detector needed `EMSDK_OS=macos` during install and activation.
The SDK's generated `.emscripten` config is used by the build script; no global shell configuration is needed.

```sh
python3 tools/build_core.py
python3 tools/build_ui.py
python3 tools/serve.py
```

`build_ui.py` uses the installed Godot 4.7.2 editor and official single-thread Web template.
The browser bundle contains a separate small BREW WebAssembly module and the prepared Godot UI.
No previous VM or game data is loaded. Only approved original BAR/MOD files and derived PCM enter the staging folder; local saves cannot enter the exported package.

## State and presentation

- The original applet advances by exactly 40 ms per simulation tick. Godot supplies elapsed time; rendering a UI frame never advances the simulation a second time.
- Classic uses the original C software renderer. A read-only capture hook runs before phone HUD/dialog drawing.
- Story pages are captured after original compositing, before the native navigation prompts.
- Godot receives a read-only model for menus, HUD, dialogs, lockpicking and discovered map data.
- UI actions call original engine handlers. Menu selections validate the menu identity to reject stale clicks.
- Dialogs sit over the fixed gameplay layout and block the movement controls.
- Both graphics modes share one simulation and one save store. Remastered keeps the original texels and adds a presentation-only lighting pass plus independent 1×/2×/4× raster-command replay; see LIGHTING.md.
- Game data and all game rules come from BREW. Only our own presentation widgets were reused.

Saves use a dedicated `/oe2-brew-v1` IDBFS mount. File writes are atomic within the virtual filesystem and synchronization is serialized/debounced. The preview origins on ports 8771 and 8772 have separate browser storage.

## Verification

```sh
python3 tools/build_qa.py
node tools/check_parity.cjs
```

This replays the same fixed-seed inputs against native C and browser-target WebAssembly. It compares the complete exposed model, full-frame RGBA CRC32 and world RGBA CRC32 after every tick and action. It also compares actual binary save files and resumes a saved level. Native QA writes into a fresh generated directory, separate from development game data.

This verifies cross-target behavior of the reconstructed engine. It does not establish equivalence to every behavior of the original ARM executable; that requires independent original-game references and broader playthroughs.

## GitHub publication

The repository is `PilotOfAsuka/orcs-elves-ii-remastered`. BREW source uses `codex/brew-port`; the game lives at the permanent Pages root on the existing `web-build` deployment branch. The release's `build.json` identifies the exact source and exported file hashes.

Use `python3 tools/publish_github.py publish` only after an explicit publication request and verification of the current export. It uses the existing credential helper, rejects uncommitted changes, and never force-pushes. The static root is replaced and the old `/brew/` path redirects to it. UI pack names and runtime resource queries use content hashes to avoid stale cached assets. Check the Pages build with `python3 tools/publish_github.py status`, then verify the live page.

## Localization, text art and save backup

`python3 tools/catalog_text.py` optionally extracts the supported English resource 1002 into ignored research files. `python3 tools/build_localization.py --strict` builds the UI catalog and checks complete coverage plus placeholder compatibility. It can rebuild from the checked-in English presentation catalog when research inputs are absent. The UI build runs this strict check.

Russian text is applied after reading the native model. Dynamic combat arguments are translated with explicit accusative/dative forms where needed. Read-only notebook IDs and complete item descriptions avoid translating phone-width fragments. Help pages describe the browser controls. A read-only capture before original story text compositing supplies the unchanged parchment; separate Cyrillic SVG masks replace only the text. English keeps the original masks. Travel captures precede native place names and prompts, allowing localized labels.

`Godot --headless --path ui --script ../tools/check_localization.gd` exercises all 1690 catalog records, formatted combat/stat samples, wrapped confirmations and text collected by the native/WASM replay. Regenerate story masks with `tools/build_story_ru.py` only when editing story.json; that optional tool expects local fontTools and NotoSerif-Bold.ttf under ignored tools/vendor paths.

The `/oe2-brew-v1` mount is intentionally independent of release versions and URLs. Settings can download a JSON backup containing Config and SD_0..SD_9 with SHA-256 checksums. Import validates every filename, size and checksum before writes, stages files, serializes storage synchronization and rolls back on failure. Input/advancement pause during replacement. Existing saves remain native BREW binary files; no conversion is involved.
