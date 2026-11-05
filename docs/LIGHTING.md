# Original BREW art with Remastered lighting

The user chose to retain original BREW textures and sprites in both modes. Classic returns the original captured pixels; Remastered applies light to those pixels without changing gameplay, RNG or saves. Generated HD weapon replacements are not used.

## Complete resource survey

`python3 tools/catalog_textures.py` decodes the supported original BAR/MOD inputs using the native `oe2tool` resource extractor. It produces `research/textures/catalog.json`, individual PNGs and contact sheets. These derived research files stay local and ignored.

Verified survey totals: 507 palettes, 220 wall materials, 24 floor/ceiling materials, 1057 sprite frames across 205 sprite identities. Palette variants are included, so these totals are not counts of unique paintings.

| Original identity | Visual reading | Current treatment |
|---|---|---|
| Sprite 130, 234 | Large animated fire | Warm orange, flickering light |
| Sprite 136 | Standing torch | Warm light at the upper flame |
| Sprite 150 | Wall torch/lantern | Warm light above the fixture |
| Sprite 181 | Candle in a niche | Smaller, warmer light |
| Sprite 149 | Small flame effect | Orange light |
| Sprite 116 plus 118 | Roasting meat/fire and the empty spit rack | Warm light only while the native meat-present entity bit is set; rack remains after taking meat |
| Sprite 133 | Violet decorative bones | No emission; bright colour alone is insufficient |
| Sprite 14–16, 220–225, 227, 230, 235, 238, 242, 243, 245, 252 | Coloured magical effects/projectiles | Matching coloured light while the sprite exists |
| Flat global identity 199 (catalog material 5) | Molten cracks | Low orange floor light |
| Wall materials 24–31 | Windows | Candidate only; no automatic emission without confirming the scene context |
| Other coloured doors, gems, bottles and painted details | Bright colour alone does not establish a light source | No automatic emission |

The source table is in `host/lighting.c`. Hidden sprites and sprites using wall materials do not become point emitters. The nearest seven environmental lights are selected, with one reserved slot for the held wand/magical weapon. Light positions follow actual sprite coordinates; held light stays at the player during cinematic camera movement.

## Renderer

The original software rasterizer also records world positions and surface normals for floors, ceilings, wall spans and visible sprite runs. The Remastered getter reads these surfaces and the original RGBA capture into a separate output buffer.

Each point light uses distance falloff, a surface-facing term and coloured linear-light modulation. Shadow rays intersect the current level's wall/door segments. Three slightly offset rays and interpolation along the receiving surface soften the edge. Enemy/object billboards additionally block rays using original alpha-column runs, including transparent gaps. Their current rendered frame and scale are recorded where available; hidden and removed sprites cease to cast. Sprite receivers use geometry shadows to prevent billboard self-shadow artifacts; sprites do not yet receive each other’s shadows. Hidden/opened door geometry is excluded; geometry changes invalidate visibility caches. Fire flicker is deterministic and never consumes game RNG. Subtle depth-tested halos surround visible emitters, geometry-based contact shading darkens floor/wall, ceiling/wall and perpendicular-wall seams, and a restrained cool distance haze gives depth. The halo and haze respect cinematic fades.

Shadow visibility is cached in a 16 × 16 × 8 world-unit grid. This deliberately trades fine shadow detail for speed. Translucent fence masks are currently treated as solid segments, billboard shadows approximate the silhouette rather than a full 3D mesh, and reflections, indirect bounce lighting and volumetrics are not implemented. This is software ray-shadow lighting, not RTX or a complete path tracer.

The user requested a stronger night-like contrast after the initial pass. Ambient is now 0.17/0.20/0.27 in linear RGB, direct lights have a 2.1× gain and visible-emitter halos are stronger. Unlit areas are substantially darker, while visible sources illuminate local surfaces and leave geometric shadows. Original emissive artwork, palette and texture resolution are retained.

## Checks

`tools/check_parity.cjs` compares native and WebAssembly simulation, Classic world pixels, full-frame pixels and binary saves. It additionally verifies a moving cinematic, blocked/open/parallel/above-wall shadow rays, a visible Remastered change, and that reading Remastered does not mutate the model, Classic buffer or save files. Performance figures are recorded in `build/parity-result.json`; they describe that replay scene and machine, not all levels or mobile hardware.

## Independent render resolution

Native gameplay continues rendering at 176×164. `host/presentation.c` records the resolved, view-space wall/sprite raster commands, weapon layers and fade/tint operations. Medium and High replay these commands on a private framebuffer/renderer at 352×328 and 704×656. Floors are projected again and spans rasterized at the selected size: the higher levels are not a resized low-resolution image.

The replay calls raster functions only. It does not rerun camera logic, sprite animation, AI visibility activation, game handlers, physics or RNG. Shared span-drawer bindings are restored before returning. Canonical native pixels and state remain available for parity checks. Sprite textures retain their original resolution.

Quality is selected in the native Options menu’s custom presentation section and persists separately from saves. Low is the default. The UI frame keeps its dimensions when quality changes.

The Staff’s original visible bottom is row 156 in a 164-row view (7-row gap). A separate background/weapon presentation layer anchors it to the bottom in both graphics modes and at each render scale. Canonical captures and original animation selection remain intact.

## Contact ambient occlusion — 2026-11-05

Contact AO uses world positions and normals from the existing raster metadata rather than a noisy screen-depth sampling pass. A lazy 16-world-unit vertex distance field follows current wall/door segments, with separate floor, ceiling and perpendicular-wall layers. A smooth 20-unit falloff darkens ambient from 1 to 0.35; direct light receives a smaller contact reduction. Upper wall pieces do not falsely shade floors they do not touch. Hidden/open geometry and height changes invalidate the fields.

The effect has the same world-space width at Low, Medium and High. A per-column cache reuses vertical wall corner distances without changing output pixels; the three sampled rendered buffers were byte-identical before/after this optimization. Held weapons are excluded. Billboard receivers face the camera rather than inheriting the last wall normal. Emitters' halo sizes scale with render quality. Held Freeze/Mold/Shrink colors follow their actual resource identities, and the Flaming Sword contributes warm light.

Native geometric tests cover floor and ceiling seams, vertical wall bottoms, clear wall centres, perpendicular corners and absence of a false floor contact beneath upper walls, alongside the existing wall/sprite ray tests. This is a local contact approximation, not global indirect illumination or hardware ray tracing.

## Projectile arrival flashes — 2026-11-05

The original projectile resolver now notifies the host immediately before a
landed missile is retired. This reads the original start/destination and current
emissive sprite identity without changing its lifetime, damage, RNG or turn.
An eight-entry presentation ring retains a colored local light for 320 ms with
a quadratic decay, a larger radius and higher initial power than flight light.
A four-unit incoming-side bias keeps wall impacts in front of opaque geometry.
Physical arrows/melee/blood do not gain emission; flaming bonus arrows use the
existing fire source. Impact lights have priority within the same seven-world-
light budget, plus the existing held light, so no unbounded light loop is added.
Rays, receiving surfaces and halos use the same occlusion as other sources.
There is no full-screen white-flash overlay.


## Painted candles and restrained glows — 2026-11-05

The candle painted into the skull-and-bars wall is global identity 61 or 69, material 140 or 164. Its flame is near texel (79,91) in the 117×117 original. Sources follow native U coordinates, repeating/mirrored pieces and actual vertical ranges, and are biased four units onto the visible side. Wall-textured props use the original orientation, mirror, size and vertical origin; hidden props are skipped. Identity 68 is a wooden grate and must not emit.

Lamp/candle sprite identities 150/181 have four flame frames and a fifth extinguished frame. A fixed frame 4 removes the source immediately; ordinary hidden/replaced sources also disappear. Sources are never retained as permanent map decorations independently of native state.

Starter-wand held light is deliberately gentle (radius 105, power 0.28); other held magic and environmental lights are unchanged. Optional halos use a smaller footprint and a 0.008 gain instead of 0.038. Held sources never receive a camera-space halo. Blended sprite/weapon passes preserve the background receiver rather than relighting blended background pixels as solid foreground; this remains an approximation, not a multilayer physical transparency model. Original Classic blending is untouched.

`tools/check_candles.cjs` exercises mirrored/repeating/two-sided/hidden/clipped wall placement, native lamp script input, flame/extinguished/hidden frames, real map-4 illumination and state/pixel/save purity at Low/Medium/High.


Lighting distance is a saved presentation preference, clamped to 100–250% (extended from 150% on 2026-11-06).
It scales environmental, projectile, arrival and held-source radii exactly once;
power, hue, halo footprint and the eight-slot budget are unchanged. Distance
changes invalidate the visibility cache. Native model, Classic and save purity
are checked at both endpoints and outside-range inputs for every quality.


## Dense-light optimization — 2026-11-06 (local only)

The user reported slow scenes in Dark Forest (map 5) and Sol (map 6), especially
with many sources. All original art, eight active light slots, source powers,
100–150% reach, three shadow samples, contact shade, halos and impact flashes
are retained. High still replays the actual raster at 704×656; this change does
not upscale a lower-resolution finished image.

The renderer now accelerates wall-ray candidate lookup with a 64-unit uniform
grid and DDA traversal. The final segment/height intersection arithmetic remains
unchanged. Out-of-grid rays and exhausted grid capacity use the complete scan.
Geometry changes rebuild the index. A separate per-light cache retains all three
wall-ray results while animated sprite silhouettes invalidate the combined
shadow cache. Light-position and geometry changes invalidate the relevant wall
samples; no frozen cross-frame irradiance image is reused.

Vertical shadow interpolation and held-weapon incident light are also reused
where their inputs are identical. Those exact optimizations were compared with
the initial build: all 18 static frames and 144 camera-motion frames had identical
RGBA hashes. Their High/150% Sol pass improved from 98.5 to 72.6 ms before the
additional irradiance reuse below.

At Medium/High, smooth incident RGB is sampled at one-world-unit intervals only
where at least two full-resolution pixels fit in an interval. Vertical spans
and native floor/ceiling trajectories keep separate current-frame caches, keyed
by the actual receiver and its normal. Texture pixels, silhouettes and receiver
boundaries are still shaded individually. Low remains exact. Receivers within
eight units of a point source use exact per-pixel illumination to preserve the
sharp normal response near the flame. The interpolation is an approximation,
not a claim of bit-identical final Remastered pixels.

`tools/check_lighting.cjs` tests 144,000 accelerated/reference rays on original
and modified level geometry and compares 288 advancing/camera-motion frames
against same-frame exact illumination at all qualities and both reach endpoints.
Observed maximum RGB-channel difference: 1/255; largest scene RMSE: 0.048/255.
Low pixels are exact. `tools/bench_lighting.cjs` surveys actual emissive points,
selects views with eight active lights, verifies model/Classic purity, and writes
local RGBA/hash/timing reports. `tools/compare_lighting.cjs` compares its static
frames against the saved baseline. These generated artifacts stay ignored.

Desktop WASM pass medians, including High raster replay, eight warm samples:

| Scene | Reach | Before High, ms | After High, ms | Camera motion before → after, ms |
|---|---:|---:|---:|---:|
| El’Landra | 100% | 46.5 | 24.0 | 46.7 → 23.7 |
| El’Landra | 150% | 71.2 | 29.4 | 75.3 → 29.1 |
| Dark Forest | 100% | 52.2 | 29.2 | 51.0 → 28.9 |
| Dark Forest | 150% | 63.8 | 32.2 | 63.6 → 31.9 |
| Sol | 100% | 67.6 | 28.1 | 81.0 → 29.5 |
| Sol | 150% | 98.5 | 37.3 | 125.8 → 39.8 |

This is local CPU-pass timing, not end-to-end browser FPS or on-device Android
performance. Reports are under `build/lighting-bench/{baseline,guarded}`; the
existing public release and APK have not been updated by this work.

The implementation applies established spatial indexing and shadow-cache
techniques to the existing software renderer. Godot documents caching unchanged
shadows in its [shadow atlas](https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html).
AMD’s [TiledLighting11 sample](https://gpuopen.com/learn/tiledlighting11-directx-11-sdk-sample/)
illustrates spatial light culling, and [PBRT’s grid traversal](https://www.pbr-book.org/4ed/Volume_Scattering/Media)
describes DDA through grid cells. These are design references; no external engine,
shader package or copied implementation was integrated. A complete Forward+/GPU
renderer would require a separate world/mesh pipeline and remains future work.


## Camera neighborhood, 250% maximum and controlled comparison

The maximum reach is now 250% in the core, saved browser preference and game
slider (100–250%, step 5). Existing selected values such as 125% and 150% survive
unchanged. It still scales radii once and preserves power, hue, halos and the
eight-slot budget.

World-source selection keeps a three-tile (192 world-unit) neighborhood around
the camera in all directions. Sources whose influence disk contains the camera
are also retained in every direction. Farther disks are conservatively tested
against the native 90-degree horizontal view cone, expanded by their light
radius and a rounding margin. The emitter center alone is never the clipping
criterion: off-screen fires that illuminate visible surfaces remain active.
Irrelevant distant sources no longer consume selection slots. The held source
retains its reserved slot. This is camera-space source culling, not a spotlight
that turns the surrounding world dark when the player looks away.

QA verifies all 64 near-source directions, distant exclusions, off-screen
influence and a grid of visible receivers. The advancing exact-illumination
comparison now covers 432 frames, including 250%: maximum difference 2/255 in
El’Landra, 1/255 in Forest/Sol; worst scene RMSE 0.048/255; Low is exact relative
to the same source-selection policy. The earlier byte-identical/static figures
above describe the preceding acceleration stage before view-cone selection.

For a fair maximum-settings comparison, an isolated control core retains the
initial lighting algorithm plus QA instrumentation and only raises its clamp to
250%. It uses the current native engine/runtime and the same original resources.
The optimized core is tested at the identical poses, seed and advancing native
call sequence. Two separate runs per version each take eight warm frames and
eight camera-motion samples; the table averages their medians. Both versions
have eight active lights in these maximum-setting views.

| Scene, High 704×656 / 250% | Warm before → after, ms | Speedup | Camera motion before → after, ms |
|---|---:|---:|---:|
| El'Landra | 98.4 → 37.9 | 2.60× | 97.2 → 36.1 |
| Dark Forest | 86.1 → 39.1 | 2.20× | 121.7 → 48.3 |
| Sol | 104.6 → 36.4 | 2.88× | 140.8 → 47.7 |

All three original camera poses are held fixed even when the optimized survey
finds a different heavy view. Raw frames/reports are in the ignored
`build/lighting-bench/max-{before,after}-{1,2}` folders, aggregate data is in
`maximum-summary.json`, and the control-source hash/description are in
`build/light-max-reference/reference.json`. These are CPU render/replay-pass
measurements on this computer, not measured phone FPS.

In the static High/250% control comparison, Forest and Sol differ by at most
1/255 per RGB channel. El’Landra differs by up to 4/255 (RMSE 0.272/255), including
source-selection/flicker-slot changes. The comparison with exact illumination
under the new policy above isolates the irradiance interpolation itself.


## Superseded first preset mapping: Low / Medium / High

The subsequent local preparation replaces the continuous slider with three
exclusive buttons. Low uses radius multiplier 1.5, Medium 2.5 and High 5.0.
The menu shows only these names, with no numbers or percentages. This setting
is independent of the raster-resolution quality selector. Preferences use the
nearest preset when reading older intermediate values; existing 150/250 values
map directly to Low/Medium. The native range is bounded to 150–500.

The user will playtest this revision. Only the normal core/UI build is prepared
for this request; no new gameplay/performance or browser checks are claimed.
The timing tables above predate the 5.0× option and are not measurements of it.


## Current processing-distance selector (clarified by the user)

Low/Medium/High now specify 4/7/10 native walking steps. One step is 64 world
units, so High reaches 640 units from the first-person camera along the forward
axis. The processing region has a finite 90-degree horizontal cone with a radial
limit and a surrounding three-step neighborhood. Candidate influence disks are
expanded conservatively; a source just outside the region can still illuminate
receivers inside it. The existing light-slot budget is retained.

The preset does not scale individual lights. Source falloff radii are fixed at
1.2× their original values, matching the appearance of the former 120% setting;
original source powers are retained. Direct illumination and its shadow work
stop beyond the processing limit; the last walking step smoothly fades to
ambient. Ambient/contact shade, textures and render resolution remain separate.
Held-weapon shading stays stable, and source halos use the finite-distance fade.
Source-identity flicker prevents list-order changes from changing its phase.

The menu shows only the three names under Lighting draw distance. New settings
use `oe2-brew-light-processing-steps`. Legacy 150/250/500 preferences map to the
corresponding Low/Medium/High names; gameplay saves retain their existing store.

This clarification is prepared locally by rebuilding the core and exporting the
UI, leaving playtesting to the user. The historical measurements above are not
measurements of these new processing distances.


## Current requested distances: 5 / 15 / 20 steps

The user subsequently selected Low 5, Medium 15 and High 20 walking steps
(320/960/1280 units) and authorized publication. The source appearance remains
fixed at the former 120% reference; only the processing extent changes. The
last-step fade and surrounding three-step neighborhood are retained.

Settings now persist `low`, `medium` or `high` in
`oe2-brew-light-processing-preset`. Previous 4/7/10-step and 150/250/500-percent
preferences migrate by preset identity. No new performance or gameplay checks
are claimed for this user-playtested adjustment.
