# Requests

The requests that shaped RoboRules, oldest first, each with what changed.

## 2026-10-23

1. **Make a clone of the old Robocode where each robot's behavior is
   defined by rules; populate it with random robots to begin with;
   selecting a robot lets you change its rules; see which rules win the
   match; the number of robots configurable, two by default; make it look
   as much as possible like Robocode, but on the web. Robot behavior in
   aityx format and the game run by aityx, including motion and
   collisions if possible, no problem if it runs slow, with a control to
   make it slower or faster. Make sure the ports don't clash, so all the
   demos can run at once.** Added RoboRules: a Flutter web app in
   Robocode's Swing look and a Dart API. Each robot is an aityx model (its
   sensors as inputs, a FIRST table of commands), random to begin with,
   editable as cards or JSON. The battle is one aityx model
   ([The battle](battle.md)): sensing, every robot's rules, Robocode's
   motion, bullets, collisions, damage and deaths, played up to 50 turns a
   call; the score is another ([Scoring](scoring.md)). A Speed control
   from 1 to 60 turns a second, or as fast as aityx plays them. Ports
   8920/8921: Life Hub and Poker Hub in this folder already use 8900/8901
   and 8910/8911.
2. **Fix what the code review found.** A battle started after a finished
   one now plays (the round-end flag is cleared on reset); a reply still
   in flight when a battle is restarted or stopped is dropped, not applied
   to the new one; a round aityx fails to score waits with **Retry
   scoring** instead of being left out of the totals; the editor's JSON is
   checked as the battle checks robots, with an error instead of a crash;
   `make` builds only the web app, the only platform.

3. **Use custom favicons for each sample, in the same style and colors
   as aityx but related to each demo.** RoboRules had Flutter's default
   icons. It now has a tank seen from above: `web/favicon.svg`, a flat
   orange glyph with no background as aityx.ai's own favicon is drawn,
   first in `index.html`; and the tile, orange on the dark background,
   rendered from `assets/icon/icon.svg` as `favicon.png` and the
   manifest's icons. See [App icon](app-icon.md).

4. **Let the user add or remove bots, picking from the predefined ones,
   and customize them.** Added the [predefined robots](robots.md#predefined-robots):
   Robocode's sample robots (SittingDuck, Fire, SpinBot, Walls, Tracker,
   RamFire, TrackFire, MyFirstRobot, Crazy) written as rules, plus a random
   one. **New Battle** is now Robocode's: available robots on the left,
   selected on the right, Add, Remove, Remove all and Edit rules… between,
   what the highlighted robot does below; it opens with the battle's
   current robots, so customizations survive. Between battles the robots
   panel has an **×** on each robot and **Add robot…** (a picker), and the
   Robot menu Add a robot… and Remove …; the editor's **Rules from…**
   replaces a robot's rules with a predefined robot's or random ones. Two
   to ten robots; a second robot of a kind is "Walls 2" in another color.
5. **Add a view of all events, not only the last one; it can be below the
   robots' cards.** Added the **Events** log under the robots: every rule
   change, hit, loss, round start, end and score, the winner, failures,
   and every aityx call, the last ten of which open in the viewer from
   their line ([The window](window.md)).
6. **Do not use "dead"; better use "lost".** A robot out of the round is
   "lost" everywhere the app says it.

## 2026-10-27

7. **Make the demos efficient enough for a 4-core codespace: serve a
   release build instead of running the Flutter dev server, and compile
   the API.** `devbox services up` now serves the app's release build
   with a small native web server (`roborules_api/bin/web_server.dart`:
   `/app/` from `build/web`, `/api/` and `/` proxied to the API, as nginx
   does under Docker Compose) and runs the API compiled with `dart
   compile exe`, which finds `models/` beside its binary as in the Docker
   image; both come from `scripts/build.sh`, which builds only what
   changed and runs one Flutter web build at a time across the
   repository. Resident memory drops from about 1 GB to about 27 MB, and a
   start after no change takes a second. Hot reload stays with
   `WEB_MODE=debug` or `devbox run web`. See
   [Development environment](dev-environment.md).
