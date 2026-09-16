# Candidate Offer Decision Model

A DMN 1.5 implementation of [the candidate offer specification](../spec/candidate_offer.md).
Given one candidate for one role, it returns the salary to offer, every rule that
fired, and a plain-language rationale.

Each group of rules in the specification is its own DMN file. The executable
model, `candidate-offer.dmn`, imports them and wires them into one decision
requirements diagram.

## Files

| File | Specification | What it decides |
|---|---|---|
| `payroll-types.dmn` | Section 3 | Item definitions. Nothing else, so types are declared once and included everywhere. |
| `payroll-common.dmn` | — | Rounding, summing and rationale formatting. No business policy. |
| `offer-validation.dmn` | Section 3 | Whether the candidate record is fit to calculate from. |
| `salary-ranges.dmn` | Section 4 | The reference range for each of the 138 roles. |
| `base-salary.dmn` | Section 5 | Where the panel score places the candidate in that range. |
| `market-adjustment.dmn` | Section 7, group 1 | The index for each of the 68 markets. |
| `certification-bonus.dmn` | Section 8, group 2 | Which certifications count, and the cap of two. |
| `relocation-adjustment.dmn` | Section 9, group 3 | Relocation and work mode. |
| `experience-adjustment.dmn` | Section 10, group 4 | Experience and how hard the role is to fill. |
| `competitive-adjustment.dmn` | Section 11, group 5 | Verified competing offers, referrals, salary history. |
| `deductions.dmn` | Section 12, group 6 | Deductions, including the part-time pro-rate. |
| `guardrails.dmn` | Section 13, group 7 | Floors, caps, approval thresholds, internal equity. |
| `candidate-offer.dmn` | Section 14 | **The executable model.** Imports all of the above. |

Every rule file exposes business knowledge models, not decisions, so the main
model invokes them as functions and there is no hidden dependency on input data
defined somewhere else.

## Running it

The models need no build. To evaluate them, install
[jbang](https://www.jbang.dev) and run the test cases from this directory:

```
jbang tests/RunTests.java        # add -v to print each rationale
```

That compiles all thirteen models with the Drools DMN engine and checks them
against `tests/candidate-offer-tests.xml`. To use the models from an
application, load the whole directory and evaluate the `Candidate Offer`
decision in namespace `https://aletyx.ai/dmn/payroll/candidate-offer`, with a
single input named `Candidate`.

## Tests

`tests/candidate-offer-tests.xml` holds eleven cases. Cases A to G are the seven
worked examples in section 15 of the specification, so the model and the document
cannot drift apart without a test failing. Cases H to K cover paths the document
does not work through: a validation rejection, a matched competing offer, a
part-time pro-rate, and an internal equity hold.

## How this follows the eight practices

1. **Every decision points back to its source.** Each decision and business
   knowledge model names its specification section, and every decision table row
   carries the rule identifier in an annotation column. The identifiers also
   travel in the output: `appliedRules` lists what fired, with the amount.
2. **Knowledge sources.** Each rule file has a knowledge source whose
   `locationURI` links to the section of the specification it implements, so a
   change to the document can be traced to the models that implement it.
3. **The rationale, not just the result.** Every rule module returns
   `tModifierResult`: the amount, the rules behind it, and any review it
   triggered. The final decision turns those into a readable rationale.
4. **Validation is separate from policy.** `offer-validation.dmn` traps bad data
   at the boundary. No policy model contains a validation test.
5. **Every type is constrained.** There is no open string input. Role codes,
   market codes, certifications, work modes and statuses are enumerations;
   scores, money, years and fractions are constrained ranges. `tRuleId`
   enumerates all 143 rule identifiers the specification defines, so an amount
   cannot be attributed to a rule that does not exist.
6. **One decision, one job.** Looking up a range, choosing a band, finding the
   band anchors and interpolating are four separate nodes rather than one
   expression.
7. **The tests ship with the model**, in `tests/`.
8. The models were generated from the specification tables, with these rules
   held in the prompt.

## Two things to know before using this

**Group order.** The specification applies group 5, competitive position, before
group 6, deductions. It cannot be executed in that order, because MOD-CMP-01
matches a competing offer against the whole offer, which is not known until the
deductions are in. The model evaluates group 5 after group 6 and before the
guardrails. `Subtotal Before Competitive` documents this.

**The floor is not pro-rated.** MOD-DED-03 pro-rates a part-time offer, then
GRD-01 raises anything below the market-adjusted role minimum back up to it. A
part-time offer is therefore pulled back to a full-time floor, as test case J
shows. The model implements the specification as written; the specification
needs a decision on whether GRD-01 should be pro-rated too.

The salary figures and market indices come from the specification and are
illustrative placeholders. They need real survey data before any live use.
