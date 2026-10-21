import 'package:flutter/material.dart';

import 'aityx_call_view.dart';
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

/// Routes [message] once and shows where it went and why, each part with
/// links to exactly the JSON behind it, then the aityx call itself.
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
  final _call = AityxCallController();

  @override
  void dispose() {
    _call.dispose();
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
                    onShow: () =>
                        _call.reveal(CallSide.request, 'state.message'),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<RoutingOutcome>(
                    future: _outcome,
                    builder: (context, snapshot) => switch (snapshot) {
                      AsyncSnapshot(:final data?) => _Outcome(data, _call),
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
              label: const Text('In the request'),
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
          Text('aityx is reading and routing your request…'),
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

/// A link to one part of the call: "Answer", "Rule 3"...
class _JsonLink {
  const _JsonLink(this.label, this.side, this.path);

  final String label;
  final CallSide side;
  final String path;
}

class _Outcome extends StatelessWidget {
  const _Outcome(this.outcome, this.call);

  final RoutingOutcome outcome;
  final AityxCallController call;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = outcome.routing;
    final hasCall = outcome.aityxRequest != null;
    Widget links(List<_JsonLink> links) =>
        hasCall ? _Links(links, call) : const SizedBox.shrink();
    const req = CallSide.request;
    const res = CallSide.response;
    final deptRule = r.departmentRule;
    final prioRule = r.priorityRule;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DepartmentCard(
          r,
          links: links([
            const _JsonLink('Answer', res, 'answers.department'),
            if (deptRule != null)
              _JsonLink(
                'Rule $deptRule',
                req,
                'decision.decisions.department.table.$deptRule',
              ),
            const _JsonLink('Receipt', res, 'receipt.decisions.department'),
            const _JsonLink('Table', req, 'decision.decisions.department'),
          ]),
        ),
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
                  const _JsonLink('Answer', res, 'answers.priority'),
                  if (prioRule != null)
                    _JsonLink(
                      'Rule $prioRule',
                      req,
                      'decision.decisions.priority.table.$prioRule',
                    ),
                  const _JsonLink('Hours', res, 'answers.response_hours'),
                  const _JsonLink(
                    'Hours table',
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
                  _JsonLink('Answer', res, 'answers.needs_review'),
                  _JsonLink('Rule', req, 'decision.decisions.needs_review'),
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
        const SizedBox(height: 12),
        _TopicCard(
          r,
          links: links(const [
            _JsonLink("aityx's reading", res, 'answers.topic'),
            _JsonLink('Question', req, 'questions.topic'),
            _JsonLink(
              'Confidence input',
              req,
              'decision.inputs.topic_confidence',
            ),
          ]),
        ),
        const SizedBox(height: 24),
        Text('The aityx call', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(
          'One call to /v1/systemone: aityx answers the questions about the '
          'message, then the routing model decides, deterministically, from '
          'those answers. The links above jump straight to the part of the '
          'request or response behind each item.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (hasCall)
          AityxCallView(
            request: outcome.aityxRequest,
            response: outcome.aityxResponse,
            targets: callTargets(r),
            controller: call,
            height: (MediaQuery.sizeOf(context).height * 0.75).clamp(
              360.0,
              760.0,
            ),
          )
        else
          const Text('The API did not include the aityx call.'),
      ],
    );
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

/// The "Jump to" bar's parts, for [r]: the rows that fired are exact.
List<JsonTarget> callTargets(Routing r) {
  const req = CallSide.request;
  const res = CallSide.response;
  return [
    const JsonTarget(
      req,
      'model',
      'Reading model',
      'The aityx model that answers the questions. It reads the message; it '
          'never decides the route.',
    ),
    const JsonTarget(
      req,
      'questions.topic',
      'Topic question',
      'A choice question: aityx picks one topic, each defined in plain words '
          'in its criteria, and says how confident it is.',
    ),
    const JsonTarget(
      req,
      'questions.urgent_probability',
      'Urgency question',
      'A yes/no question (noul): the probability that the message is '
          'urgent.',
    ),
    const JsonTarget(
      req,
      'questions.sensitive_data_probability',
      'Sensitive data question',
      'Whether the message contains a card number, password, bank account '
          'or ID number.',
    ),
    const JsonTarget(
      req,
      'questions.abusive_probability',
      'Abuse question',
      'Whether the message is abusive, threatening or harassing.',
    ),
    const JsonTarget(
      req,
      'decision.inputs',
      'Model inputs',
      "The routing model's inputs: the questions' answers, by name, and "
          'confidence in the topic, bound with from = "jev:/answers/topic/'
          'confidence".',
    ),
    const JsonTarget(
      req,
      'decision.decisions.clear_topic',
      'Clear topic rule',
      'The topic routes directly only when aityx is at least 60% confident '
          'and it fits a department.',
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
      'state.message',
      'The message',
      'The only fact sent: the request as typed or dictated.',
    ),
    const JsonTarget(
      res,
      'answers.topic',
      'The topic',
      "aityx's choice, its confidence, and the probability of every topic.",
    ),
    const JsonTarget(
      res,
      'answers.urgent_probability',
      'Urgency',
      "aityx's probability that the message is urgent; the model treats 0.8 "
          'or more as urgent.',
    ),
    const JsonTarget(
      res,
      'answers.sensitive_data_probability',
      'Sensitive data',
      "aityx's probability that the message holds a card number, password or "
          'ID.',
    ),
    const JsonTarget(
      res,
      'answers.abusive_probability',
      'Abuse',
      "aityx's probability that the message is abusive.",
    ),
    const JsonTarget(
      res,
      'answers.department',
      'Department',
      'The routing: the department the model chose.',
    ),
    const JsonTarget(
      res,
      'answers.priority',
      'Priority',
      'The priority, as a level (low, normal, high).',
    ),
    const JsonTarget(
      res,
      'answers.response_hours',
      'Response hours',
      'Hours the department has to answer, from the priority.',
    ),
    const JsonTarget(
      res,
      'answers.needs_review',
      'Needs review',
      'Whether a person checks the message first (1 yes, 0 no).',
    ),
    const JsonTarget(
      res,
      'receipt.read',
      'Inputs read',
      'Every input the model read, its value and its source: here, all '
          'from the questions (aityx names that source "jev").',
    ),
    const JsonTarget(
      res,
      'receipt.decisions.department',
      'Department receipt',
      'The department table\'s trace: "rule" is the row that fired, '
          '"rows" and "cells" how each row matched.',
    ),
    const JsonTarget(
      res,
      'receipt.decisions.priority',
      'Priority receipt',
      "The priority table's trace: the row that fired.",
    ),
    const JsonTarget(
      res,
      'usage',
      'Cost',
      "The call's tokens: one System One charge covers the questions and the model.",
    ),
    const JsonTarget(
      res,
      'decision_error',
      'Model error',
      'Present only when the model failed after the questions were answered.',
    ),
  ];
}

class _Links extends StatelessWidget {
  const _Links(this.links, this.call);

  final List<_JsonLink> links;
  final AityxCallController call;

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
            onPressed: () => call.reveal(l.side, l.path),
            iconAlignment: IconAlignment.end,
            icon: Icon(
              l.side == CallSide.request ? Icons.north_east : Icons.south_west,
              size: 14,
            ),
            label: Text(l.label),
          ),
      ],
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
              'aityx gives a probability; the model sets the bar (0.8, or 0.6 '
              'for the topic).',
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
                              'Rule',
                              req,
                              'decision.decisions.clear_topic',
                            ),
                            _JsonLink('Answer', res, 'answers.clear_topic'),
                          ],
                          final id => [
                            _JsonLink(
                              'Question',
                              req,
                              'questions.${id}_probability',
                            ),
                            _JsonLink(
                              'Answer',
                              res,
                              'answers.${id}_probability',
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

class _TopicCard extends StatelessWidget {
  const _TopicCard(this.r, {required this.links});

  final Routing r;
  final Widget links;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final top = r.topicProbabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shown = top.take(4).where((e) => e.value > 0 || e == top.first);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "aityx's reading of the topic",
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'aityx chose ${topicNames[r.topic] ?? r.topic ?? 'nothing'}'
              '${r.topicConfidence == null ? '' : ', ${(r.topicConfidence! * 100).round()}% confident'}.'
              ' The model routes from this answer, but the rules decide.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final e in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        topicNames[e.key] ?? e.key,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: LinearProgressIndicator(
                        value: e.value,
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(5),
                        color: e.key == r.topic
                            ? scheme.primary
                            : scheme.outline,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${(e.value * 100).round()}%',
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            links,
          ],
        ),
      ),
    );
  }
}
