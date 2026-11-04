# Vertical English trailer

Offline capture of the BREW-based browser port, in the first dungeon. The main
trailer is 47.6 seconds; the short cut is 21.8 seconds. Both are 1080×1920 at
60 FPS, H.264 (BT.709 limited-range 4:2:0) with AAC audio. English captions
describe the port. The interface briefly switches to Russian to demonstrate the
language option. The short cut stays entirely in English.

The recordings use the original BREW artwork, original title music and gameplay
sounds, the port's lighting renderer, and the actual Godot HUD/control widgets.
Small synthesized transition impacts are mixed under the game sounds. There is
no voice-over. The camera flythroughs use an offline-only fractional camera
adapter. The combat/movement/map/save sequence uses actual game actions and the
unmodified 40 ms simulation step. A 60 FPS edit does not imply 60 simulation
ticks per second or guaranteed High performance on phones.

Capture starts an isolated `persist:false` WASM instance and never reads or
replaces the user's browser saves. `OE2_CINEMATIC_CAPTURE` hooks are absent from
normal native/browser builds. The film core goes to `build/cinematic/core`,
separately from the published web build. Filming tools do not change the Pages
URL or require a new game deployment.

## Rebuild

Run from the repository root. Requires the usual supported BREW assets and
Emscripten setup, Node, Python with NumPy, Godot 4 and FFmpeg/ffprobe. Generated
frames, copies of the interface and edit manifests stay in ignored
`build/cinematic`. Final files in `videos/` are also ignored.

```sh
python3 tools/build_core.py --cinematic
node tools/cinematic/capture.cjs fly
node tools/cinematic/capture.cjs gameplay
python3 tools/cinematic/edit.py
python3 tools/cinematic/setup_ui.py
godot --headless --editor --path build/cinematic/ui --import
godot --path build/cinematic/ui --script "$PWD/tools/cinematic/render.gd" -- "$PWD/build/cinematic/edit.json"
python3 tools/cinematic/audio.py
python3 tools/cinematic/finish.py
```

Godot renders a fixed 1080×1920 SubViewport to a JPEG stream. Its native preview
window can be smaller without cropping the movie. It is an authored portrait
capture, not footage from a physical phone. Rendering needs a working graphics
display; headless import alone does not render the movie.

`finish.py` writes the main trailer, short cut and PNG poster. It verifies actual
dimensions, frame rate, frame counts, durations, color range and audio format,
then decodes both movies with FFmpeg's error handling enabled. The result is
saved as `build/cinematic/video-verified.json`. Frame models and the English
caption edit are retained for inspection; `edit.py` rejects another dungeon or
non-ASCII captions. Original native/WASM parity is checked separately with the
normal `tools/build_qa.py` and `tools/check_parity.cjs` workflow.

The optional survey/route/shot scripts help inspect first-dungeon geometry and
choose camera shots. They are production tools, not part of the browser game.
