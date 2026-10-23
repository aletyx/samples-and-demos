# The window

[BattleScreen](../roborules_app/lib/ui/battle_screen.dart), in the look of
Robocode's Java Swing window ([classic.dart](../roborules_app/lib/ui/classic.dart)):
light gray panels, beveled buttons, a blue gradient title bar, "RoboRules:
Robocode-style battles, every turn played by aityx".

- **Menu bar**: **Battle** (New…, Start, Pause/Resume, Stop, Results…),
  **Robot** (each robot's rules), **Options** (speeds), **Help** (the last
  aityx call, About).
- **Battlefield** ([painter.dart](../roborules_app/lib/battle/painter.dart)),
  800 × 600 scaled to fit: dark ground with a faint speckle and grid;
  tanks with two treads (moving with the tank), a body in the robot's color
  turned to its heading, a turret and barrel turned to the gun, a radar
  dish sweeping; energy above, name and the rule it follows below; glowing
  bullets sized by power; orange explosions for hits and bigger ones for
  deaths. Positions and angles ease between turns. Messages over it: how
  to start, "aityx is playing the next turns…", "Round n is over: aityx is
  scoring it…".
- **Robots**, on the right (below on a narrow window): round and turn, and
  a button per robot: color, name (struck through when dead), energy and a
  green, amber or red bar, and the rule it follows now with its reason, or
  its rule count and score. Its tooltip lists its rules; selecting it opens
  the [rules editor](robots.md#the-rules-editor).
- **Controls**: Start/Pause/Resume, Next turn, Stop, Restart, New battle…,
  **Speed** (1 to 60 turns a second, or Max), aityx's measured turns a
  second, **aityx call**, and any error (a failed call pauses the battle
  until Resume).
- **Dialogs**: **New Battle** (robots 2–10, two by default; rounds 1–10,
  three by default), **Results** (Rank, Robot Name, Total Score, Survival,
  Surv Bonus, Bullet Dmg, 1sts, the winner highlighted), and **The last
  aityx call**, Contact Hub's viewer in aityx's dark theme with each
  robot's rules, the turn's steps, the world and the frames labeled.
