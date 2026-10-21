# Routing

**Send** opens the routing screen, which asks the API to route the
request and shows where it went, why, and the aityx call behind it.

## How a request is routed

One call to aityx's `POST /v1/systemone`, built by
[lib/routing.dart](../contacthub_api/lib/routing.dart) from
[models/routing.json](../contacthub_api/models/routing.json), with the
the message, today and the order it names as the state (see
[Order policy](order-policy.md)):

1. **Jev** (`model: "jev-latest"`) answers five questions about the
   message:
   - `topic`, a **choice** among the departments' topics, each defined in
     plain words in its `criteria`, plus `other`; the answer carries Jev's
     `confidence` and every topic's probability;
   - `request_kind`, a **choice** of what the customer wants done with
     their order (see [Order policy](order-policy.md));
   - `urgent_probability`, `sensitive_data_probability` and
     `abusive_probability`, yes/no questions (**noul**) answered as
     probabilities.
2. The **routing model** then decides, deterministically, from those
   answers (its inputs are Jev's answers by name, and the topic's
   confidence, bound with `from: "jev:/answers/topic/confidence"`):
   - `urgent`, `sensitive_data`, `abusive`: the probability is at least
     `evidence_threshold`, 0.8;
   - `clear_topic`: the confidence is at least `confidence_threshold`, 0.6,
     and the topic isn't `other`;
   - `department` (a FIRST table): abuse goes to Trust & Safety whatever
     the topic; an unclear topic to General Inquiries; otherwise one row
     per topic; General Inquiries last;
   - `priority` (`low<normal<high`): high for abuse, sensitive data,
     urgency, a late package, and Trust & Safety or Legal; low for Marketing, Public
     Relations and Investor Relations; normal otherwise;
   - `response_hours`: 4 for high, 24 for normal, 48 for low;
   - `needs_review`: the topic is unclear, the message holds sensitive
     data or abuse, or the policy needs a person to approve it;
   - the store's policy for the order: see [Order policy](order-policy.md).

The API reads the department and priority from `answers`, and the reason
for each from the `# why` of the table row that fired, whose number it
finds in `receipt.decisions.<decision>.rule`.

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

- the message, with a link to it in the request;
- **The store's policy**, for a request about an order (see
  [Order policy](order-policy.md));
- a spinner, "Jev is reading your request, and aityx is routing it…",
  then the result, or the error with **Try again**;
- **Routed to**: the department, its person, role and email, and the
  reason;
- **Priority** (the level and hours, colored by level) and **Review**
  (whether a person checks it first), side by side, stacked on a phone;
- **Checks on the message**: urgent, sensitive data, abuse and an unclear
  topic, each with Jev's probability as a bar, flagged in amber;
- **Jev's reading of the topic**: the top topics' probabilities;
- **The aityx call**, below.

Every item has links (with ↗ for the request, ↙ for the response) to
**exactly** the JSON behind it: the department's answer, the department
table's row that fired (`decision.decisions.department.table.<rule>`),
its receipt entry and the whole table; the priority's answer and row;
each check's question and answer; the topic's answer, question and
confidence input; the message.

## The aityx call

[AityxCallView](../contacthub_app/lib/routing/aityx_call_view.dart), an
improvement on Mortgage Hub's JSON view:

- **Request** and **Response**, a toggle; each keeps its own scroll
  position.
- **Larger**: 14 px Roboto Mono (bundled, see
  [assets/fonts](../contacthub_app/assets/fonts/README.md)), 22 px lines,
  in a panel 75% of the window's height (360 to 760 px), with line
  numbers and colors for keys, strings, numbers and literals; short lists,
  such as a table's rows, stay on one line
  ([json_layout.dart](../contacthub_app/lib/routing/json_layout.dart)).
  **Full screen** opens it in a dialog at the same place.
- **Exact navigation**: the layout records every value's first and last
  line; since every line is the same height, a jump scrolls the value's
  first line to the top (one line of context above it), with room below
  the last line so even the end of the response reaches the top. The
  whole value is marked, its label pinned to its first line, and a panel
  above the code says what it is, its path and why it matters.
- **Jump to**: a chip for each part worth seeing on the current side,
  including the rows that fired for this message; the result's links use
  the same mechanism, switching sides as needed.
- **Copy section** (the marked value) and **Copy request/response**.

The API includes the call only if aityx's answer doesn't contain the key.

### Verified

Against the live API (`api.aityx.ai`): the 13 department samples and the
two check samples each routed where expected (see
[Request box](request.md#samples)); in Chrome, the links and chips landed
on exactly their values (department rule 3, rule 9, the receipt near the
end of the response), and full screen opened at the marked value. Widget
tests check the scroll offset of a jump to the pixel, on both sides, and
that the screen fits a 390 px phone.

## Known limitations

- Jev's answers can vary between calls; the rules don't.
- The people are made up; nothing is sent to them.
- English only.
