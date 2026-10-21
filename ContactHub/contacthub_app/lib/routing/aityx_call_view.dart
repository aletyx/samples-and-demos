import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'json_layout.dart';

/// Which half of the aityx call.
enum CallSide {
  request('Request', 'What the API sent to aityx'),
  response('Response', "aityx's answer");

  const CallSide(this.label, this.description);

  final String label;
  final String description;
}

/// A part of the call worth jumping to: exactly the value at [path] on
/// [side], with a short [label] and [why] it matters.
class JsonTarget {
  const JsonTarget(this.side, this.path, this.label, this.why);

  final CallSide side;
  final String path;
  final String label;
  final String why;
}

/// Lets the page around an [AityxCallView] show a part of the call: the
/// view switches to [side], scrolls [path]'s first line to the top and
/// marks the whole value.
class AityxCallController extends ChangeNotifier {
  CallSide side = CallSide.request;
  String? path;

  void reveal(CallSide side, String path) {
    this.side = side;
    this.path = path;
    notifyListeners();
  }
}

/// The aityx call behind a routing, large: the request and the response,
/// pretty-printed with line numbers and colors, a "Jump to" bar of
/// [targets] that each scroll to exactly their value, and a full-screen
/// mode.
class AityxCallView extends StatefulWidget {
  const AityxCallView({
    super.key,
    required this.request,
    required this.response,
    required this.targets,
    this.controller,
    this.height = 600,
    this.fullScreen = false,
    this.initialOffsets = const {},
    this.initialMarks = const {},
  });

  final Object? request;
  final Object? response;
  final List<JsonTarget> targets;
  final AityxCallController? controller;

  /// The code panel's height; ignored in [fullScreen], which fills.
  final double height;
  final bool fullScreen;

  /// Where each side starts scrolled, and which part it starts with
  /// marked: full screen opens where the page's view was.
  final Map<CallSide, double> initialOffsets;
  final Map<CallSide, String> initialMarks;

  @override
  State<AityxCallView> createState() => _AityxCallViewState();
}

/// Each line's height: fixed, so a line's offset is exactly
/// `index * _lineHeight` and a jump lands on it.
const _lineHeight = 22.0;
const _fontSize = 14.0;
const _gutterWidth = 52.0;

class _AityxCallViewState extends State<AityxCallView> {
  late final AityxCallController _controller =
      widget.controller ?? AityxCallController();
  final _panelKey = GlobalKey();
  late final _vertical = {
    for (final side in CallSide.values)
      side: ScrollController(
        initialScrollOffset: widget.initialOffsets[side] ?? 0,
      ),
  };
  final _horizontal = {
    for (final side in CallSide.values) side: ScrollController(),
  };
  late Map<CallSide, JsonLayout> _layouts;

  /// The part marked on each side: the last one jumped to.
  late final _active = <CallSide, String>{...widget.initialMarks};

  CallSide get _side => _controller.side;

  @override
  void initState() {
    super.initState();
    _layout();
    _controller.addListener(_onReveal);
    if (_controller.path != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onReveal());
    }
  }

  @override
  void didUpdateWidget(AityxCallView old) {
    super.didUpdateWidget(old);
    if (old.request != widget.request || old.response != widget.response) {
      _layout();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onReveal);
    if (widget.controller == null) _controller.dispose();
    for (final c in [..._vertical.values, ..._horizontal.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _layout() {
    _layouts = {
      CallSide.request: layoutJson(widget.request),
      CallSide.response: layoutJson(widget.response),
    };
  }

  /// The controller asked for a part: switch to its side, bring the panel
  /// into view on the page, then scroll the code to it.
  void _onReveal() {
    final path = _controller.path;
    if (!mounted || path == null) return;
    final side = _controller.side;
    final found = _resolve(side, path);
    setState(() {
      if (found != null) _active[side] = found;
    });
    if (!widget.fullScreen) {
      final panel = _panelKey.currentContext;
      if (panel != null) {
        Scrollable.ensureVisible(
          panel,
          alignment: 0.02,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }
    if (found != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollTo(side, found),
      );
    }
  }

  /// [path] if the side has it, else its nearest parent that it has.
  String? _resolve(CallSide side, String path) {
    final ranges = _layouts[side]!.ranges;
    var p = path;
    while (!ranges.containsKey(p)) {
      final dot = p.lastIndexOf('.');
      if (dot < 0) return null;
      p = p.substring(0, dot);
    }
    return p;
  }

  void _scrollTo(CallSide side, String path) {
    final controller = _vertical[side]!;
    final range = _layouts[side]!.ranges[path];
    if (range == null || !controller.hasClients) return;
    // One line of context above the value's first line.
    final offset = math.max(0.0, 8 + (range.first - 1) * _lineHeight);
    controller.animateTo(
      math.min(offset, controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
    _horizontal[side]!.jumpTo(0);
  }

  void _select(CallSide side) {
    if (side == _side) return;
    setState(() => _controller.side = side);
  }

  void _jump(JsonTarget target) => _controller.reveal(target.side, target.path);

  Future<void> _openFullScreen() {
    // The same side, scroll positions and marks: it opens where you were.
    final controller = AityxCallController()..side = _side;
    final offsets = {
      for (final MapEntry(:key, :value) in _vertical.entries)
        if (value.hasClients) key: value.offset,
    };
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('The aityx call'),
            leading: IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: AityxCallView(
              request: widget.request,
              response: widget.response,
              targets: widget.targets,
              controller: controller,
              fullScreen: true,
              initialOffsets: offsets,
              initialMarks: Map.of(_active),
            ),
          ),
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  void _copy(Object? json) => Clipboard.setData(
    ClipboardData(text: const JsonEncoder.withIndent('  ').convert(json)),
  );

  Object? _valueAt(CallSide side, String path) {
    Object? value = side == CallSide.request ? widget.request : widget.response;
    for (final segment in path.split('.')) {
      value = switch (value) {
        Map map => map[segment],
        List list => list[int.parse(segment)],
        _ => null,
      };
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final side = _side;
    final targets = [
      for (final t in widget.targets)
        if (t.side == side && _layouts[side]!.ranges.containsKey(t.path)) t,
    ];
    final active = _active[side];
    final activeTarget = targets.where((t) => t.path == active).firstOrNull;
    final panel = Container(
      key: _panelKey,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outline),
      ),
      clipBehavior: Clip.antiAlias,
      // Both sides stay built, each with its own scroll position, so a
      // jump to the hidden side can scroll before it shows.
      child: IndexedStack(
        index: side.index,
        sizing: StackFit.expand,
        children: [
          for (final s in CallSide.values)
            _CodePanel(
              layout: _layouts[s]!,
              vertical: _vertical[s]!,
              horizontal: _horizontal[s]!,
              active: _active[s] == null
                  ? null
                  : _layouts[s]!.ranges[_active[s]],
              anchors: {
                for (final t in widget.targets)
                  if (t.side == s && _layouts[s]!.ranges.containsKey(t.path))
                    _layouts[s]!.ranges[t.path]!.first: t,
              },
              activePath: _active[s],
              onAnchor: _jump,
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: widget.fullScreen ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            SegmentedButton<CallSide>(
              segments: [
                for (final s in CallSide.values)
                  ButtonSegment(
                    value: s,
                    label: Text(s.label),
                    tooltip: s.description,
                    icon: Icon(
                      s == CallSide.request
                          ? Icons.north_east
                          : Icons.south_west,
                    ),
                  ),
              ],
              selected: {side},
              onSelectionChanged: (s) => _select(s.single),
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (activeTarget != null)
                  TextButton.icon(
                    onPressed: () => _copy(_valueAt(side, activeTarget.path)),
                    icon: const Icon(Icons.content_copy, size: 18),
                    label: const Text('Copy section'),
                  ),
                TextButton.icon(
                  onPressed: () => _copy(
                    side == CallSide.request ? widget.request : widget.response,
                  ),
                  icon: const Icon(Icons.copy_all, size: 18),
                  label: Text('Copy ${side.label.toLowerCase()}'),
                ),
                if (!widget.fullScreen)
                  IconButton(
                    tooltip: 'Full screen',
                    onPressed: _openFullScreen,
                    icon: const Icon(Icons.open_in_full),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        // The chips and the explanation; in full screen they get at most
        // 40% of the height, scrolling, so a short window keeps room for
        // the code.
        _Controls(
          limit: widget.fullScreen
              ? MediaQuery.sizeOf(context).height * 0.4
              : null,
          children: [
            if (targets.isNotEmpty) ...[
              Text(
                'Jump to',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final t in targets)
                    ChoiceChip(
                      label: Text(t.label),
                      tooltip: t.why,
                      selected: t.path == active,
                      showCheckmark: false,
                      avatar: Icon(
                        Icons.my_location,
                        size: 16,
                        color: t.path == active
                            ? scheme.onPrimaryContainer
                            : scheme.primary,
                      ),
                      onSelected: (_) => _jump(t),
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            // What the marked part is, in words, above the code.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: activeTarget == null
                  ? const SizedBox(width: double.infinity)
                  : Container(
                      key: ValueKey(activeTarget.path),
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(color: scheme.primary, width: 3),
                        ),
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${activeTarget.label}  ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: activeTarget.path,
                              style: TextStyle(
                                fontFamily: 'RobotoMono',
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            TextSpan(text: '\n${activeTarget.why}'),
                          ],
                        ),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
            ),
          ],
        ),
        if (widget.fullScreen)
          Expanded(child: panel)
        else
          SizedBox(height: widget.height, child: panel),
      ],
    );
  }
}

/// The code: one fixed-height row per line, numbered and colored, with the
/// active value marked and each target's first line labeled.
class _CodePanel extends StatelessWidget {
  const _CodePanel({
    required this.layout,
    required this.vertical,
    required this.horizontal,
    required this.active,
    required this.anchors,
    required this.activePath,
    required this.onAnchor,
  });

  final JsonLayout layout;
  final ScrollController vertical;
  final ScrollController horizontal;
  final ({int first, int last})? active;
  final Map<int, JsonTarget> anchors;
  final String? activePath;
  final ValueChanged<JsonTarget> onAnchor;

  static const _style = TextStyle(
    fontFamily: 'RobotoMono',
    fontSize: _fontSize,
    height: 1.2,
  );

  double _charWidth() {
    final painter = TextPainter(
      text: const TextSpan(text: '0000000000', style: _style),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width / 10;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = {
      JsonToken.key: scheme.tertiary,
      JsonToken.string: scheme.secondary,
      JsonToken.number: scheme.onPrimaryContainer,
      JsonToken.literal: scheme.onPrimaryContainer,
      JsonToken.punctuation: scheme.onSurfaceVariant,
      JsonToken.space: scheme.onSurface,
    };
    final contentWidth =
        _gutterWidth + 24 + layout.longestLine * _charWidth() + 240;
    return LayoutBuilder(
      builder: (context, constraints) => Scrollbar(
        controller: horizontal,
        child: SingleChildScrollView(
          controller: horizontal,
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: math.max(constraints.maxWidth, contentWidth),
            height: constraints.maxHeight,
            child: Scrollbar(
              controller: vertical,
              child: ListView.builder(
                controller: vertical,
                // Room below the last line, so a value near the end can
                // still scroll to the top like any other.
                padding: EdgeInsets.only(
                  top: 8,
                  bottom: math.max(8, constraints.maxHeight - 3 * _lineHeight),
                ),
                itemExtent: _lineHeight,
                itemCount: layout.lines.length,
                itemBuilder: (context, i) {
                  final line = layout.lines[i];
                  final marked =
                      active != null && i >= active!.first && i <= active!.last;
                  final anchor = anchors[i];
                  return Container(
                    decoration: marked
                        ? BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.16),
                            border: Border(
                              left: BorderSide(color: scheme.primary, width: 3),
                            ),
                          )
                        : null,
                    child: Row(
                      children: [
                        SizedBox(
                          width: _gutterWidth - (marked ? 3 : 0),
                          child: Text(
                            '${i + 1}',
                            textAlign: TextAlign.right,
                            style: _style.copyWith(
                              color: marked
                                  ? scheme.primary
                                  : scheme.outlineVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text.rich(
                          TextSpan(
                            children: [
                              for (final (kind, text) in tokenize(line.text))
                                TextSpan(
                                  text: text,
                                  style: TextStyle(color: colors[kind]),
                                ),
                            ],
                          ),
                          style: _style,
                          softWrap: false,
                        ),
                        if (anchor != null) ...[
                          const SizedBox(width: 12),
                          _AnchorLabel(
                            anchor,
                            active: anchor.path == activePath,
                            onTap: () => onAnchor(anchor),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A target's label at the end of its first line: tap it to mark the
/// value.
class _AnchorLabel extends StatelessWidget {
  const _AnchorLabel(this.target, {required this.active, required this.onTap});

  final JsonTarget target;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: target.why,
      waitDuration: const Duration(milliseconds: 300),
      constraints: const BoxConstraints(maxWidth: 360),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          decoration: BoxDecoration(
            color: active ? scheme.primary : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.6)),
          ),
          child: Text(
            target.label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: active ? scheme.onPrimary : scheme.onPrimaryContainer,
            ),
          ),
        ),
      ),
    );
  }
}

/// The view's controls, in a column; with a [limit], at most that high and
/// scrolling.
class _Controls extends StatelessWidget {
  const _Controls({required this.limit, required this.children});

  final double? limit;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
    final limit = this.limit;
    if (limit == null) return column;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: limit),
      child: SingleChildScrollView(child: column),
    );
  }
}
