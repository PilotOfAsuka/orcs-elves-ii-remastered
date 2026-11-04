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
