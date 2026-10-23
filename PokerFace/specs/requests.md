# Requests

The requests that shaped PokerFace, oldest first, each with what changed.
The feature files hold the current specification; see the
[index](README.md).

## 2026-10-23

1. **Another sample, a poker simulator much like PokerStars or online
   poker, but with the player rules defined by aityx. As in the others,
   show the requests and responses in a sidebar, let the user accelerate
   or slow the game, and add players with different strategies defined
   as rules. Call it PokerFace.** Added `PokerFace/`, built like Contact
   Hub and Life Hub: a Flutter app (`pokerface_app`, web, Android, iOS
   and Linux) and a Dart API (`pokerface_api`), devbox, process-compose
   and the health monitor, the Makefile, Docker Compose, and the dev
   container in `.devcontainer/PokerFace/`, on ports 8910 and 8911 (see
   [Development environment](dev-environment.md)). The app plays no-limit
   Texas hold'em for up to nine players, with blinds, betting rounds,
   side pots, showdowns and rebuys, and shows it on a felt with everyone's
   cards face up ([The table](table.md)). Every decision is one aityx
   call: the app computes the player's situation (cards, hand class, made
   hand, draws, equity by Monte Carlo, pot, pot odds, position, players
   to act, a random number) and the API runs the player's strategy on it
   ([Strategies](strategies.md), [API](api.md)). Five preset strategies,
   each a file of rules with a `why` per row: the Rock, the Maniac, the
   Calling Station, the Mathematician and the Shark, verified on aityx by
   `scripts/model-test.sh`. The sidebar lists every call with the
   situation, the action, the rule that fired and its reason, and opens
   the full request and response with the key parts marked, in the same
   viewer as Contact Hub's; a second tab holds the hand log ([The aityx
   calls](calls.md)). Play, pause and step, a pace slider from 4 s
   between steps down to full speed, rebuys and reset. The players panel
   adds players by name and strategy, changes a player's strategy, removes
   players, shows every strategy's rules, and has an editor to write a
   strategy of your own from a preset, with **Try it on aityx** ([Players
   and strategies](players.md)). The [theme](theme.md) is the aityx
   palette with a green felt; the [app icon](app-icon.md) an orange ace of
   spades with a chip.
