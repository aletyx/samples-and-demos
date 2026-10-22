# Routing

**Send** opens the routing screen, which asks the API to route the
request and shows where it went, why, and the two calls behind it.

## How a request is routed

Two calls, by [lib/routing.dart](../contacthub_api/lib/routing.dart)
and [lib/reading.dart](../contacthub_api/lib/reading.dart) from
[models/routing.json](../contacthub_api/models/routing.json):

1. **The local model reads** (see [Reading with a local
   model](reading.md)): qwen3:1.7b, on Ollama, answers the model's five
   `questions` about the message:
   - `topic`, a **choice** among the departments' topics, each defined in
     plain words in its `criteria`, plus `other`, with its
     `topic_confidence`;
   - `request_kind`, a **choice** of what the customer wants done with
     their order (see [Order policy](order-policy.md));
   - `urgent_probability`, `sensitive_data_probability` and
     `abusive_probability`, yes/no questions answered as probabilities.
2. **aityx decides**: one call to `POST /v1/systemone` with the model's
   `decision` and, as the `state`, those six facts by name, the
   `message`, `today` and the `order` the message names (see [Order
   policy](order-policy.md)). The inputs are declared `from: "the local
   model's reading"`; aityx asks nothing itself, its receipt's
   `provenance` says `state` for every input. The **routing model** then
   decides, deterministically:
   - `urgent`, `sensitive_data`, `abusive`: the probability is at least
     `evidence_threshold`, 0.8;
   - `clear_topic`: the confidence is at least `confidence_threshold`, 0.6,
     and the topic isn't `other`;
   - `department` (a FIRST table): abuse goes to Trust & Safety whatever
     the topic; an unclear topic to General Inquiries; otherwise one row
     per topic; General Inquiries last;
   - `priority` (`low<normal<high`): high for abuse, sensitive data,
     urgency, a late package, and Trust & Safety or Legal; low for
     Marketing, Public Relations and Investor Relations; normal otherwise;
   - `response_hours`: 4 for high, 24 for normal, 48 for low;
   - `needs_review`: the topic is unclear, the message holds sensitive
     data or abuse, or the policy needs a person to approve it;
   - the store's policy for the order: see [Order policy](order-policy.md).

The API reads the department and priority from `answers`, and the reason
for each from the `# why` of the table row that fired, whose number it
finds in `receipt.decisions.<decision>.rule`. The topic, its confidence,
the request kind and the checks' probabilities are what was sent in the
state.

## Departments

The usual departments of a large online store, each with a person (made
up, with `@contacthub.example` addresses) in the API's directory:

| Department | Handles | Person |
|---|---|---|
| Customer Service | Orders, delivery, returns, refunds, cancellations | Maria Lopez, Customer Service Lead |
| Billing & Payments | Charges, payment methods, invoices, gift cards, memberships | David Chen, Billing Operations Manager |
| Marketing | Products before buying, prices, promotions, reviews | Aisha Patel, Product Marketing Manager |
| Technical Support | The website, the app, sign-in, devices, digital services | Lukas Schmidt, Technical Support Lead |
| Trust & Safety | Fraud, scams, hacked accounts, counterfeits, abuse | Grace Okafor, Trust & Safety Investigator |
| Human Resources | Job applications, careers, employment verification | Sofia Rossi, Talent Acquisition Partner |
| Seller Services | Selling on the marketplace | Kenji Tanaka, Seller Success Manager |
| Procurement & Vendors | Suppliers who sell to the company | Olivia Brown, Vendor Relations Manager |
| Business Sales | Bulk and corporate purchases | Rafael Silva, Business Accounts Executive |
| Legal & Privacy | Legal notices, IP claims, privacy requests | Hannah Weiss, Privacy Counsel |
| Public Relations | Journalists and media | Tom Becker, Media Relations Manager |
| Investor Relations | Shareholders, results, reports | Priya Nair, Investor Relations Director |
| General Inquiries | Anything unclear, or that fits no department | Sam Taylor, Front Desk Coordinator |

## The routing screen

[RoutingScreen](../contacthub_app/lib/routing/routing_screen.dart), titled
**Request routed**, at most 1100 px wide:

- the message, with a link to it as sent to the local model;
- a spinner, "The local model is reading your request on this machine,
  then aityx routes it…", then the result, or the error with **Try
  again**;
- **Read on this machine**: the local model, how long it took, and what
  it read (see [Reading with a local model](reading.md#on-the-routing-screen));
- **Routed to**: the department, its person, role and email, and the
  reason;
- **The store's policy**, for a request about an order (see
  [Order policy](order-policy.md));
- **Priority** (the level and hours, colored by level) and **Review**
  (whether a person checks it first), side by side, stacked on a phone;
- **Checks on the message**: urgent, sensitive data, abuse and an unclear
  topic, each with the local model's probability as a bar, flagged in
  amber; each links to the model's answer, the input and the rule in the
  aityx request, and aityx's verdict;
- **Behind the routing**: the two calls, below.

Every item has links (with ↗ for a request, ↙ for a response; a link
into the local model's call says *(local)*) to **exactly** the JSON
behind it: the department's answer, the department table's row that
fired (`decision.decisions.department.table.<rule>`), its receipt entry
and the whole table; the priority's answer and row; each check's answer,
input, rule and verdict; the topic and the request kind as read and as
sent; the message.

## The calls

[CallView](../contacthub_app/lib/routing/call_view.dart), one pane per
call, as in Mortgage Hub, with the key parts highlighted and labeled:

- **1. The local model reads**: under **REQUEST**, the whole body sent to
  Ollama's `POST /api/chat`; under **RESPONSE**, Ollama's answer with
  `message.content`, the model's JSON, parsed
  ([readingDigest](../contacthub_app/lib/routing/routing_screen.dart)),
  so each fact it read is a row a link can land on. Its key parts: the
  model, the prompt, the message, the schema, temperature 0 and no
  thinking; in the answer, what it read and each fact, and the time
  taken.
- **2. aityx decides**: under **REQUEST**, the whole body sent to
  `POST /v1/systemone`; under **RESPONSE**, the answers that decide the
  route (the checks, the department, the days, the resolution, the
  amount and date, the priority, the hours, the review), each without
  its probability map, the receipt of the department, resolution,
  amount, priority and hours tables with the rule that fired in each,
  and the provenance of every input
  ([decisionDigest](../contacthub_app/lib/routing/routing_screen.dart)).
  Its key parts: the inputs, the thresholds, the tables and the rows that
  fired, the policy limits, the facts sent (the state, the topic and
  request kind read, today, the order, the message); in the answer, the
  decision, the resolution, the priority, the rule that fired and the
  provenance.
- **Each pane**: line numbers restart in each section. **Copy request**
  and **Copy full response** copy the whole of each; **Copy section** the
  marked part. Every key part is tinted with its label on its first row,
  the innermost winning where they nest; a part over 12 rows is tinted
  on its first row only. A label's tooltip says why it matters.
- **Readable JSON**: 14 px Roboto Mono (bundled, see
  [assets/fonts](../contacthub_app/assets/fonts/README.md)), 22 px rows,
  with colors for keys, strings, numbers and literals; short lists, such
  as a table's rows, stay on one line; **a long string, or one with line
  breaks, wraps** at 88 characters and at its line breaks onto
  continuation rows, unnumbered and shown as written (no `\n`, no
  escaped quotes), so the prompt reads as the prose it is and a rule's
  reason fits the pane
  ([json_layout.dart](../contacthub_app/lib/routing/json_layout.dart),
  `wrapString`). The copies are exact JSON. A pane is as high as its
  rows, up to 75% of the window (360 to 760 px). **Full screen** opens
  it in a dialog at the same place.
- **Exact navigation**: the layout records every value's first and last
  row on each side; since every row is the same height, a jump scrolls the
  value's first row to the top (one row of context above it), with room
  below the last row so the end reaches the top too. The value is marked
  strongly, and a panel above the pane says what it is, its side and path,
  and why it matters.
- **Jump to**: the call's key parts in the request, then in the response,
  as chips. The result's links use the same mechanism; links to parts a
  pane doesn't show are left out.

The API includes the aityx call only if aityx's answer doesn't contain
the key.

### Verified

Against the live API (`api.aityx.ai`) and Ollama with qwen3:1.7b: see
[Reading with a local model](reading.md#verified) for which of the 27
samples routed where their labels say. In Chrome, the links and chips
landed on exactly their values in both panes (the schema and a fact read
in the local call; department rule 3, the receipt, the provenance in the
aityx call), the prompt read as wrapped prose, and full screen opened at
the marked value. Widget tests check the scroll offset of a jump to the
pixel, in both panes and on both sides, that the prompt wraps onto
unnumbered rows, and that the screen fits a 390 px phone.

## Known limitations

- The local model's reading can vary with the wording, and a small model
  misreads some messages (see [Reading with a local
  model](reading.md#which-model)); the rules don't vary.
- The people are made up; nothing is sent to them.
- English only.
