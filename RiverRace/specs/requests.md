# Requests

The requests that shaped RiverRace, oldest first, each with what changed.
The feature files hold the current specification; see the
[index](README.md).

## 2026-10-28

1. **Build a new aityx demo with Cellfie's structure, other ports and
   content: a remake of the Atari 2600 River Raid, as in the original, but
   with two planes on screen at once, in different colors, each flying by
   a different strategy (a set of rules), to see which strategy wins; the
   user explores each plane's strategy, adding and removing rules, and a
   sidebar shows every event sent to and received from aityx.** Added
   `RiverRace/` (group `aityx`, ports 8940 and 8941), copied from Cellfie's
   scaffolding (scripts, process-compose, Docker Compose, dev container,
   Makefile, the calls panel's JSON view): the [game](game.md) in the app,
   the [strategies](strategies.md) with their pilot cards and rule editor,
   the [decisions](decisions.md) asked of aityx through the
   [API](api.md)'s `POST /api/decide`, and the [calls panel](calls-panel.md).
   Named RiverRace, not after the original. Added to the Index page, the
   root README, the default dev container's ports and the aityx group's
   scripts.
2. **Make it three planes: two automated with different strategies, and
   one the user flies; the user's plane opaque, the computer ones more
   transparent.** The yellow plane is the player's (arrow keys and space),
   drawn solid; the aityx pilots' cyan and magenta planes are drawn at
   half opacity. **You fly** lets the two aityx pilots race alone. Since a
   person plays in real time, the game doesn't wait for aityx unless
   **Fair race** is on (see [Decisions](decisions.md)).
3. **Make the GIF, and add RiverRace to the Index page, the Dockerfile
   and the blog post.** Recorded `riverrace.gif` for the aityx launch post
   in the docs repo, and added RiverRace to it beside the other demos. The
   Index page already had its card. Docker Compose (`docker compose up
   --build`) was run: both images build and answer; the published dev
   container image carries RiverRace's web build once its app is
   committed, as it does every demo's, with no change to the
   `Containerfile`.
4. **Wait for a keypress to start.** Any key starts the race, goes on
   after a pause, or starts another race once one is over (see
   [Game](game.md#playing)).
5. **Make the computer planes a little more transparent.** The aityx
   pilots' planes are drawn at 35% opacity, down from half.
6. **Don't say how many planes on the start screen, just "Press any key
   to play", and make that work: there are two or three planes depending
   on whether the user plays.** The start screen says only *Press any key
   to play*. The game's keys are read app-wide, so a key plays even when
   a control just clicked has the focus (space used to toggle it); not
   while a dialog or menu is open. Recorded the GIF again for the blog
   post.
