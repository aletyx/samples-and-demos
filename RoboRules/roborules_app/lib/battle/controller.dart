import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'api.dart';
import 'model.dart';
import 'random_robots.dart';

/// Where a battle is.
enum BattleState { setup, running, paused, scoring, over }

/// A burst drawn where a robot was hit or died.
class Explosion {
  Explosion(this.x, this.y, this.big, this.at);

  final double x;
  final double y;
  final bool big;
  final DateTime at;
}

/// A robot's totals over the battle's rounds.
class Totals {
  int total = 0;
  int survival = 0;
  int lastSurvivor = 0;
  int bulletDamage = 0;
  int firsts = 0;
}

/// Runs a battle: its rounds, fetching turns from aityx ahead of time and
/// playing them at [turnsPerSecond], scoring each round on aityx.
class BattleController extends ChangeNotifier {
  BattleController({BattleApi? api, RobotFactory? factory})
    : _api = api ?? HttpBattleApi(),
      factory = factory ?? RobotFactory();

  final BattleApi _api;
  final RobotFactory factory;

  List<Robot> robots = [];
  int rounds = 3;

  /// A round ends when one robot is left, or after this many turns.
  int maxTurns = 1500;

  /// Playback speed; 0 means as fast as aityx answers.
  double turnsPerSecond = 15;

  /// Turns asked of aityx per call.
  int turnsPerCall = 20;

  BattleState state = BattleState.setup;
  int round = 0;
  World? world;
  World? previous;
  DateTime shownAt = DateTime.now();
  final explosions = <Explosion>[];
  final roundScores = <RoundScore>[];
  final totals = <String, Totals>{};
  String? error;

  /// The last call to aityx, for the viewer: request and response.
  Object? lastRequest;
  Object? lastResponse;

  /// How fast aityx plays turns, measured.
  double? aityxTurnsPerSecond;

  final _buffer = ListQueue<World>();
  bool _disposed = false;
  bool _fetching = false;
  bool _roundEnds = false;
  Timer? _timer;

  /// Which battle this is: replies to an earlier one, still in flight when
  /// it was restarted, are dropped.
  int _battle = 0;

  /// A finished round aityx couldn't score yet: [retryScore] tries again.
  World? _unscored;

  int get buffered => _buffer.length;
  bool get waitingForAityx => _fetching && _buffer.isEmpty;
  bool get canRetryScore => _unscored != null && state == BattleState.scoring;

  /// [n] new robots with random rules.
  void randomRobots(int n) {
    robots = [];
    for (var i = 0; i < n; i++) {
      robots.add(factory.make(taken: robots));
    }
    _reset();
  }

  void replaceRobot(int index, Robot robot) {
    robots[index] = robot;
    notifyListeners();
  }

  void setSpeed(double tps) {
    turnsPerSecond = tps;
    notifyListeners();
  }

  void _reset() {
    _stopTimer();
    _battle++;
    _fetching = false;
    _roundEnds = false;
    _unscored = null;
    state = BattleState.setup;
    round = 0;
    world = _startWorld();
    previous = null;
    _buffer.clear();
    explosions.clear();
    roundScores.clear();
    totals
      ..clear()
      ..addAll({for (var i = 0; i < robots.length; i++) 'r${i + 1}': Totals()});
    error = null;
    notifyListeners();
  }

  World _startWorld() {
    final places = factory.places(robots.length);
    return World(
      tick: 0,
      bots: [
        for (var i = 0; i < robots.length; i++)
          Bot.start('r${i + 1}', places[i].x, places[i].y, places[i].heading),
      ],
      bullets: const [],
    );
  }

  /// Starts the battle from round 1.
  void start() {
    if (robots.length < 2) return;
    _reset();
    round = 1;
    state = BattleState.running;
    _startTimer();
    _fetch();
    notifyListeners();
  }

  void pause() {
    if (state != BattleState.running) return;
    state = BattleState.paused;
    notifyListeners();
  }

  void resume() {
    if (state != BattleState.paused) return;
    error = null;
    state = BattleState.running;
    shownAt = DateTime.now();
    notifyListeners();
  }

  /// Shows the next turn while paused.
  void nextTurn() {
    if (state == BattleState.paused) _advance();
  }

  void stop() => _reset();

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _tick() {
    final now = DateTime.now();
    explosions.removeWhere((e) => now.difference(e.at).inMilliseconds > 700);
    if (state == BattleState.running) {
      final interval = turnsPerSecond <= 0 ? 0 : 1000 / turnsPerSecond;
      if (_buffer.isNotEmpty &&
          now.difference(shownAt).inMilliseconds >= interval) {
        _advance();
      }
    }
    _fetch();
    // Repaint for smooth movement and fading explosions.
    notifyListeners();
  }

  /// Shows the next buffered turn: explosions for hits and deaths, and
  /// the round's end when it was its last.
  void _advance() {
    if (_buffer.isEmpty) return;
    final next = _buffer.removeFirst();
    final before = world;
    previous = before;
    world = next;
    shownAt = DateTime.now();
    for (final b in next.bots) {
      final was = before?.bots.where((o) => o.id == b.id).firstOrNull;
      if (b.hit) explosions.add(Explosion(b.x, b.y, false, shownAt));
      if (was != null && was.alive && !b.alive) {
        explosions.add(Explosion(b.x, b.y, true, shownAt));
      }
    }
    if (_buffer.isEmpty && _roundEnds) unawaited(_endRound(next));
    notifyListeners();
  }

  /// Asks aityx for the next turns when the buffer runs low.
  Future<void> _fetch() async {
    if (_disposed || _fetching || _roundEnds) return;
    if (state != BattleState.running && state != BattleState.paused) return;
    // After a failed call, wait for Resume rather than retry while paused.
    if (state == BattleState.paused && error != null) return;
    if (_buffer.length >= turnsPerCall) return;
    final from = _buffer.isNotEmpty ? _buffer.last : world;
    if (from == null) return;
    final n = min(turnsPerCall, maxTurns - from.tick);
    if (n <= 0) return;
    _fetching = true;
    final started = DateTime.now();
    final battle = _battle;
    final roundAtStart = round;
    bool stale() => _disposed || battle != _battle || round != roundAtStart;
    try {
      final turns = await _api.turns(robots, from, n);
      if (stale()) return;
      final ms = DateTime.now().difference(started).inMilliseconds;
      aityxTurnsPerSecond = n * 1000 / max(ms, 1);
      lastRequest = turns.request;
      lastResponse = turns.response;
      error = null;
      for (final f in turns.frames) {
        _buffer.add(f);
        if (f.alive <= 1 || f.tick >= maxTurns) {
          _roundEnds = true;
          break;
        }
      }
    } on BattleException catch (e) {
      if (stale()) return;
      error = e.message;
      if (state == BattleState.running) state = BattleState.paused;
    } finally {
      if (battle == _battle) _fetching = false;
      notifyListeners();
    }
  }

  /// Scores the finished round again, after aityx failed to.
  void retryScore() {
    final last = _unscored;
    if (last != null && state == BattleState.scoring) {
      unawaited(_endRound(last));
    }
  }

  Future<void> _endRound(World last) async {
    final battle = _battle;
    bool stale() => _disposed || battle != _battle;
    state = BattleState.scoring;
    _unscored = null;
    error = null;
    notifyListeners();
    try {
      final score = await _api.score(last);
      if (stale()) return;
      roundScores.add(score);
      lastRequest = score.request;
      lastResponse = score.response;
      for (final s in score.scores) {
        final t = totals[s.id];
        if (t == null) continue;
        t
          ..total += s.total
          ..survival += s.survival
          ..lastSurvivor += s.lastSurvivor
          ..bulletDamage += s.bulletDamage;
      }
      if (score.winner case final w?) totals[w]?.firsts += 1;
    } on BattleException catch (e) {
      if (stale()) return;
      // Keep the round until it's scored: moving on would leave it out of
      // the totals and could change the ranking.
      error = 'Scoring failed: ${e.message}';
      _unscored = last;
      notifyListeners();
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (stale() || state != BattleState.scoring) return;
    if (round >= rounds) {
      state = BattleState.over;
      _stopTimer();
      notifyListeners();
      return;
    }
    round += 1;
    world = _startWorld();
    previous = null;
    _roundEnds = false;
    _buffer.clear();
    state = BattleState.running;
    notifyListeners();
  }

  /// The robots in order of their battle total, best first.
  List<int> get ranking {
    final ids = List.generate(robots.length, (i) => i);
    ids.sort(
      (a, b) => (totals['r${b + 1}']?.total ?? 0).compareTo(
        totals['r${a + 1}']?.total ?? 0,
      ),
    );
    return ids;
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTimer();
    super.dispose();
  }
}
