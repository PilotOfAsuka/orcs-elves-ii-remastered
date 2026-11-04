# Sources and provenance

## Game data

Orcs & Elves II, BREW English release 7.0.41, id Software / Fountainhead Entertainment / Electronic Arts.
Retrieved from https://www.myabandonware.com/game/orcs-elves-ii-vvv#BREW on 2026-11-04.

Original files are local inputs, excluded from Git:

| File | Bytes | CRC32 | SHA-256 |
|---|---:|---|---|
| orcsandelves2.mod | 292116 | 1631c7f1 | 1b8664e937ef8c43c474dff9b82c398b46425c5cca43eff5919e4ce96fc3d750 |
| orcsandelves2.bar | 2130702 | ad370c54 | 508aa62a368cc77c64113a68c5485f43871bf18fa819a58ae8e3aac085265c2f |

The MOD matches the exact size and CRC expected by moddata.h. The ARM executable is read for tables and strings; gameplay executes the reconstructed C code.

## Engine

Public source: https://github.com/new-thegrex-source/OEII_BREW_SymbianPort
Pinned revision: 2e9c7bfb79694ffbd8e648513edd229ee212c10a.
Engine reconstruction credited upstream to George Gorzhiyev (ygorz/oe2-re).
GPLv3 is preserved in engine/LICENSE. The public fork includes an SDL desktop host in addition to the Symbian host.

Our additions: browser host, WebAssembly build, audio conversion from BREW resources, UI state adapter, cinematic capture fixes, integration with our existing Godot UI, original-texture catalog and a presentation-only point-light/geometric ray-shadow pass.

Upstream claims full original-engine reconstruction. Our own validation is recorded separately in PROGRESS.md.

## UI

Our prepared stone/bronze UI, vector icons, HUD, dialogs, map and touch controls are reused from the previous project. Its game runtime and game resources are not part of this project.

## Build tools

Emscripten SDK: https://github.com/emscripten-core/emsdk (local, ignored).
Godot: https://godotengine.org/ (installed desktop editor and official Web export template).

## Russian presentation

The complete BREW 7.0.41 string catalog has a separate Russian presentation translation in localization/ru. Original English strings and game rules remain unchanged in the core. The checked-in ui/locales/ru.json is built from those translations and the supported English catalog. Intro/ending text masks have separate Cyrillic SVG resources; the original parchment illustration and travel map art remain intact.

Text-mask glyph outlines use Noto Serif Bold by the Noto Project Authors, obtained from the bundled LibreOffice font installation. Its SIL Open Font License and copyright notice are preserved in localization/FONT_LICENSE.txt. The optional regeneration tool uses fontTools 4.68; generated SVG resources are checked in, so ordinary UI builds do not require fontTools or the local font file.
