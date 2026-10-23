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
