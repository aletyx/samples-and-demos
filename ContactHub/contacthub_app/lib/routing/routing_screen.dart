import 'dart:convert';

import 'package:flutter/material.dart';

import 'call_view.dart';
import 'json_layout.dart';
import 'routing.dart';

/// Topic and department ids as people read them.
const topicNames = {
  'customer_service': 'Customer Service',
  'billing': 'Billing & Payments',
  'marketing': 'Marketing',
  'tech_support': 'Technical Support',
  'trust_safety': 'Trust & Safety',
  'hr': 'Human Resources',
  'seller_services': 'Seller Services',
  'procurement': 'Procurement & Vendors',
  'business_sales': 'Business Sales',
  'legal': 'Legal & Privacy',
  'press': 'Public Relations',
  'investor_relations': 'Investor Relations',
  'general_inquiries': 'General Inquiries',
  'other': 'Other',
};

/// What the customer wants, as the local model reads it, in words.
const requestKindNames = {
  'where_is_order': 'To know where an order is',
  'return_refund': 'A return or a refund',
  'damaged_defective': 'A damaged or defective item',
  'cancel_order': 'To cancel an order',
  'price_adjustment': 'A price drop refunded',
  'duplicate_charge': 'A duplicate charge refunded',
  'none': 'Nothing about an order',
};

/// The two calls behind a routing: the local model's, which read the
/// message, and aityx's, which decided from what it read.
enum Call {
  reading("The local model's call", Key('call-reading')),
  aityx('The aityx call', Key('call-aityx'));

  const Call(this.title, this.key);

  final String title;

  /// The key of the call's [CallView] on the page.
  final Key key;
}

/// Routes [message] once and shows where it went and why, each part with
/// links to exactly the JSON behind it, then the two calls themselves.
class RoutingScreen extends StatefulWidget {
  const RoutingScreen({super.key, required this.message, this.router});

  final String message;

  /// Who routes it: the app's API unless a test says.
  final RequestRouter? router;

  @override
  State<RoutingScreen> createState() => _RoutingScreenState();
}

class _RoutingScreenState extends State<RoutingScreen> {
  late final RequestRouter _router = widget.router ?? ApiRequestRouter();
  late Future<RoutingOutcome> _outcome = _router.route(widget.message);
  final _calls = {for (final call in Call.values) call: CallController()};

  @override
  void dispose() {
    for (final controller in _calls.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _retry() => setState(() {
    _outcome = _router.route(widget.message);
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request routed')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MessageCard(
                    widget.message,
                    onShow: () => _calls[Call.reading]!.reveal(
                      CallSide.request,
                      'messages.1.content',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<RoutingOutcome>(
                    future: _outcome,
                    builder: (context, snapshot) => switch (snapshot) {
                      AsyncSnapshot(:final data?) => _Outcome(data, _calls),
                      AsyncSnapshot(:final error?) => _Failure(
                        '$error',
                        _retry,
                      ),
                      _ => const _Routing(),
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard(this.message, {required this.onShow});

  final String message;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.format_quote, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(message, style: theme.textTheme.bodyLarge)),
            TextButton.icon(
              onPressed: onShow,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.north_east, size: 14),
              label: const Text('As sent'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Routing extends StatelessWidget {
  const _Routing();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'The local model is reading your request on this machine, then '
            'aityx routes it…',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure(this.message, this.onRetry);

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: scheme.error, size: 32),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

/// A link to one part of one call: "Answer", "Rule 3"...
class _JsonLink {
  const _JsonLink(this.label, this.call, this.side, this.path);

  final String label;
  final Call call;
  final CallSide side;
  final String path;
}

/// The pane's height for a call of [rows] rows: enough for all of them,
/// up to three quarters of the window (360 to 760 px).
double _paneHeight(BuildContext context, int rows) {
  final window = (MediaQuery.sizeOf(context).height * 0.75).clamp(360.0, 760.0);
  return (rows * 22.0 + 16).clamp(200.0, window);
}

class _Outcome extends StatelessWidget {
  const _Outcome(this.outcome, this.calls);

  final RoutingOutcome outcome;
  final Map<Call, CallController> calls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = outcome.routing;
    final reading = readingDigest(outcome.readingResponse);
    final decision = decisionDigest(outcome.aityxResponse);
    final present = {
      Call.reading: outcome.readingRequest != null,
      Call.aityx: outcome.aityxRequest != null,
    };
    // Only links to parts the panes show: each response is a digest.
    final layouts = {
      Call.reading: layoutCall(outcome.readingRequest, reading),
      Call.aityx: layoutCall(outcome.aityxRequest, decision),
    };
    Widget links(List<_JsonLink> links) {
      final kept = [
        for (final l in links)
          if (present[l.call]! &&
              layouts[l.call]!.range(
                    l.side == CallSide.request ? 'request' : 'response',
                    l.path,
                  ) !=
                  null)
            l,
      ];
      return kept.isEmpty ? const SizedBox.shrink() : _Links(kept, calls);
    }

    const req = CallSide.request;
    const res = CallSide.response;
    final deptRule = r.departmentRule;
    final prioRule = r.priorityRule;

    Widget heading(String title, String text) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReadingCard(outcome, links: links),
        const SizedBox(height: 12),
        _DepartmentCard(
          r,
          links: links([
            const _JsonLink('Answer', Call.aityx, res, 'answers.department'),
            if (deptRule != null)
              _JsonLink(
                'Rule $deptRule',
                Call.aityx,
                req,
                'decision.decisions.department.table.$deptRule',
              ),
            const _JsonLink(
              'Receipt',
              Call.aityx,
              res,
              'receipt.decisions.department',
            ),
            const _JsonLink(
              'Table',
              Call.aityx,
              req,
              'decision.decisions.department',
            ),
          ]),
        ),
        if (r.policy case final policy? when policy.applies) ...[
          const SizedBox(height: 12),
          _PolicyCard(policy, links: links),
        ],
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _FactCard(
                icon: Icons.flag_outlined,
                title: 'Priority',
                value:
                    '${_capitalize(r.priority)} · answer within '
                    '${r.responseHours} h',
                detail: r.priorityReason,
                accent: switch (r.priority) {
                  'high' => theme.colorScheme.error,
                  'low' => theme.colorScheme.secondary,
                  _ => theme.colorScheme.tertiary,
                },
                links: links([
                  const _JsonLink(
                    'Answer',
                    Call.aityx,
                    res,
                    'answers.priority',
                  ),
                  if (prioRule != null)
                    _JsonLink(
                      'Rule $prioRule',
                      Call.aityx,
                      req,
                      'decision.decisions.priority.table.$prioRule',
                    ),
                  const _JsonLink(
                    'Hours',
                    Call.aityx,
                    res,
                    'answers.response_hours',
                  ),
                  const _JsonLink(
                    'Hours table',
                    Call.aityx,
                    req,
                    'decision.decisions.response_hours',
                  ),
                ]),
              ),
              _FactCard(
                icon: r.needsReview
                    ? Icons.visibility_outlined
                    : Icons.task_alt,
                title: 'Review',
                value: r.needsReview
                    ? 'A person checks it first'
                    : 'Goes straight to the department',
                detail: r.needsReview
                    ? 'The topic is unclear, or the message holds sensitive '
                          'data or abuse: see the checks below.'
                    : 'The topic is clear and no check raised a flag.',
                accent: r.needsReview
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.secondary,
                links: links(const [
                  _JsonLink('Answer', Call.aityx, res, 'answers.needs_review'),
                  _JsonLink(
                    'Rule',
                    Call.aityx,
                    req,
                    'decision.decisions.needs_review',
                  ),
                ]),
              ),
            ];
            if (constraints.maxWidth < 640) {
              return Column(
                children: [cards[0], const SizedBox(height: 12), cards[1]],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _ChecksCard(r, links: links),
        const SizedBox(height: 24),
        heading(
          'Behind the routing',
          'Two calls. First the local model, run by Ollama on this machine, '
              'reads the message and answers the questions about it. Then '
              "aityx runs the routing model's rules on those answers, "
              'deterministically. The links above jump straight to the part '
              'of each call behind each item.',
        ),
        heading(
          '1. The local model reads',
          'POST /api/chat to Ollama: the prompt holds the questions and '
              'their criteria, the message is the only thing read, and the '
              'schema is the shape the answer must take.',
        ),
        if (present[Call.reading]!)
          CallView(
            key: Call.reading.key,
            title: Call.reading.title,
            request: outcome.readingRequest,
            response: reading,
            fullResponse: outcome.readingResponse,
            requestSubtitle: 'POST /api/chat to Ollama, as the API sent it',
            responseSubtitle:
                "Ollama's answer; message.content, the model's JSON, parsed",
            targets: readingTargets(),
            controller: calls[Call.reading],
            height: _paneHeight(context, layouts[Call.reading]!.rows.length),
          )
        else
          const Text("The API did not include the local model's call."),
        const SizedBox(height: 24),
        heading(
          '2. aityx decides',
          'POST /v1/systemone: the routing model and, as its state, what '
              'the local model read, today, the order on file and the '
              'message. aityx answers with every decision and a receipt of '
              'the rules that fired.',
        ),
        if (present[Call.aityx]!)
          CallView(
            key: Call.aityx.key,
            title: Call.aityx.title,
            request: outcome.aityxRequest,
            response: decision,
            fullResponse: outcome.aityxResponse,
            requestSubtitle: 'POST /v1/systemone, as the API sent it',
            responseSubtitle:
                'the answers that decide the route and the rules that '
                'fired; the probability maps are left out',
            targets: aityxTargets(r),
            controller: calls[Call.aityx],
            height: _paneHeight(context, layouts[Call.aityx]!.rows.length),
          )
        else
          const Text('The API did not include the aityx call.'),
      ],
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// What the pane shows of Ollama's [response]: all of it, except that
/// `message.content`, the model's answer as one JSON string, is parsed, so
/// each fact it read is a row of its own that a link can land on.
Map<String, Object?> readingDigest(Object? response) {
  final r = response is Map ? response : const {};
  return {
    for (final MapEntry(:key, :value) in r.entries)
      '$key': key == 'message' && value is Map
          ? {
              for (final MapEntry(key: k, value: v) in value.entries)
                '$k': k == 'content' && v is String ? _parsed(v) : v,
            }
          : value,
  };
}

Object? _parsed(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    return text;
  }
}

/// The answers aityx's response shows in the pane: the ones that decide
/// the route, in the order the rules run.
const _shownAnswers = [
  'urgent',
  'sensitive_data',
  'abusive',
  'clear_topic',
  'department',
  'days_since_order',
  'days_since_delivery',
  'resolution',
  'refund_amount',
  'refund_by',
  'priority',
  'response_hours',
  'needs_review',
];

/// The decisions whose receipt (the rule that fired) the pane shows.
const _tracedDecisions = [
  'department',
  'resolution',
  'refund_amount',
  'priority',
  'response_hours',
];

/// What the pane shows of aityx's [response]: the answers that decide the
/// route, each without its probability map (a dozen zeros and a one), the
/// receipt of the tables, with the rule that fired in each, and where every
/// input came from. "Copy full response" has all of it.
Map<String, Object?> decisionDigest(Object? response) {
  final r = response is Map ? response : const {};
  final answers = r['answers'] is Map ? r['answers'] as Map : const {};
  final receipt = r['receipt'] is Map ? r['receipt'] as Map : const {};
  final decisions = receipt['decisions'] is Map
      ? receipt['decisions'] as Map
      : const {};
  return {
    'answers': {
      for (final name in _shownAnswers)
        if (answers[name] case final Map answer)
          name: {
            for (final MapEntry(:key, :value) in answer.entries)
              if (key != 'probabilities') '$key': value,
          },
    },
    'receipt': {
      'decisions': {
        for (final name in _tracedDecisions)
          if (decisions[name] != null) name: decisions[name],
      },
      if (receipt['provenance'] != null) 'provenance': receipt['provenance'],
    },
    if (r['decision_error'] != null) 'decision_error': r['decision_error'],
  };
}

/// The key parts of the local model's call: highlighted in its pane, and
/// in its "Jump to" bar.
List<JsonTarget> readingTargets() {
  const req = CallSide.request;
  const res = CallSide.response;
  return const [
    JsonTarget(
      req,
      'model',
      'The local model',
      'The model that reads the message, run by Ollama on this machine. It '
          'reads; it never decides.',
    ),
    JsonTarget(
      req,
      'messages.0.content',
      'The prompt',
      'The questions about the message, with the criteria for each answer '
          "in plain words: the routing model's questions, as the API wrote "
          'them out for the local model.',
    ),
    JsonTarget(
      req,
      'messages.1.content',
      'The message',
      'The request as typed or dictated: the only thing the model reads.',
    ),
    JsonTarget(
      req,
      'format',
      "The answer's schema",
      'Ollama makes the model follow this JSON schema as it writes: a topic '
          'and a request kind from these lists only, and numbers in range. '
          'No parsing of free text.',
    ),
    JsonTarget(
      req,
      'options',
      'Temperature 0',
      'The most likely answer every time, so the same message reads the '
          'same way.',
    ),
    JsonTarget(
      req,
      'think',
      'No thinking',
      'qwen3 can reason before it answers; here it answers directly, in '
          'well under a second.',
    ),
    JsonTarget(
      res,
      'message.content',
      'What it read',
      "The model's answer, parsed: the six facts aityx's rules decide "
          'from. Nothing else it says is used.',
    ),
    JsonTarget(
      res,
      'message.content.request_kind',
      'Request kind',
      'What the customer wants done with an order, or none: the policy '
          'rules start from it.',
    ),
    JsonTarget(
      res,
      'message.content.urgent_probability',
      'Urgency',
      'The probability that the message is urgent; the rules call it a '
          'fact from 0.8 up.',
    ),
    JsonTarget(
      res,
      'message.content.sensitive_data_probability',
      'Sensitive data',
      'The probability that the message itself holds a card number, a '
          'password or an ID number; a fact from 0.8 up.',
    ),
    JsonTarget(
      res,
      'message.content.abusive_probability',
      'Abuse',
      'The probability that the message is abusive or threatening; a fact '
          'from 0.8 up.',
    ),
    JsonTarget(
      res,
      'message.content.topic',
      'Topic',
      "The department's area the message is mainly about, or other: what "
          'the department table routes from.',
    ),
    JsonTarget(
      res,
      'message.content.topic_confidence',
      'Confidence',
      'How sure the model is of the topic, in percent; the rules route '
          'directly from 60 up, and send the rest to General Inquiries.',
    ),
    JsonTarget(
      res,
      'total_duration',
      'Time taken',
      'In nanoseconds, all in: loading the model if it was not in memory, '
          'reading the prompt, writing the answer.',
    ),
  ];
}

/// The key parts of the aityx call, for [r]: highlighted in its pane, and
/// in its "Jump to" bar; the rows that fired are exact.
List<JsonTarget> aityxTargets(Routing r) {
  const req = CallSide.request;
  const res = CallSide.response;
  return [
    const JsonTarget(
      req,
      'decision.inputs',
      'Model inputs',
      "The rules' inputs: the six facts the local model read, by name, "
          'plus today, the order on file and the message.',
    ),
    const JsonTarget(
      req,
      'decision.decisions.evidence_threshold',
      'Evidence threshold',
      'A probability from the local model counts as a fact from 0.8 up.',
    ),
    const JsonTarget(
      req,
      'decision.decisions.clear_topic',
      'Clear topic rule',
      'The topic routes directly only when the local model is at least 60% '
          'confident and it fits a department.',
    ),
    const JsonTarget(
      req,
      'decision.decisions.department',
      'Department table',
      'The routing rules: abuse first, then an unclear topic, then one row '
          'per department. The first row that matches wins.',
    ),
    if (r.departmentRule case final rule?)
      JsonTarget(
        req,
        'decision.decisions.department.table.$rule',
        'Department rule $rule',
        'The row of the department table that fired for this message, with '
            'its reason.',
      ),
    const JsonTarget(
      req,
      'decision.inputs.order',
      'Order input',
      'The order the message names, from the order book: its dates, '
          'amounts, category, status and charges.',
    ),
    const JsonTarget(
      req,
      'decision.decisions.return_window_days',
      'Policy limits',
      'The store policy\'s numbers, one decision each: 30 days to refund, '
          '60 for store credit, 7 to report damage, a 1-year warranty on '
          'electronics, 14 days for a price drop, late after 10 days, a '
          'person above \$500, a 15% restocking fee on electronics after '
          '14 days, paid within 5 days.',
    ),
    const JsonTarget(
      req,
      'decision.decisions.days_since_delivery',
      'Days since delivery',
      'Today minus the delivery date, in days: what the windows are '
          'measured against.',
    ),
    const JsonTarget(
      req,
      'decision.decisions.resolution',
      'Policy table',
      'What the policy offers, by request kind, status, category, dates '
          'and amount. The first row that matches wins.',
    ),
    if (r.policy?.rule case final rule?)
      JsonTarget(
        req,
        'decision.decisions.resolution.table.$rule',
        'Policy rule $rule',
        'The row of the policy table that fired for this order.',
      ),
    if (r.policy?.amountRule case final rule?)
      JsonTarget(
        req,
        'decision.decisions.refund_amount.table.$rule',
        'Amount rule $rule',
        'The row of the amount table that fired: how much is paid back, '
            'and why.',
      ),
    const JsonTarget(
      req,
      'decision.decisions.refund_amount',
      'Amount table',
      'How much is refunded or credited for each resolution, restocking '
          'fee included.',
    ),
    const JsonTarget(
      req,
      'decision.decisions.priority',
      'Priority table',
      'How soon the department must answer: high for abuse, sensitive data, '
          'urgency, fraud and legal matters; low for product and media '
          'questions.',
    ),
    if (r.priorityRule case final rule?)
      JsonTarget(
        req,
        'decision.decisions.priority.table.$rule',
        'Priority rule $rule',
        'The row of the priority table that fired for this message.',
      ),
    const JsonTarget(
      req,
      'decision.decisions.needs_review',
      'Review rule',
      'A person checks the message first when its topic is unclear or it '
          'holds sensitive data or abuse.',
    ),
    const JsonTarget(
      req,
      'state',
      'The facts',
      'The state aityx decides from: what the local model read, today, '
          'the order on file and the message. aityx reads nothing itself.',
    ),
    const JsonTarget(
      req,
      'state.topic',
      'Topic read',
      "The local model's topic, as sent: the department table's main "
          'input.',
    ),
    const JsonTarget(
      req,
      'state.request_kind',
      'Request kind read',
      "The local model's reading of what the customer wants: the policy "
          "table's first column.",
    ),
    const JsonTarget(
      req,
      'state.today',
      'Today',
      "The request's date, from the API's clock: every window counts from "
          'it.',
    ),
    const JsonTarget(
      req,
      'state.order',
      'The order',
      'The order on file the API sent, found by the number in the message.',
    ),
    const JsonTarget(
      req,
      'state.message',
      'The message',
      'The request as typed or dictated, for the record: no rule reads it.',
    ),
    const JsonTarget(
      res,
      'answers.department',
      'The routing decision',
      'The department the rules chose: the routing.',
    ),
    const JsonTarget(
      res,
      'answers.resolution',
      'Policy resolution',
      "What the store's policy offers for the order, if the request is "
          'about one.',
    ),
    const JsonTarget(
      res,
      'answers.priority',
      'Priority',
      'How soon the department must answer: low, normal or high.',
    ),
    const JsonTarget(
      res,
      'receipt.decisions.department',
      'Rule that fired',
      'The department table\'s trace: "rule" is the row that fired, "rows" '
          'and "cells" how each row matched.',
    ),
    const JsonTarget(
      res,
      'receipt.provenance',
      'Provenance',
      'Where each input came from: every one from the state, none read by '
          'aityx.',
    ),
    const JsonTarget(
      res,
      'decision_error',
      'Model error',
      'Present only when the model failed on these facts.',
    ),
  ];
}

class _Links extends StatelessWidget {
  const _Links(this.links, this.calls);

  final List<_JsonLink> links;
  final Map<Call, CallController> calls;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(
          Icons.data_object,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        for (final l in links)
          TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            onPressed: () => calls[l.call]!.reveal(l.side, l.path),
            iconAlignment: IconAlignment.end,
            icon: Icon(
              l.side == CallSide.request ? Icons.north_east : Icons.south_west,
              size: 14,
            ),
            label: Text(
              l.call == Call.reading ? '${l.label} (local)' : l.label,
            ),
          ),
      ],
    );
  }
}

/// What the local model read, and how long it took: the facts aityx then
/// decided from.
class _ReadingCard extends StatelessWidget {
  const _ReadingCard(this.outcome, {required this.links});

  final RoutingOutcome outcome;
  final Widget Function(List<_JsonLink>) links;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final r = outcome.routing;
    const req = CallSide.request;
    const res = CallSide.response;
    final seconds = outcome.readingSeconds;
    final loading = outcome.loadingSeconds ?? 0;
    final confidence = r.topicConfidence;
    final flagged = [
      for (final c in r.checks)
        if (c.flagged && c.id != 'clear_topic') c.label,
    ];
    Widget fact(String name, String value, List<_JsonLink> to) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(value, style: theme.textTheme.bodyLarge),
                links(to),
              ],
            ),
          ),
        ],
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: scheme.tertiary, width: 4)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'READ ON THIS MACHINE',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.tertiary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${outcome.localModel ?? 'The local model'}'
              '${seconds == null ? '' : ' · ${seconds.toStringAsFixed(1)} s'}'
              '${loading > 0.5 ? ' (${loading.toStringAsFixed(1)} s loading it)' : ''}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'The local model, run by Ollama, answered the questions below '
              'from the message alone. It never picks the department: '
              "aityx's rules decide from these answers.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            fact(
              'Topic',
              '${topicNames[r.topic] ?? r.topic ?? 'none'}'
                  '${confidence == null ? '' : ', ${(confidence * 100).round()}% sure'}',
              const [
                _JsonLink('Answer', Call.reading, res, 'message.content.topic'),
                _JsonLink(
                  'Confidence',
                  Call.reading,
                  res,
                  'message.content.topic_confidence',
                ),
                _JsonLink('Input', Call.aityx, req, 'state.topic'),
              ],
            ),
            fact(
              'Wants',
              requestKindNames[r.requestKind] ?? r.requestKind ?? 'unknown',
              const [
                _JsonLink(
                  'Answer',
                  Call.reading,
                  res,
                  'message.content.request_kind',
                ),
                _JsonLink('Input', Call.aityx, req, 'state.request_kind'),
              ],
            ),
            fact(
              'Flags',
              flagged.isEmpty
                  ? 'None raised: not urgent, no sensitive data, civil'
                  : flagged.join(' · '),
              const [
                _JsonLink(
                  'Urgency',
                  Call.reading,
                  res,
                  'message.content.urgent_probability',
                ),
                _JsonLink(
                  'Sensitive data',
                  Call.reading,
                  res,
                  'message.content.sensitive_data_probability',
                ),
                _JsonLink(
                  'Abuse',
                  Call.reading,
                  res,
                  'message.content.abusive_probability',
                ),
              ],
            ),
            const SizedBox(height: 4),
            links(const [
              _JsonLink('The prompt', Call.reading, req, 'messages.0.content'),
              _JsonLink('The schema', Call.reading, req, 'format'),
              _JsonLink('All it read', Call.reading, res, 'message.content'),
              _JsonLink('The facts sent to aityx', Call.aityx, req, 'state'),
            ]),
          ],
        ),
      ),
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard(this.r, {required this.links});

  final Routing r;
  final Widget links;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = r.department;
    return Card(
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: scheme.primary, width: 4)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ROUTED TO',
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.primary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              d.name,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: Text(
                    d.person.split(' ').map((w) => w[0]).take(2).join(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.person, style: theme.textTheme.titleMedium),
                      Text(
                        '${d.role} · ${d.email}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (r.reason != null) ...[
              const SizedBox(height: 12),
              Text(r.reason!, style: theme.textTheme.bodyLarge),
            ],
            const SizedBox(height: 8),
            links,
          ],
        ),
      ),
    );
  }
}

class _FactCard extends StatelessWidget {
  const _FactCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.detail,
    required this.accent,
    required this.links,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? detail;
  final Color accent;
  final Widget links;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 20),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.labelLarge),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(color: accent),
            ),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            links,
          ],
        ),
      ),
    );
  }
}

class _ChecksCard extends StatelessWidget {
  const _ChecksCard(this.r, {required this.links});

  final Routing r;
  final Widget Function(List<_JsonLink>) links;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const req = CallSide.request;
    const res = CallSide.response;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Checks on the message', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              "The local model gives each probability; aityx's rules set "
              'the bar: 0.8, or a confidence of 0.6 for the topic.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final c in r.checks) ...[
              const Divider(height: 16),
              Row(
                children: [
                  Icon(
                    c.flagged
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle,
                    color: c.flagged ? scheme.tertiary : scheme.secondary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.label, style: theme.textTheme.bodyLarge),
                        if (c.probability case final p?)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: p,
                                    minHeight: 6,
                                    borderRadius: BorderRadius.circular(3),
                                    color: c.flagged
                                        ? scheme.tertiary
                                        : scheme.secondary,
                                    backgroundColor:
                                        scheme.surfaceContainerHighest,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  c.id == 'clear_topic'
                                      ? 'confidence ${(p * 100).round()}%'
                                      : '${(p * 100).round()}%',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        links(switch (c.id) {
                          'clear_topic' => const [
                            _JsonLink(
                              'Confidence',
                              Call.reading,
                              res,
                              'message.content.topic_confidence',
                            ),
                            _JsonLink(
                              'Rule',
                              Call.aityx,
                              req,
                              'decision.decisions.clear_topic',
                            ),
                            _JsonLink(
                              'Verdict',
                              Call.aityx,
                              res,
                              'answers.clear_topic',
                            ),
                          ],
                          final id => [
                            _JsonLink(
                              'Answer',
                              Call.reading,
                              res,
                              'message.content.${id}_probability',
                            ),
                            _JsonLink(
                              'Input',
                              Call.aityx,
                              req,
                              'state.${id}_probability',
                            ),
                            _JsonLink(
                              'Rule',
                              Call.aityx,
                              req,
                              'decision.decisions.$id',
                            ),
                            _JsonLink(
                              'Verdict',
                              Call.aityx,
                              res,
                              'answers.$id',
                            ),
                          ],
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// What each resolution is called, and how it reads: good for the
/// customer, a step to take, or a no.
const _resolutions = {
  'ask_for_order': ('Ask for the order number', _Tone.step),
  'cancel_and_refund': ('Cancel and refund', _Tone.good),
  'return_after_delivery': ('Return it once it arrives', _Tone.step),
  'share_tracking': ('On schedule: share the tracking', _Tone.good),
  'investigate_late': ('Late: open a carrier investigation', _Tone.step),
  'refund_duplicate': ('Refund the duplicate charge', _Tone.good),
  'price_adjustment': ('Refund the price difference', _Tone.good),
  'replace_or_refund': ('Replace or refund', _Tone.good),
  'warranty_repair': ('Repair under warranty', _Tone.good),
  'refund': ('Refund', _Tone.good),
  'store_credit': ('Store credit', _Tone.good),
  'manual_review': ('A person approves it', _Tone.step),
  'not_eligible': ('Not eligible', _Tone.no),
};

enum _Tone { good, step, no }

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _date(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

String _money(double amount) {
  final cents = (amount * 100).round();
  final whole = (cents ~/ 100).toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]},',
  );
  return '\$$whole.${(cents % 100).toString().padLeft(2, '0')}';
}

String _ago(int? days) => switch (days) {
  null || < 0 => '',
  0 => ' (today)',
  1 => ' (yesterday)',
  final d => ' ($d days ago)',
};

/// The store's policy for the order: what it offers, how much and by when,
/// why, and the order's facts it was decided from.
class _PolicyCard extends StatelessWidget {
  const _PolicyCard(this.policy, {required this.links});

  final OrderPolicy policy;
  final Widget Function(List<_JsonLink>) links;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const req = CallSide.request;
    const res = CallSide.response;
    const a = Call.aityx;
    final (label, tone) =
        _resolutions[policy.resolution] ?? (policy.resolution, _Tone.step);
    final accent = switch (tone) {
      _Tone.good => scheme.secondary,
      _Tone.step => scheme.tertiary,
      _Tone.no => scheme.error,
    };
    final order = policy.order;
    final rule = policy.rule;
    Widget fact(String name, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 4)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "THE STORE'S POLICY",
              style: theme.textTheme.labelMedium?.copyWith(
                color: accent,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
            if (policy.refundAmount > 0) ...[
              const SizedBox(height: 4),
              Text(
                '${_money(policy.refundAmount)}'
                '${policy.refundBy == null ? '' : ', paid by ${_date(policy.refundBy!)}'}',
                style: theme.textTheme.titleLarge,
              ),
              if (policy.amountReason != null)
                Text(
                  policy.amountReason!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
            if (policy.reason != null) ...[
              const SizedBox(height: 8),
              Text(policy.reason!, style: theme.textTheme.bodyLarge),
            ],
            links([
              const _JsonLink('Answer', a, res, 'answers.resolution'),
              if (rule != null)
                _JsonLink(
                  'Rule $rule',
                  a,
                  req,
                  'decision.decisions.resolution.table.$rule',
                ),
              if (policy.refundAmount > 0) ...[
                const _JsonLink('Amount', a, res, 'answers.refund_amount'),
                if (policy.amountRule case final amountRule?)
                  _JsonLink(
                    'Amount rule $amountRule',
                    a,
                    req,
                    'decision.decisions.refund_amount.table.$amountRule',
                  ),
              ],
              const _JsonLink(
                'Limits',
                a,
                req,
                'decision.decisions.return_window_days',
              ),
            ]),
            const Divider(height: 24),
            if (order == null)
              Text(
                policy.orderNumber == null
                    ? 'The message names no order.'
                    : 'Order ${policy.orderNumber} is not on file.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else ...[
              Text(
                'Order ${order.number} · ${order.item}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              fact(
                'Ordered',
                '${_date(order.placedOn)}${_ago(policy.daysSinceOrder)}',
              ),
              fact(
                order.status == 'delivered' ? 'Delivered' : 'Expected',
                '${_date(order.deliveredOn)}'
                '${order.status == 'delivered' ? _ago(policy.daysSinceDelivery) : ' · ${order.status}'}',
              ),
              fact(
                'Paid',
                '${_money(order.amount)}'
                    '${order.currentPrice != order.amount ? ' · ${_money(order.currentPrice)} today' : ''}'
                    '${order.charges > 1 ? ' · charged ${order.charges} times' : ''}',
              ),
              fact('Category', switch (order.category) {
                'final_sale' => 'Final sale',
                'electronics' => 'Electronics',
                _ => 'Standard',
              }),
              links(const [
                _JsonLink('The order', a, req, 'state.order'),
                _JsonLink('Today', a, req, 'state.today'),
                _JsonLink(
                  'Days since delivery',
                  a,
                  res,
                  'answers.days_since_delivery',
                ),
                _JsonLink(
                  'Request kind',
                  Call.reading,
                  res,
                  'message.content.request_kind',
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
