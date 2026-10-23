# Robots

## A robot is an aityx model

[Robot.toModel](../roborules_app/lib/battle/model.dart):

- `inputs`: the 12 sensors, each with its type and meaning (see
  [The battle](battle.md#the-world-model)).
- `decisions.action`: a FIRST decision table. Its columns are the sensors
  its rules test, then `=> drive: ahead|back|stop`,
  `=> turn: left|right|none|toward_enemy|away_from_enemy|perpendicular`,
  `=> gun: aim|sweep_left|sweep_right|hold`, `=> fire: number [0..3]` and
  `# why`. A condition is an aityx test (`true`, `< 200`, `[0..30]`), `-`
  for any value.

It runs alone in aityx too, given the sensors as its state. Rules may also
be written as `{"when": {...}, "then": {...}, "why": "..."}`. The API refuses
an unknown sensor, a missing command, a command value it doesn't know and a
fire power outside 0 to 3 ([lib/battle.dart](../roborules_api/lib/battle.dart)),
since aityx takes any word in an output column as a value.

## Random robots

[RobotFactory](../roborules_app/lib/battle/random_robots.dart): a name and a
color not yet taken (24 names, 10 colors), and rules: usually "a wall ahead:
back off and turn" first, then two to five tactics in random order, each
with random numbers (fire when the enemy is in sight; stand and fire hard
when closer than 150–350 px; dodge across the line of fire when hit; run
under 20–50 energy; finish an enemy under 10–30; ram when closer than
80–150 px; cheap long shots beyond 300–500 px), then a fallback that always
matches (circle and sweep, head for the enemy, or circle it).

## The rules editor

Selecting a robot (or **Robot › Edit …'s rules**) pauses a running battle
and opens [RulesEditor](../roborules_app/lib/ui/rules_editor.dart): the
robot's name and color, and three tabs:

- **Rules**: a card per rule: its conditions (**When**, a sensor and its
  test; **+ condition** adds one; true/false for yes/no sensors), its
  commands (**Then**: drive, turn, gun, fire), and **Why**; move a rule up
  or down, delete it, **Add rule** (before the fallback), **Randomize
  rules**.
- **aityx model (JSON)**: the robot's model, one rule per line, editable;
  **Apply** reads it back (an error says why it isn't a robot model),
  **Copy**.
- **Sensors**: what each sensor means and how to write conditions.

**OK** keeps the changes; the battle uses them from its next batch of turns.
