import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Why a part of the aityx JSON matters: shown as a highlight on its lines,
/// a short [label] beside it, and [why] in a tooltip.
class JsonNote {
  const JsonNote(
    this.path,
    this.label,
    this.why, {
    this.when,
    this.alarm = false,
  });

  /// Matches the dotted path of the value, from the block's root (list
  /// indexes are segments too: `decision.decisions.ltv_check.table.0`).
  final RegExp path;
  final String label;
  final String why;

  /// When set, the note applies only to values it accepts; a value it
  /// rejects falls through to the next note whose [path] matches.
  final bool Function(Object? value)? when;

  /// Drawn in the theme's error color (red) instead of its primary: for
  /// what makes a proposal Not processable.
  final bool alarm;

  bool matches(String path, Object? value) =>
      this.path.hasMatch(path) && (when?.call(value) ?? true);
}

/// The red of the [JsonNote.alarm] highlights: the theme's error color,
/// lightened so it reads clearly without shouting.
Color _alarmColor(ColorScheme scheme) =>
    Color.lerp(scheme.error, Colors.white, 0.35)!;

bool _failed(Object? check) => check is Map && check['result'] == 'fail';

/// The parts of the body the API sends to aityx worth pointing out.
final requestNotes = [
  JsonNote(
    RegExp(r'^decision$'),
    'The rules',
    'The whole decision model: inputs, decision tables and expressions. '
        'aityx stores no models, so the rules travel with every call, and '
        'what you see here is exactly what was executed.',
  ),
  JsonNote(
    RegExp(r'^decision\.decisions\.[a-z_]+\.table\.0$'),
    'Cited rules',
    "A decision table's header. The first matching row wins, and its "
        "'# why' column cites the source of the rule (Fannie Mae's matrix, "
        'the HUD Handbook, the CFR), so every reason can be traced back.',
  ),
  JsonNote(
    RegExp(r'^decision\.decisions\.status$'),
    'Verdict rule',
    'How the verdict is reached: any failed check makes it Not '
        'processable, else any review makes it Requires review, else '
        "it's Processable.",
  ),
  JsonNote(
    RegExp(r'^state$'),
    'The facts',
    "The borrower's answers, mapped to the model's inputs. The name, email "
        'and phone are left out: aityx gets only what the rules need.',
  ),
  JsonNote(
    RegExp(r'^state\.(loan_program|occupancy|loan_purpose)$'),
    'Picks the rules',
    'The program, occupancy and purpose decide which rows of the tables '
        'apply: each program has its own maximum LTV and ratio limits.',
  ),
  JsonNote(
    RegExp(r'^state\.(property_value|down_payment|current_balance|cash_out)$'),
    'Loan & LTV',
    'Give the loan amount, and with the value the loan-to-value ratio, '
        'compared against the program maximum.',
  ),
  JsonNote(
    RegExp(r'^state\.credit_score$'),
    'Credit',
    'Self-reported band; below 620, or unknown, sends the proposal to '
        'review.',
  ),
  JsonNote(
    RegExp(r'^state\.(annual_income|monthly_debts)$'),
    'Debt-to-income',
    'With the estimated payment, give the debt-to-income ratio, checked '
        "against the program's limits.",
  ),
  JsonNote(
    RegExp(r'^state\.assumed_rate$'),
    'Assumed rate',
    'The annual rate the payment is estimated with: an assumption, not a '
        'priced rate.',
  ),
];

/// The parts of aityx's answer worth pointing out. The red ones come first,
/// so they win over the general note for the same value.
final responseNotes = [
  JsonNote(
    RegExp(r'^answers\.status\.choice$'),
    'Not processable',
    "Where aityx asserts the verdict: a lender can't process this proposal "
        'as asked. At least one check failed (the red Failed check '
        'highlights below), and one failure is enough.',
    when: (value) => value == 'not_processable',
    alarm: true,
  ),
  JsonNote(
    RegExp(r'^answers\.[a-z_]+_check\.value$'),
    'Failed check',
    'This check failed, which alone makes the proposal Not processable. '
        'The reason beside it, from the table row that matched, says why.',
    when: _failed,
    alarm: true,
  ),
  JsonNote(
    RegExp(r'^receipt\.decisions\.status\.value$'),
    'Verdict computed',
    "The receipt's record of the verdict: the status rule found a failed "
        'check, so it computed Not processable. Its branches, next to it, '
        'show the rule that fired.',
    when: (value) => value == 'not_processable',
    alarm: true,
  ),
  JsonNote(
    RegExp(r'^answers$'),
    'Answers',
    'Every decision the model computed. The verdict, the figures and the '
        'reasons above are read straight from here.',
  ),
  JsonNote(
    RegExp(r'^answers\.status$'),
    'The verdict',
    'Processable, Requires review or Not processable: the status shown at '
        'the top of the check.',
  ),
  JsonNote(
    RegExp(r'^answers\.(program|ltv|limit|credit|dti)_check$'),
    'Check & reason',
    "One check's result (pass, review, fail) and its reason, from the "
        'table row that matched. The app shows this reason as is.',
  ),
  JsonNote(
    RegExp(r'^answers\.(ltv|max_ltv|dti|housing_payment)$'),
    'Figure shown',
    'A figure shown above. LTV and DTI stay unrounded here, since the '
        'rules compare exact values (97.0002% is above 97%).',
  ),
  JsonNote(
    RegExp(r'^receipt$'),
    'Audit trail',
    'The receipt: the computed values and where each input came from, '
        'enough to explain the verdict later.',
  ),
  JsonNote(
    RegExp(r'^receipt\.decisions$'),
    'Computed',
    'The value of every decision, helpers included: how the model got '
        'from the facts to the verdict.',
  ),
  JsonNote(
    RegExp(r'^receipt\.provenance$'),
    'Provenance',
    'Where each input came from. "state" means it was supplied in the '
        'request, not inferred by a language model.',
  ),
  JsonNote(
    RegExp(r'^usage$'),
    'Cost',
    "The call's tokens. System One is deterministic: the same facts always "
        'give the same answer.',
  ),
  JsonNote(
    RegExp(r'^decision_error$'),
    'Error',
    'Present only when the model failed to run; the API then reports the '
        'check as failed.',
  ),
];

/// Values printed on more lines than this are highlighted on their first
/// line only, so a large one doesn't tint the whole block.
const _maxHighlightLines = 15;

@visibleForTesting
class AnnotatedLine {
  AnnotatedLine(this.text);

  final String text;
  JsonNote? note;

  /// The first line of a highlighted value: it carries the label.
  bool start = false;
}

/// [json] as `JsonEncoder.withIndent('  ')` prints it, line by line, with
/// [notes] attached to the lines of the values they match. Where notes
/// nest, the innermost wins.
@visibleForTesting
List<AnnotatedLine> annotateJson(Object? json, List<JsonNote> notes) {
  final lines = <AnnotatedLine>[];
  final spans = <(int depth, int first, int last, JsonNote note)>[];

  void emit(Object? value, String path, int depth, String key, String comma) {
    final indent = '  ' * depth;
    final first = lines.length;
    void children(String open, String close, Iterable<(String, Object?)> kids) {
      lines.add(AnnotatedLine('$indent$key$open'));
      final all = kids.toList();
      for (var i = 0; i < all.length; i++) {
        final (name, kid) = all[i];
        emit(
          kid,
          path.isEmpty ? name : '$path.$name',
          depth + 1,
          value is Map ? '${jsonEncode(name)}: ' : '',
          i < all.length - 1 ? ',' : '',
        );
      }
      lines.add(AnnotatedLine('$indent$close$comma'));
    }

    if (value is Map && value.isNotEmpty) {
      children('{', '}', [
        for (final e in value.entries) ('${e.key}', e.value),
      ]);
    } else if (value is List && value.isNotEmpty) {
      children('[', ']', [
        for (var i = 0; i < value.length; i++) ('$i', value[i]),
      ]);
    } else {
      lines.add(AnnotatedLine('$indent$key${jsonEncode(value)}$comma'));
    }
    if (path.isEmpty) return;
    for (final note in notes) {
      if (note.matches(path, value)) {
        spans.add((depth, first, lines.length - 1, note));
        break;
      }
    }
  }

  emit(json, '', 0, '', '');
  spans.sort((a, b) => a.$1.compareTo(b.$1));
  for (final (_, first, last, note) in spans) {
    final end = last - first < _maxHighlightLines ? last : first;
    for (var i = first; i <= end; i++) {
      lines[i]
        ..note = note
        ..start = i == first;
    }
  }
  return lines;
}

/// [json], pretty-printed and selectable under [title], with the parts
/// [notes] match highlighted: a short label beside each, the reason it
/// matters in a tooltip, and chips above that scroll to them.
class AityxJsonView extends StatefulWidget {
  const AityxJsonView(
    this.title,
    this.json, {
    super.key,
    this.notes = const [],
  });

  final String title;
  final Object? json;
  final List<JsonNote> notes;

  @override
  State<AityxJsonView> createState() => _AityxJsonViewState();
}

class _AityxJsonViewState extends State<AityxJsonView> {
  late List<AnnotatedLine> _lines;

  /// The first line of each note's first highlight, to scroll to.
  final _anchors = <JsonNote, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _build();
  }

  @override
  void didUpdateWidget(AityxJsonView old) {
    super.didUpdateWidget(old);
    if (old.json != widget.json || old.notes != widget.notes) _build();
  }

  void _build() {
    _lines = annotateJson(widget.json, widget.notes);
    _anchors.clear();
    for (final line in _lines) {
      if (line.start) _anchors.putIfAbsent(line.note!, GlobalKey.new);
    }
  }

  void _jumpTo(JsonNote note) {
    final context = _anchors[note]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      alignment: 0.1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
    final seen = <JsonNote>{};
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.title, style: theme.textTheme.titleSmall),
              ),
              IconButton(
                tooltip: 'Copy JSON',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                icon: const Icon(Icons.copy),
                onPressed: () => Clipboard.setData(
                  ClipboardData(
                    text: const JsonEncoder.withIndent('  ')
                        .convert(widget.json),
                  ),
                ),
              ),
            ],
          ),
          if (_anchors.isNotEmpty) ...[
            Text(
              'Highlighted parts matter most: hover or tap a label for why. '
              'Jump to:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final note in _anchors.keys)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(
                      note.alarm ? Icons.error_outline : Icons.my_location,
                      size: 14,
                      color: note.alarm ? _alarmColor(scheme) : scheme.primary,
                    ),
                    side: note.alarm
                        ? BorderSide(color: _alarmColor(scheme))
                        : null,
                    label: Text(note.label),
                    tooltip: note.why,
                    onPressed: () => _jumpTo(note),
                  ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Container(
            constraints: const BoxConstraints(maxHeight: 360),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final line in _lines)
                      _JsonLine(
                        line,
                        key: line.start && seen.add(line.note!)
                            ? _anchors[line.note]
                            : null,
                        style: mono,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JsonLine extends StatelessWidget {
  const _JsonLine(this.line, {super.key, this.style});

  final AnnotatedLine line;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final note = line.note;
    final text = Text(line.text, style: style);
    if (note == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: text,
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final accent = note.alarm ? _alarmColor(scheme) : scheme.primary;
    final onAccent = note.alarm ? scheme.onError : scheme.onPrimary;
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: note.alarm ? 0.18 : 0.12),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      padding: const EdgeInsets.only(left: 9, right: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(child: text),
          if (line.start) ...[
            const SizedBox(width: 8),
            Tooltip(
              richMessage: TextSpan(
                children: [
                  TextSpan(
                    text: '${note.label}\n',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: note.why),
                ],
              ),
              triggerMode: TooltipTriggerMode.tap,
              showDuration: const Duration(seconds: 8),
              waitDuration: const Duration(milliseconds: 200),
              constraints: const BoxConstraints(maxWidth: 320),
              child: SelectionContainer.disabled(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline, size: 12, color: onAccent),
                      const SizedBox(width: 3),
                      Text(
                        note.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: onAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
