# Samples and demos

Working examples of business automation: processes and decision models.
Each folder is a self-contained sample with its own documentation.

The aityx and datyx demos (Mortgage Hub, Contact Hub, Cellfie, RiverRace,
RoboRules, PokerFace, datyx, the datyx dashboard and HealthHub) have moved
to [aityx-labs/aityx-demos](https://github.com/aityx-labs/aityx-demos).

| Sample | What it shows | Open it |
|---|---|---|
| [Payroll](Payroll/) | A large rule base with some intricate rules, as payroll and HR systems have, written as DMN decision models | Open the `.dmn` files in your editor |
| [Mortgage Process](Mortgage_Process/) | A loan approval process in BPMN2 with a decision table, business rules and forms | Import into Business Central or VS Code |

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
