# Aletyx samples and demos

Working examples of business automation with Aletyx: processes, decision
models, and applications built around them. Each folder is a self-contained
sample with its own documentation.

| Sample | What it shows | Launch |
|---|---|---|
| [Mortgage Hub](MortgageHub/) | A mortgage application from request to verdict: a Flutter app, a Dart API, and a decision model run by [aityx.ai](https://aityx.ai) | [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/aletyx/samples-and-demos?devcontainer_path=.devcontainer%2FMortgageHub%2Fdevcontainer.json&machine=standardLinux32gb) |
| [Contact Hub](ContactHub/) | Ask anything and have it routed to the right department or person. A request, typed or dictated on the device, routed by Jev and an aityx decision model: a Flutter app and a Dart API | [![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/aletyx/samples-and-demos?devcontainer_path=.devcontainer%2FContactHub%2Fdevcontainer.json&machine=standardLinux32gb) |
| [Payroll](Payroll/) | A large rule base with some intricate rules, as payroll and HR systems have, written as DMN decision models | Open the `.dmn` files in your editor |
| [Mortgage Process](Mortgage_Process/) | A loan approval process in BPMN2 with a decision table, business rules and forms | Import into Business Central or VS Code |

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

[![Open Mortgage Hub in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/aletyx/samples-and-demos?devcontainer_path=.devcontainer%2FMortgageHub%2Fdevcontainer.json&machine=standardLinux32gb)

That opens the **Mortgage Hub** dev container on a 4-core machine (16 GB
RAM), which is what the Flutter and Nix builds want. This repository holds
several samples, so if you create the codespace yourself through *Code →
Codespaces → New with options*, pick **Mortgage Hub** as the dev container
configuration.

Once it starts, the app starts too: when it has compiled, a minute or
two on the first start, open port **8880** from the **Ports** panel.
Check that its visibility says **Public**, so the link can be shared; if
it says Private, right-click it and choose **Port Visibility → Public**.
The full
instructions, including running it without a codespace, are in the
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
