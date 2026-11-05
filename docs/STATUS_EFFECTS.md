# Timed modifiers in the custom HUD

The gameplay already applied status effects; only the custom presentation was
missing. The host now reads the same `Player.buffs[12]` entries used by the
original `Player_drawBuffs`, after the native status-to-modifier aggregation.
It never ticks effects, changes stats or writes saved state.

The original icon atlas is BAR resource 3030, Icons_Buffs.bmp (12×144). The UI
build decodes its twelve 12×12 cells, with the original RGB565 conversion and
magenta transparency. Derived PNGs remain in ignored ui/generated/effects.
The ordered identities are Familiar, Avoidance, Remedy, Haste, the reserved
modifier slot 4, Regeneration, Accuracy, Strength, Defense, Frozen, Poisoned and
Shrunk. Familiar energy is listed only while possessing, as in the original.

Compound effects can contribute to several modifiers. The native engine sums
their amounts and reports the nearest underlying expiry; when that component
expires, the longer-lived component's duration becomes visible. Reading raw
status slots instead would incorrectly duplicate icons and report durations
that differ from the original modifier panel.

The custom column sits inside the top-left of the game view, at the user's
request. Rows are 58 units wide with a 23-unit pitch and 14-unit native icons.
The original signed amount appears at the left when applicable and remaining
turns at the right. Tooltip/accessibility labels identify effects in Russian or
English. Negative entries have warmer edging; icons gently pulse during the
last ten turns. Turn numbers stay readable instead of fading after a turn.
All active modifiers are shown, rather than the original six-row truncation.

The column is an overlay; it cannot alter the game's viewport or aspect ratio.
Enemy HP/events move beside it. Menus/story/map/death screens hide the column;
modal dialogue/lock views cover it with their ordinary shade. Updating graphics
quality changes only the world buffer, not icon sizes or effect counters.

## Checks

- tools/check_status_effects.cjs uses the QA-only core and original native APIs:
  positive/negative values, idle clock ticks, actual player turns, expiry,
  compound effects, familiar visibility, saved durations and getter purity.
- The ordinary native/WASM replay covers model, Classic world/full-frame pixels
  and binary saves.
- tools/check_status_layout.gd checks 24 combinations of viewport, graphics mode
  and modifier count, including twelve rows, with an unchanged world rectangle
  and no overlap between the column and enemy/event area.
- Visual browser verification is local only, following the user's preference.
