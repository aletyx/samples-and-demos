# aityx demos

Working examples of business automation with aityx: processes, decision
models, and applications built around them. Each folder is a self-contained
sample with its own documentation.

| Sample | What it shows | Launch |
|---|---|---|
| [Mortgage Hub](MortgageHub/) | A mortgage application from request to verdict: a Flutter app, a Dart API, and a decision model run by [aityx.ai](https://aityx.ai) | [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/aletyx/samples-and-demos?devcontainer_path=.devcontainer%2Fdevcontainer.json&machine=standardLinux32gb) (every demo) |
| [Contact Hub](ContactHub/) | Ask anything and have it routed to the right department or person. A request, typed or dictated on the device, routed by Jev and an aityx decision model: a Flutter app and a Dart API | [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/aletyx/samples-and-demos?devcontainer_path=.devcontainer%2FContactHub%2Fdevcontainer.json&machine=standardLinux32gb) |
| [Cellfie](Cellfie/) | The cells take a picture of themselves every generation, and aityx says who's in it: Conway's Game of Life on an infinite board, with the rules and pattern catalogue as an aityx decision model; one call per generation, with the board and every request and response shown in the app | [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/aletyx/samples-and-demos?devcontainer_path=.devcontainer%2FCellfie%2Fdevcontainer.json&machine=standardLinux32gb) |
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
Compose, is left as it is. The script checks for `AITYX_API_KEY` and
warns if it is missing; the apps still open, but their aityx-backed
features won't work. It passes `AITYX_API_KEY` and `AITYX_URL` from the
environment to each API service. API scripts prefer those values and
fall back to that demo's `.env` (see each folder's `.env.example`).
`AITYX_URL` defaults to `https://api.aityx.ai`; a stage key needs
`AITYX_URL=https://api-stage.aityx.ai`. Watch one demo's services with
`devbox services attach -c <demo>`; [stop-all.sh](stop-all.sh) runs
`devbox services stop` in each folder that is running.

The same, in a codespace: the repository's default dev container,
[.devcontainer/devcontainer.json](.devcontainer/devcontainer.json),
builds every demo's toolchain and runs `./start-all.sh` on each start.
It needs your own `AITYX_API_KEY` Codespaces secret and, optionally, an
`AITYX_URL` secret (see [Launching it](#launching-it) below) and the
8-core machine, since six apps compile at once.

[![Open every demo in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/aletyx/samples-and-demos?devcontainer_path=.devcontainer%2Fdevcontainer.json&machine=standardLinux32gb)

Once it starts, the index page opens on port **8800** and shows each
demo as it comes up, with a link to it; the apps' ports (8880 to 8930)
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

**You need your own [aityx.ai](https://aityx.ai) API key.** No key ships
with this repository. Without one the codespace still starts and the app
still opens, but the regulatory check — the point of the demo — cannot run.

Add it before launching: go to
[github.com/settings/codespaces](https://github.com/settings/codespaces),
choose **New secret** under *Codespaces secrets*, name it exactly
`AITYX_API_KEY`, paste your own key, and give it access to this repository.
For a non-default endpoint, add an `AITYX_URL` secret and set it to
`https://api-stage.aityx.ai` for a stage key; leave it unset to use
`https://api.aityx.ai`. Give it access to this repository too. The
[Mortgage Hub README](MortgageHub/README.md#run-it-in-a-codespace) shows
the secret setup and codespace creation. The all-demos launcher passes
both values to each API service; they are not written to disk or logged.
The same secrets can be used for every demo.

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

## Cellfie

[Cellfie/](Cellfie/) plays Conway's Game of Life on an infinite board,
with the rules and pattern catalogue run as an aityx decision model.
Each generation is one aityx call: the app sends the board's situations
and clusters, displays the next generation, labels recognized patterns,
and shows the full request and response in a side panel. Choose a random
soup, islands, a glider fleet, a pattern zoo or a methuselah, then play
at a chosen acceleration or step one generation at a time. The rule
switches include Conway, HighLife and Life without death.

Put your `AITYX_API_KEY` in `Cellfie/.env` for local use (see
[Cellfie/.env.example](Cellfie/.env.example)), or use the Codespaces
secrets described above. To start it locally from the repository root:

```bash
devbox services up -c Cellfie --pcflags "--tui=false"
# or, with Docker alone
docker compose -f Cellfie/compose.yaml up --build
```

Both serve the app at http://localhost:8930/app/, alongside the other
samples. See the [Cellfie README](Cellfie/README.md).

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

## Cellfie

[Cellfie/](Cellfie/) plays Conway's Game of Life on an infinite board:
each generation, the cells take a picture of themselves and aityx says
who's in it. Its decision model applies the rules and recognizes known
patterns. The Flutter app draws the board, labels patterns, and shows
each request and response; the Dart API makes one aityx call per
generation. Put your key in `Cellfie/.env` (see
[.env.example](Cellfie/.env.example)), then, from the root:

```bash
devbox services up -c Cellfie --pcflags "--tui=false"
# or, with Docker alone
docker compose -f Cellfie/compose.yaml up --build
```

The app serves at http://localhost:8930/app/. The badge above opens it
in a Codespace. See the [Cellfie README](Cellfie/README.md).

## Life Hub

[LifeHub/](LifeHub/) plays Conway's Game of Life on an infinite board,
with the rules and pattern catalogue as an aityx decision model. Its
Flutter app draws the board (drag, zoom, tap to draw, **Random start**,
**Play** and an **Acceleration** control), and its Dart API runs each
generation as one aityx call. The app labels patterns on the board,
notifies when one appears, and shows every call, request and response
in a side panel. HighLife's birth with six neighbours and Life without
death can be switched on. Put your key in `LifeHub/.env` (see
[.env.example](LifeHub/.env.example)), then, from the root:

```bash
devbox services up -c LifeHub --pcflags "--tui=false"
# or, with Docker alone
docker compose -f LifeHub/compose.yaml up --build
```

The app serves at http://localhost:8900/app/. See the
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
