# Remaining work

1. Finish browser playthrough checks: movement, combat, inventory, shops, quests, death, lockpicking, level transitions and ending. Add meaningful replay coverage when those scenarios are established.
2. Complete quick weapon/item selection and review unusual events. Credits, travel labels, notebook and item descriptions now use the separate presentation; check later-game and touch-only flows in longer sessions.
3. Extend save checks to unavailable/quota-limited storage and longer sessions. Page reload, binary cross-target parity and backup download/import pass; a corrupted backup is rejected without changing saves.
4. Measure full scenes in the browser on desktop and narrow/mobile layouts. Keep the original simulation rate and optimize rendering/transfer only when measurements justify it.
5. Refine original-art Remastered lighting: tune each location against the decoded catalog, improve transparent fences and sprite-to-sprite shadow reception, validate dynamic light sources throughout the game, and investigate indirect light within the performance budget. Profile Medium/High on more scenes and mobile devices; their actual geometry replay is now implemented. Classic remains exact.
6. Review Russian phrasing and rare dynamically assembled text during a full playthrough. All 1690 original string records now have translations; separate Cyrillic intro/ending text masks and runtime language changes are implemented. Catalog coverage does not replace a whole-game linguistic review.
7. Remove unused source/reference platform files only when the browser/native targets no longer need them; preserve provenance and GPL credits.
8. Publish verified updates at the same permanent Pages root on web-build. Keep build hashes and cache busting, preserve the legacy /brew/ redirect, and verify the live release after every publication.
