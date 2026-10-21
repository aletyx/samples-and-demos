/// A ready-made request to try: one for each department, and a few that
/// exercise the checks.
class SampleRequest {
  const SampleRequest(this.department, this.title, this.text);

  /// Where it should be routed, as people read it.
  final String department;
  final String title;
  final String text;
}

const departmentSamples = [
  SampleRequest(
    'Customer Service',
    'Where is my package?',
    'I ordered a desk lamp last Monday (order 112-8834) and the tracking '
        "hasn't moved in five days. Where is it?",
  ),
  SampleRequest(
    'Billing & Payments',
    'Charged twice',
    'I was charged twice for the same order this month. Please refund one '
        'of the charges.',
  ),
  SampleRequest(
    'Marketing',
    'A question about a product',
    'Does the Aurora 55-inch TV support HDMI 2.1, and does it come with a '
        'wall mount?',
  ),
  SampleRequest(
    'Technical Support',
    "Can't sign in",
    'The app keeps saying my password is wrong, even right after I reset '
        "it. I can't sign in.",
  ),
  SampleRequest(
    'Trust & Safety',
    'A phishing email',
    "I got an email that looks like it's from you, asking me to confirm my "
        'card details on a strange website. Is it a scam?',
  ),
  SampleRequest(
    'Human Resources',
    'A job application',
    "I'd like to apply for the warehouse supervisor position in Dallas. "
        'Where should I send my CV?',
  ),
  SampleRequest(
    'Seller Services',
    'Selling on the marketplace',
    'I make handmade candles and want to start selling them on your '
        'marketplace. What are the seller fees?',
  ),
  SampleRequest(
    'Procurement & Vendors',
    'Becoming a supplier',
    "We're a furniture manufacturer and would like to supply your home "
        'section wholesale. Who handles new vendors?',
  ),
  SampleRequest(
    'Business Sales',
    'A bulk order',
    'Our company needs 200 laptops for new employees. Can we get a business '
        'quote, paid by invoice?',
  ),
  SampleRequest(
    'Legal & Privacy',
    'Delete my data',
    'Under the GDPR, please delete all the personal data you hold about me '
        'and confirm when it is done.',
  ),
  SampleRequest(
    'Public Relations',
    'A press request',
    "I'm a reporter at the Daily Ledger writing about holiday delivery "
        'delays. Could someone give us a comment by Friday?',
  ),
  SampleRequest(
    'Investor Relations',
    'A shareholder question',
    "When is the next earnings call, and where can I find last year's "
        'annual report?',
  ),
  SampleRequest(
    'General Inquiries',
    'Too vague to tell',
    'hello? anyone there',
  ),
];

const checkSamples = [
  SampleRequest(
    'Billing & Payments · high priority, reviewed',
    'A card number in the message',
    'I was charged twice for order 112-4432. My card is 4111 1111 1111 '
        '1111, please refund one of the charges.',
  ),
  SampleRequest(
    'Trust & Safety · whatever the topic',
    'An abusive message',
    "You people are useless. If my refund isn't here tomorrow I'll come to "
        'your office and make you regret it.',
  ),
];
