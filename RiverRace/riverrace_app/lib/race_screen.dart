import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'app_version.dart';
import 'calls/calls_panel.dart';
import 'game/race.dart';
import 'game/race_painter.dart';
import 'strategy/decide.dart';
import 'strategy/strategy.dart';
import 'strategy/strategy_panel.dart';
import 'theme.dart';

/// The planes' colors: the player's is the original's yellow, drawn solid;
/// the aityx pilots' are see-through.
const planeColors = {
  'you': Color(0xFFE8E84A),
  'p1': Color(0xFF5FE0F0),
  'p2': Color(0xFFF070E0),
};
const planeOpacity = {'you': 1.0, 'p1': 0.35, 'p2': 0.35};

/// The calls the panel keeps, newest first.
const keptCalls = 120;

/// The race screen: the river with the three planes, its controls, the
/// aityx pilots' strategies, and the calls to aityx in a side panel.
class RaceScreen extends StatefulWidget {
  const RaceScreen({super.key, this.decider, this.seed});

  /// Asks aityx what the pilots do: the app's API unless a test says.
  final Decider? decider;

  /// The first river's seed; random unless a test says.
  final int? seed;

  @override
  State<RaceScreen> createState() => _RaceScreenState();
}

class _RaceScreenState extends State<RaceScreen>
    with SingleTickerProviderStateMixin {
  late final Decider _decider = widget.decider ?? ApiDecider();
  late final Ticker _ticker = createTicker(_tick);
  final _repaint = ValueNotifier(0);
  final _focus = FocusNode(debugLabel: 'race');
  final _random = math.Random();

  late int _seed = widget.seed ?? _random.nextInt(1 << 30);
  late Race _race = _newRace();
  final _strategies = [careful(), daredevil()];

  bool _playing = false;
  bool _youFly = true;

  /// The game's speed, in percent.
  int _speed = 100;
  int _decideEvery = 6;
  bool _hold = false;
  int _finish = 10;

  Duration _last = Duration.zero;

  /// When the race ended: keys still held from playing don't start the
  /// next one for a moment, so the winner can be read.
  DateTime? _overAt;
  double _due = 0;
  int _shownFrame = 0;

  bool _asking = false;
  int _askedAt = 0;
  int _quietUntil = 0;
  String? _error;
  final _calls = <CallRecord>[];
  int _callCount = 0;
  int? _lastTookMs;

  static const _ids = ['p1', 'p2'];

  Race _newRace() => Race(
    seed: _seed,
    planeIds: [if (_youFly) 'you', ..._ids],
    finishBridge: _finish,
  );

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _name(String id) => switch (id) {
    'you' => 'You',
    'p1' => _strategies[0].name,
    'p2' => _strategies[1].name,
    _ => id,
  };

  // --- The loop ---

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    _due = math.min(_due + dt * 60 * _speed / 100, 4);
    while (_due >= 1) {
      if (_race.over) break;
      // A fair race: the game waits for aityx's answer.
      if (_hold && _asking && _race.frame - _askedAt >= _decideEvery) {
        _due = 0;
        break;
      }
      _race.step();
      _due -= 1;
      if (_race.frame % _decideEvery == 0) _ask();
    }
    _repaint.value++;
    if (_race.over) {
      _overAt = DateTime.now();
      _pause();
    } else if (_race.frame - _shownFrame >= 6) {
      _shownFrame = _race.frame;
      setState(() {});
    }
  }

  void _play() {
    if (_race.over) _restart(keepPlaying: false);
    _last = Duration.zero;
    _due = 0;
    _ticker.start();
    setState(() => _playing = true);
    _focus.requestFocus();
  }

  void _pause() {
    if (_ticker.isActive) _ticker.stop();
    setState(() => _playing = false);
  }

  void _restart({bool newRiver = false, bool keepPlaying = true}) {
    final wasPlaying = _playing && keepPlaying;
    _pause();
    setState(() {
      if (newRiver) _seed = _random.nextInt(1 << 30);
      _race = _newRace();
      _shownFrame = 0;
      _asking = false;
      _quietUntil = 0;
      _error = null;
    });
    _repaint.value++;
    if (wasPlaying) _play();
    _focus.requestFocus();
  }

  /// Asks aityx what the flying aityx pilots do now.
  Future<void> _ask() async {
    final race = _race;
    if (_asking || race.frame < _quietUntil) return;
    final pilots = [
      for (final (i, id) in _ids.indexed)
        if (race.plane(id).flying)
          PilotAsk(id, _strategies[i].copy(), race.sense(race.plane(id))),
    ];
    if (pilots.isEmpty) return;
    _asking = true;
    _askedAt = race.frame;
    final frame = race.frame;
    final labels = {
      for (final p in pilots)
        p.id: PilotLabel(p.strategy.name, planeColors[p.id]!),
    };
    final senses = {for (final p in pilots) p.id: p.sense};
    CallRecord record;
    try {
      final decision = await _decider.decide(frame, pilots);
      if (!mounted || race != _race) return;
      for (final MapEntry(key: id, value: action) in decision.actions.entries) {
        final plane = race.plane(id);
        if (plane.flying) plane.action = action;
      }
      _error = null;
      _lastTookMs = decision.tookMs;
      record = CallRecord(
        ++_callCount,
        frame,
        DateTime.now(),
        decision: decision,
        pilots: labels,
        senses: senses,
      );
    } on DecideException catch (e) {
      if (!mounted || race != _race) return;
      _error = e.message;
      // Don't hammer the API while it fails: try again in a second.
      _quietUntil = race.frame + 60;
      record = CallRecord(
        ++_callCount,
        frame,
        DateTime.now(),
        error: e.message,
        pilots: labels,
      );
    } finally {
      if (race == _race) _asking = false;
    }
    setState(() {
      _calls.insert(0, record);
      if (_calls.length > keptCalls) _calls.removeLast();
    });
  }

  // --- The player's keys ---

  /// Keys that don't start the race on their own.
  static final _modifiers = {
    LogicalKeyboardKey.tab,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.capsLock,
    LogicalKeyboardKey.escape,
  };

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyRepeatEvent) return KeyEventResult.ignored;
    final down = event is KeyDownEvent;
    final key = event.logicalKey;
    // Any key starts the race, resumes it, or, once it's over, starts
    // another on a new river; not a shortcut (Cmd, Ctrl, Alt) or Tab.
    final keyboard = HardwareKeyboard.instance;
    if (down &&
        !_playing &&
        !keyboard.isMetaPressed &&
        !keyboard.isControlPressed &&
        !keyboard.isAltPressed &&
        !_modifiers.contains(key)) {
      if (_race.over) {
        final at = _overAt;
        if (at != null &&
            DateTime.now().difference(at) <
                const Duration(milliseconds: 1500)) {
          return KeyEventResult.handled;
        }
        _restart(newRiver: true);
      }
      _play();
      // P and Enter would pause it again; any other key also counts as
      // itself (an arrow held from the start steers).
      if (key == LogicalKeyboardKey.keyP || key == LogicalKeyboardKey.enter) {
        return KeyEventResult.handled;
      }
    }
    final c = _race.controls;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      c.left = down;
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      c.right = down;
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.keyW) {
      c.fast = down;
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.keyS) {
      c.slow = down;
    } else if (key == LogicalKeyboardKey.space) {
      c.fire = down;
    } else if (key == LogicalKeyboardKey.keyP ||
        key == LogicalKeyboardKey.enter) {
      if (down) _playing ? _pause() : _play();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  // --- Layout ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final panel = CallsPanel(
      calls: _calls,
      total: _callCount,
      onClear: () => setState(() {
        _calls.clear();
        _callCount = 0;
      }),
    );
    final main = ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _controls(theme),
        if (_error case final error?)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
            ),
          ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [_game(theme), _hud(theme)],
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              for (final (i, id) in _ids.indexed)
                PilotCard(
                  title: 'pilot ${i + 1}',
                  color: planeColors[id]!,
                  strategy: _strategies[i],
                  plane: _race.plane(id),
                  onChanged: () {
                    setState(() {});
                    _focus.requestFocus();
                  },
                ),
            ];
            return constraints.maxWidth >= 760
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cards[0]),
                      const SizedBox(width: 12),
                      Expanded(child: cards[1]),
                    ],
                  )
                : Column(children: cards);
          },
        ),
        const SizedBox(height: 12),
        _log(theme),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppVersion.title),
        actions: [
          if (!wide)
            Builder(
              builder: (context) => TextButton.icon(
                onPressed: () => Scaffold.of(context).openEndDrawer(),
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text('Calls ($_callCount)'),
              ),
            ),
          if (AppVersion.version.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  AppVersion.version,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.outline,
                  ),
                ),
              ),
            ),
        ],
      ),
      endDrawer: wide
          ? null
          : Drawer(
              width: math.min(460, MediaQuery.sizeOf(context).width * 0.92),
              child: SafeArea(child: panel),
            ),
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: wide
            ? Row(
                children: [
                  Expanded(child: main),
                  const VerticalDivider(width: 1),
                  SizedBox(width: 420, child: panel),
                ],
              )
            : main,
      ),
    );
  }

  Widget _controls(ThemeData theme) {
    final status = [
      'Frame ${_race.frame}',
      if (_asking)
        'asking aityx…'
      else if (_lastTookMs case final ms?)
        'aityx answered in $ms ms',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            onPressed: _playing ? _pause : _play,
            icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
            label: Text(
              _playing ? 'Pause' : (_race.frame == 0 ? 'Start' : 'Play'),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => _restart(),
            icon: const Icon(Icons.replay),
            label: const Text('Restart'),
          ),
          OutlinedButton.icon(
            onPressed: () => _restart(newRiver: true),
            icon: const Icon(Icons.water),
            label: const Text('New river'),
          ),
          FilterChip(
            avatar: Icon(Icons.flight, size: 18, color: planeColors['you']),
            label: const Text('You fly'),
            selected: _youFly,
            tooltip: 'Fly the yellow plane yourself, or let the two aityx pilots race alone',
            onSelected: (on) {
              _youFly = on;
              _restart();
            },
          ),
          FilterChip(
            label: const Text('Fair race'),
            selected: _hold,
            tooltip: 'Hold the game until aityx answers, so the pilots never fly on an old decision',
            onSelected: (on) => setState(() => _hold = on),
          ),
          _Choice<int>(
            label: 'Speed',
            value: _speed,
            options: const {25: '¼×', 50: '½×', 100: '1×'},
            onChanged: (v) => setState(() => _speed = v),
          ),
          _Choice<int>(
            label: 'aityx decides every',
            value: _decideEvery,
            options: const {
              3: '3 frames',
              6: '6 frames',
              12: '12 frames',
              30: '30 frames',
            },
            onChanged: (v) => setState(() => _decideEvery = v),
          ),
          _Choice<int>(
            label: 'Finish at',
            value: _finish,
            options: const {
              5: 'bridge 5',
              10: 'bridge 10',
              20: 'bridge 20',
              0: 'last plane',
            },
            onChanged: (v) {
              _finish = v;
              _restart();
            },
          ),
          Text(
            status.join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _game(ThemeData theme) {
    return GestureDetector(
      onTap: _focus.requestFocus,
      child: AspectRatio(
        aspectRatio: 1.6,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: RacePainter(
                race: _race,
                colors: planeColors,
                opacity: planeOpacity,
                repaint: _repaint,
              ),
            ),
            if (!_playing) _overlay(theme),
          ],
        ),
      ),
    );
  }

  Widget _overlay(ThemeData theme) {
    final winner = _race.winner;
    final lines = winner != null
        ? [
            '${_name(winner.id)} ${winner.id == 'you' ? 'win' : 'wins'}!',
            for (final p in [
              ..._race.planes,
            ]..sort((a, b) => b.score.compareTo(a.score)))
              '${_name(p.id)}: ${p.score} · bridge ${p.bridges} · lost ${p.lost}×',
            'Press any key to race again.',
          ]
        : _race.frame == 0
        ? [
            'Three planes, one river.',
            'Two are flown by aityx, each by its own rules; '
                '${_youFly ? 'the yellow one is yours.' : 'you watch.'}',
            if (_youFly)
              '← → steer · ↑ faster · ↓ slower · space fires · P pauses',
            'Press any key to start.',
          ]
        : ['Paused', 'Press any key to go on.'];
    return Container(
      color: Colors.black.withValues(alpha: 0.55),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, line) in lines.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                line,
                textAlign: TextAlign.center,
                style:
                    (i == 0
                            ? theme.textTheme.headlineSmall
                            : theme.textTheme.bodyLarge)
                        ?.copyWith(
                          color: Colors.white,
                          fontWeight: i == 0 ? FontWeight.bold : null,
                        ),
              ),
            ),
          if (winner != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton.icon(
                onPressed: () {
                  _restart(newRiver: true);
                  _play();
                },
                icon: const Icon(Icons.replay),
                label: const Text('Race again'),
              ),
            ),
        ],
      ),
    );
  }

  /// The gray band under the river, as on the Atari: each plane's score,
  /// planes left and fuel.
  Widget _hud(ThemeData theme) {
    return Container(
      color: const Color(0xFF8E8E8E),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (final p in _race.planes)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.flight, size: 16, color: planeColors[p.id]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _name(p.id),
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '${p.score}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontFamily: 'RobotoMono',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Expanded(
                          child: FuelGauge(
                            fuel: p.fuel,
                            color: Color.lerp(
                              planeColors[p.id],
                              Colors.black,
                              0.25,
                            )!,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          p.state == PlaneState.out ? 'out' : '×${p.lives}',
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _log(ThemeData theme) {
    final events = _race.events.take(8).toList();
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Race log',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            if (events.isEmpty)
              Text(
                'Planes lost, bridges blown up and depots shot show here.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            for (final e in events)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${(e.frame / 60).toStringAsFixed(1)} s  ',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TextSpan(
                      text: _name(e.planeId),
                      style: TextStyle(
                        color: planeColors[e.planeId],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(text: ' ${e.text}'),
                  ],
                ),
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

/// A labeled drop-down of a few options.
class _Choice<T> extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: Theme.of(context).textTheme.bodyMedium),
        DropdownButton<T>(
          value: value,
          isDense: true,
          underline: const SizedBox.shrink(),
          focusColor: Colors.transparent,
          dropdownColor: Aityx.bg2,
          items: [
            for (final MapEntry(:key, value: text) in options.entries)
              DropdownMenuItem(value: key, child: Text(text)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
