# Remaining work

1. Finish browser playthrough checks: movement, combat, inventory, shops, quests, death, lockpicking, level transitions and ending. Add meaningful replay coverage when those scenarios are established.
2. Complete presentation for quick weapon/item selection, credits, travel/loading and unusual events. Ensure each touch-only flow has a working original-engine action and no phone interface leaks through the Remastered view.
3. Extend save checks to storage failures and longer sessions. Actual page-reload recovery and binary cross-target save parity already pass.
4. Measure full scenes in the browser on desktop and narrow/mobile layouts. Keep the original simulation rate and optimize rendering/transfer only when measurements justify it.
5. Build a BREW-only resource manifest for textures/sprites. Add HD overrides and the actual Remastered renderer while keeping Classic exact and one shared simulation/save store.
6. Translate BREW resources into a separate Russian presentation catalog; retain original English resources. Expand the custom menu/UI translation.
7. Remove unused source/reference platform files only when the browser/native targets no longer need them; preserve provenance and GPL credits.
8. Continue publishing verified BREW previews at `/brew/`. Promote BREW to the Pages root after full-port validation. The source is now on GitHub and the first public BREW preview has been verified live.
