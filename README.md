# aityx demos

Working examples of business automation with aityx: processes, decision
models, and applications built around them. Each folder is a self-contained
sample with its own documentation.

| Sample | What it shows | Launch |
|---|---|---|
| [Mortgage Hub](MortgageHub/) | A mortgage application from request to verdict: a Flutter app, a Dart API, and a decision model run by [aityx.ai](https://aityx.ai) | [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/aletyx/samples-and-demos?devcontainer_path=.devcontainer%2Fdevcontainer.json&machine=standardLinux32gb) (every demo) |
| [Contact Hub](ContactHub/) | Ask anything and have it routed to the right department or person. A request, typed or dictated on the device, routed by Jev and an aityx decision model: a Flutter app and a Dart API | [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/aletyx/samples-and-demos?devcontainer_path=.devcontainer%2FContactHub%2Fdevcontainer.json&machine=standardLinux32gb) |
| [Life Hub](LifeHub/) | Conway's Game of Life on an infinite board, with the rules, and a catalogue of its patterns, as an aityx decision model: one aityx call per generation, shown request and response in a side panel; a Flutter app and a Dart API | [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/aletyx/samples-and-demos?devcontainer_path=.devcontainer%2FLifeHub%2Fdevcontainer.json&machine=standardLinux32gb) |
| [RoboRules](RoboRules/) | A web take on the old Robocode: robots whose behavior is an aityx decision model, fighting battles played turn by turn by aityx | [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/aletyx/samples-and-demos?devcontainer_path=.devcontainer%2FRoboRules%2Fdevcontainer.json&machine=standardLinux32gb) |
| [PokerFace](PokerFace/) | A poker simulator where every player is a set of rules run by [aityx.ai](https://aityx.ai): no-limit hold'em at a table of nine, every aityx call in a sidebar, the pace in your hands, and strategies you can read or write. A Flutter app and a Dart API | [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/aletyx/samples-and-demos?devcontainer_path=.devcontainer%2FPokerFace%2Fdevcontainer.json&machine=standardLinux32gb) |
| [Index](Index/) | One page linking every demo, in the aityx palette, saying which ones are up; `./start-all.sh` starts it with the rest on http://localhost:8800/ | `./start-all.sh`, or [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/aletyx/samples-and-demos?devcontainer_path=.devcontainer%2Fdevcontainer.json&machine=standardLinux32gb) (every demo) |
| [Payroll](Payroll/) | A large rule base with some intricate rules, as payroll and HR systems have, written as DMN decision models | Open the `.dmn` files in your editor |
| [Mortgage Process](Mortgage_Process/) | A loan approval process in BPMN2 with a decision table, business rules and forms | Import into Business Central or VS Code |

## Run all the demos

The demos that run as services, Mortgage Hub, Contact Hub and any other
folder with a `devbox.json` and a `process-compose.yaml`, start together
from the root of this repository with [Devbox](https://www.jetify.com/devbox):

```bash
./start-all.sh              # every demo, detached; waits until each answers
./start-all.sh ContactHub   # only the ones named
./stop-all.sh               # stops them all; ./stop-all.sh ContactHub only one
```

[start-all.sh](start-all.sh) runs `devbox services up -b` in each folder
and then prints where to open each app once its web app and API answer;
the first start compiles each app, which takes a few minutes. A demo
that already answers on its port, started by hand or with Docker
Compose, is left as it is. Each demo reads its aityx settings from its
own `.env` (see each folder's `.env.example`): `AITYX_API_KEY`, the key,
and `AITYX_URL`, the endpoint, `https://api.aityx.ai` unless set; a
stage key needs `AITYX_URL=https://api-stage.aityx.ai`. Watch one demo's
services with
`devbox services attach -c <demo>`; [stop-all.sh](stop-all.sh) runs
`devbox services stop` in each folder that is running.

The same, in a codespace: the repository's default dev container,
[.devcontainer/devcontainer.json](.devcontainer/devcontainer.json),
builds every demo's toolchain and runs `./start-all.sh` on each start.
It needs your own `AITYX_API_KEY` Codespaces secret (see
[Launching it](#launching-it) below) and the 8-core machine, since six
apps compile at once.

[![Open every demo in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/aletyx/samples-and-demos?devcontainer_path=.devcontainer%2Fdevcontainer.json&machine=standardLinux32gb)

Once it starts, the index page opens on port **8800** and shows each
demo as it comes up, with a link to it; the apps' ports (8880 to 8920)
are in the **Ports** panel too, made public so the links can be shared.
Every step of the start goes to `startup.log` at the root. The other
dev containers in the list, one per demo, start only that demo.

## Mortgage Hub

[MortgageHub/](MortgageHub/) brings a home buyer's mortgage, from
application to closing, into one place. A buyer fills in a proposal
request, and a regulatory check says whether a lender can process it under
current US rules — Fannie Mae's eligibility matrix, the 2026 FHFA and FHA
limits, FHA, VA and USDA rules and DTI limits — executed as a decision
model on [aityx.ai](https://aityx.ai).

| Part | Technology |
|---|---|
| App | [Flutter](https://flutter.dev): web, Android, iOS and Linux from one codebase |
| API | Dart (`dart:io`); holds the [aityx](https://aityx.ai) key and runs the check |
| Rules | An [aityx.ai](https://aityx.ai) decision model |
| Dev environment | [Devbox](https://www.jetify.com/devbox) (Nix) in a [dev container](https://containers.dev/) |

### Launching it

**You need your own [aityx.ai](https://aityx.ai) API key, and it is
required.** No key ships with this repository. Without one the codespace
still starts and the app still opens, but the regulatory check — the point
of the demo — cannot run.

Add it before launching: go to
[github.com/settings/codespaces](https://github.com/settings/codespaces),
choose **New secret** under *Codespaces secrets*, name it exactly
`AITYX_API_KEY`, and give it access to this repository. If you skip this,
GitHub asks for it on the codespace creation page. The
[Mortgage Hub README](MortgageHub/README.md#run-it-in-a-codespace) shows
both screens, the secret form and the creation page.

[![Open every demo in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/aletyx/samples-and-demos?devcontainer_path=.devcontainer%2Fdevcontainer.json&machine=standardLinux32gb)

That opens the repository's default dev container, **All demos**, on an
8-core machine (32 GB RAM): it starts Mortgage Hub with every other demo
and the index page. If you create the codespace yourself through *Code →
Codespaces → New with options*, keep **All demos** as the dev container
configuration; the others start one demo each.

Once it starts, the apps start too: when Mortgage Hub has compiled, a
few minutes on the first start, open port **8880** from the **Ports**
panel, or from its card on the index page (port **8800**, opened for
you). Check that the port's visibility says **Public**, so the link can
be shared; if it says Private, right-click it and choose **Port
Visibility → Public**. The full instructions, including running it
without a codespace, are in the
[Mortgage Hub README](MortgageHub/README.md).

### Running it locally

Put your key in `MortgageHub/.env` (copy
[MortgageHub/.env.example](MortgageHub/.env.example)) or export
`AITYX_API_KEY`. Then, from the root of this repository, either:

```bash
# With Docker alone: builds the web app and the API, then starts both
docker compose -f MortgageHub/compose.yaml up --build

# Or with Devbox: the Flutter dev server (hot reload), the API and a health monitor
devbox services up -c MortgageHub --pcflags "--tui=false"
```

Both serve the app at http://localhost:8880/app/. Stop them with
`docker compose -f MortgageHub/compose.yaml down` or
`devbox services stop -c MortgageHub`.

## Contact Hub

[ContactHub/](ContactHub/) will let someone ask anything and route the
question to the right department or person, with its checks run on the
way. Built like Mortgage Hub: a Flutter app takes the request (typed,
dictated with speech recognized in the browser, or picked from samples),
and a Dart API routes it with one aityx call, in which Jev classifies and
checks the message and a decision model picks the department, the person
and the priority. The app shows why, and the aityx call, with links to
exactly the JSON behind each item. Put your key in `ContactHub/.env`
(see [.env.example](ContactHub/.env.example)), then, from the root of this
repository:

```bash
devbox services up -c ContactHub --pcflags "--tui=false"
# or, with Docker alone
docker compose -f ContactHub/compose.yaml up --build
```

Both serve the app at http://localhost:8890/app/, so it runs alongside
Mortgage Hub. The badge above opens it in a codespace, which uses the same
`AITYX_API_KEY` Codespaces secret as Mortgage Hub. See the
[Contact Hub README](ContactHub/README.md).

## RoboRules

[RoboRules/](RoboRules/) is a web take on the old Robocode, in its look:
tanks fight on a dark battlefield until one is left. Each robot's behavior
is an aityx decision model, a table of rules over what it senses (the
nearest enemy's distance and bearing, walls, energy, its gun) that sets how
it drives, turns, aims and fires; select a robot to change its rules. The
battle itself is played by aityx: one call plays up to 50 turns of sensing,
every robot's rules, Robocode's motion, bullets, collisions and damage, and
another scores each round. Put your key in `RoboRules/.env`, then:

```bash
devbox services up -c RoboRules --pcflags "--tui=false"
# or, with Docker alone
docker compose -f RoboRules/compose.yaml up --build
```

and open http://localhost:8920/app/. Its ports are its own, so it runs at
the same time as Mortgage Hub (8880) and Contact Hub (8890). See the
[RoboRules README](RoboRules/README.md).

## Life Hub

[LifeHub/](LifeHub/) plays Conway's Game of Life on an infinite board,
with the rules of the game as a decision model on aityx. Built like
Contact Hub: a Flutter app draws the board (drag, zoom, tap to draw,
**Random start**, **Play** and an **Acceleration** control from half a
generation a second to as fast as aityx answers), and a Dart API runs
each generation as one aityx call, in which a decision table decides the
fate of every situation on the board, with a why on every row, and a
pattern catalogue names the well-known patterns (still lifes,
oscillators, spaceships, methuselahs) among the clusters of live cells.
The app labels the patterns on the board, notifies when one appears, and
shows every call, request and response, in a side panel. Conway's rules
are on at the start; HighLife's birth with six neighbours and Life without
death can be switched on. Put your key in `LifeHub/.env` (see
[.env.example](LifeHub/.env.example)), then, from the root of this
repository:

```bash
devbox services up -c LifeHub --pcflags "--tui=false"
# or, with Docker alone
docker compose -f LifeHub/compose.yaml up --build
```

Both serve the app at http://localhost:8900/app/, so it runs alongside
the other two. The badge above opens it in a codespace, which uses the
same `AITYX_API_KEY` Codespaces secret. See the
[Life Hub README](LifeHub/README.md).

## PokerFace

[PokerFace/](PokerFace/) is a poker simulator, no-limit Texas hold'em at
a table of up to nine, where every player is a set of rules: a decision
model run on [aityx.ai](https://aityx.ai) at each turn, on the player's
situation as the app computes it (cards, hand, equity, pot odds,
position, a random number for mixed play). Five strategies come with it,
the Rock, the Maniac, the Calling Station, the Mathematician and the
Shark, each a file of rules; add players with any of them, read the
rules, or write your own. The table plays like an online poker room, a
sidebar shows every call to aityx with its request and response, and a
slider sets the pace. Put your key in `PokerFace/.env` (see
[.env.example](PokerFace/.env.example)), then, from the root of this
repository:

```bash
devbox services up -c PokerFace --pcflags "--tui=false"
# or, with Docker alone
docker compose -f PokerFace/compose.yaml up --build
```

Both serve the app at http://localhost:8910/app/, alongside the other
samples. The badge above opens it in a codespace, with the same
`AITYX_API_KEY` Codespaces secret. See the
[PokerFace README](PokerFace/README.md).

## Payroll

[Payroll/](Payroll/) is built to show what a decision model looks like when
there are many rules and some of them are complicated, as is usual in
payroll and HR systems. It takes a written compensation policy, with
hundreds of rows of reference data, modifiers applied group by group,
and guardrails that floor, cap or hold the result, and turns it into a
decision model you can execute.

- [spec/candidate_offer.md](Payroll/spec/candidate_offer.md): how much to
  offer a candidate, in plain language — salary ranges for 138 roles,
  seniority bands, 68 market indices, and the modifier rules for
  certifications, relocation, experience, competing offers and deductions.
  Every rule has an identifier.
- [decisions/](Payroll/decisions/): the same policy as 13 DMN models,
  one per rule group, imported by `candidate-offer.dmn`. It returns the
  amount to offer together with every rule that fired and a
  plain-language rationale.

The models need no build. With [jbang](https://www.jbang.dev) installed,
`jbang tests/RunTests.java` from `Payroll/decisions/` runs the 11 test
cases, seven of which reproduce the worked examples in the specification.

## Mortgage Process

[Mortgage_Process/](Mortgage_Process/) is a getting-started loan approval
process in BPMN2, with a decision table, business rules and forms. It is a
Maven `kjar`, built with the KIE Maven plugin and deployed to a KIE Server
or opened in Business Central.

## License

[MIT](LICENSE).
