# Remaining work

1. Finish browser playthrough checks: movement, combat, inventory, shops, quests, death, lockpicking, level transitions and ending. Add meaningful replay coverage when those scenarios are established.
2. Complete presentation for quick weapon/item selection, credits, travel/loading and unusual events. Ensure each touch-only flow has a working original-engine action and no phone interface leaks through the Remastered view.
3. Extend save checks to storage failures and longer sessions. Actual page-reload recovery and binary cross-target save parity already pass.
4. Measure full scenes in the browser on desktop and narrow/mobile layouts. Keep the original simulation rate and optimize rendering/transfer only when measurements justify it.
5. Refine original-art Remastered lighting: tune each location against the decoded catalog, improve transparent fences and sprite-to-sprite shadow reception, validate dynamic light sources throughout the game, and investigate indirect light within the performance budget. Profile Medium/High on more scenes and mobile devices; their actual geometry replay is now implemented. Classic remains exact.
6. Translate BREW resources into a separate Russian presentation catalog; retain original English resources. Expand the custom menu/UI translation.
7. Remove unused source/reference platform files only when the browser/native targets no longer need them; preserve provenance and GPL credits.
8. Publish verified updates at the same permanent Pages root on web-build. Keep build hashes and cache busting, preserve the legacy /brew/ redirect, and verify the live release after every publication.
