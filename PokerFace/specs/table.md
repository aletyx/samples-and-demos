# The table

[TableScreen](../pokerface_app/lib/table/table_screen.dart) is the app's
one screen: the table with its controls, and beside it, on a window at
least 1100 px wide, the sidebar of [aityx calls](calls.md); narrower, the
sidebar opens from the app bar's receipt icon as a bottom sheet. The app
bar says **PokerFace**, "every player is a set of rules, run on aityx",
and the build's version when the build sets `POKERFACE_VERSION`.

## What the table shows

[TableView](../pokerface_app/lib/table/table_view.dart): a green felt
with a wooden rail, and the seats on an ellipse around it, the first seat
at the bottom, clockwise. In the middle: the hand number and the street
(or, between hands, who won what, or what to do: "Press play to deal."),
the five board slots with the community cards as they come, and the pot.
Each seat shows the player's name, their strategy, their two hole cards
(everyone's cards are face up: it is a simulator, and the point is to
judge the rules), their stack in amber, and their last action ("Raises to
120", "Calls 40", "Folds", "Checks", "All in, 960", or the hand shown at
the showdown). The player to act has an orange ring and a spinner while
aityx decides; a folded player is dimmed; the winners of a hand get an
amber ring and "wins". The bet of the round sits in front of the seat as
an amber chip, and the dealer button as a white "D".

## The rules of the game

[PokerGame](../pokerface_app/lib/engine/game.dart) plays the hand one step
at a time: blinds and the deal, a decision, a street dealt, the showdown,
the end of the hand. Blinds are 5/10, everyone buys in for 1000. The
button moves one seat each hand; heads up the button posts the small
blind and acts first before the flop. Before the flop the player after
the big blind acts first and the big blind has its option; after it, the
first player after the button. A bet or a full raise reopens the round
for everyone else; a raise is at least the size of the last one (the big
blind to start), and a raise for less is made the minimum, or all in when
the stack doesn't reach it. When nobody can act any more (all in, or all
but one), the board runs out. At the showdown every level of commitment
is a pot, shared by the best hand among the players who reached it, so
side pots are paid right and chips nobody matched go back; odd chips go
to the first winner after the button. When everyone else folds, the last
player takes the pot without a showdown. A player who busts buys in
again for the next hand when **Rebuy when busted** is on (it is by
default), with the rebuy counted; otherwise they sit out as "busted". A
player added during a hand is dealt in at the next; one removed during a
hand leaves after it.

The hand evaluator ([evaluator.dart](../pokerface_app/lib/engine/evaluator.dart))
ranks any five, six or seven cards, with the wheel as a five-high
straight, and estimates a player's equity against the players still in
the hand by 200 random run-outs. It also classes the hole cards and spots
flush draws and straight draws, all for the [situation](strategies.md)
sent to aityx.

## What the strategy decides, made legal

The action aityx answers is played as it is when it is legal. Otherwise
the nearest legal action is played, and the call in the sidebar notes it:
a fold with nothing to call is a check; a call of nothing is a check; a
check facing a bet is a fold; a raise when none is possible (no chips
beyond the call, or nobody left to raise) is a call; a raise below the
minimum is made the minimum, and above the stack is all in.

## The controls

[ControlsBar](../pokerface_app/lib/table/controls_bar.dart), under the
table:

- **Play** / **Pause**: the table runs on its own, one step after
  another, each decision asked of aityx. It pauses by itself when a call
  fails (the error shows in a banner above the table) or when fewer than
  two players have chips.
- **Step**: one step while paused: a deal, a decision, a street, the end
  of a hand.
- The **pace slider**, slow on the left, fast on the right: the seconds
  between steps, from 4 s down to 0, "Full speed", where the only wait is
  aityx's answer. The end of a hand waits two and a half times as long,
  so the showdown can be read.
- **Rebuy when busted**: see above.
- **Players (n)**: opens [Players and strategies](players.md).
- **Reset**: everyone buys in again, the hand count, the calls and the
  log start over.

## Known limitations

- No human seat: every player is a strategy. Everyone's cards are face
  up.
- Blinds and the buy-in are fixed (5/10, 1000); no antes, no blind
  levels.
- The equity estimate is Monte Carlo with 200 run-outs, so it moves by a
  few points from one decision to the next in the same spot.
- The game lives in the browser tab: reloading the page starts over.
