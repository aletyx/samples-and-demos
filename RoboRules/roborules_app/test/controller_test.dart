import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roborules_app/battle/api.dart';
import 'package:roborules_app/battle/controller.dart';
import 'package:roborules_app/battle/model.dart';
import 'package:roborules_app/battle/random_robots.dart';
import 'package:roborules_app/main.dart';

/// Plays turns where r2 loses 10 energy a turn, so it dies on turn 10,
/// and scores r1 the winner.
class FakeApi implements BattleApi {
  int turnCalls = 0;
  int scoreCalls = 0;
  Object? failNext;
  Object? failScore;

  /// When set, the next turns call waits for it.
  Completer<void>? hold;

  @override
  Future<Turns> turns(List<Robot> robots, World world, int turns) async {
    turnCalls++;
    final wait = hold;
    hold = null;
    if (wait != null) await wait.future;
    if (failNext case final e?) {
      failNext = null;
      throw e;
    }
    final frames = <World>[];
    var w = world;
    for (var i = 0; i < turns; i++) {
      final tick = w.tick + 1;
      w = World(
        tick: tick,
        bullets: const [],
        bots: [
          for (final b in w.bots)
            b.id == 'r2'
                ? _with(b, energy: max(0, 100 - tick * 10), tick: tick)
                : _with(b, energy: b.energy, tick: tick),
        ],
      );
      frames.add(w);
    }
    return Turns(frames, request: {'decision': {}}, response: {'answers': {}});
  }

  Bot _with(Bot b, {required double energy, required int tick}) => Bot(
    id: b.id,
    x: b.x + 1,
    y: b.y,
    heading: b.heading,
    v: 1,
    gun: b.gun,
    energy: energy,
    heat: 0,
    alive: energy > 0,
    rule: 1,
    hit: energy < b.energy,
    damage: b.damage,
    fired: 0,
    died: energy <= 0 && b.alive ? tick : b.died,
  );

  @override
  Future<RoundScore> score(World last) async {
    scoreCalls++;
    if (failScore case final e?) {
      failScore = null;
      throw e;
    }
    return const RoundScore([
      Score(
        id: 'r1',
        survival: 50,
        lastSurvivor: 10,
        bulletDamage: 100,
        total: 160,
      ),
      Score(id: 'r2', survival: 0, lastSurvivor: 0, bulletDamage: 0, total: 0),
    ], 'r1');
  }
}

void main() {
  BattleController battle(FakeApi api) =>
      BattleController(api: api, factory: RobotFactory(Random(1)))
        ..randomRobots(2)
        ..rounds = 2
        ..turnsPerSecond = 0; // as fast as the turns arrive

  testWidgets('plays every round to the end, scored on aityx', (tester) async {
    final api = FakeApi();
    final c = battle(api);
    c.start();
    expect(c.state, BattleState.running);

    for (var i = 0; i < 400 && c.state != BattleState.over; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(c.state, BattleState.over);
    expect(api.scoreCalls, 2);
    expect(c.totals['r1']!.total, 320);
    expect(c.totals['r1']!.firsts, 2);
    expect(c.ranking.first, 0);
    // r2 died on turn 10 each round: the round stopped there.
    expect(c.world!.tick, 10);
    expect(c.world!.bots[1].alive, isFalse);
    c.dispose();
  });

  testWidgets('a battle after a finished one plays again', (tester) async {
    final api = FakeApi();
    final c = battle(api)..rounds = 1;
    c.start();
    for (var i = 0; i < 200 && c.state != BattleState.over; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(c.state, BattleState.over);
    c.start();
    for (var i = 0; i < 50 && c.world!.tick == 0; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(c.world!.tick, greaterThan(0));
    c.dispose();
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets("a restarted battle drops the old battle's late reply", (
    tester,
  ) async {
    final api = FakeApi()..hold = Completer<void>();
    // Slow, so what arrives stays in the buffer to be counted.
    final c = battle(api)..turnsPerSecond = 1;
    final held = api.hold!;
    c.start(); // the first call waits
    await tester.pump(const Duration(milliseconds: 20));
    c.start(); // restart: a new battle, a new call
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    held.complete(); // the old battle's 20 frames arrive late
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    // Dropped: the turns shown and buffered are the new battle's round
    // alone, which ends on turn 10 (an old reply would add 10 more).
    expect(c.world!.tick + c.buffered, 10);
    expect(api.turnCalls, 2);
    c.dispose();
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a round aityx fails to score waits for a retry', (tester) async {
    final api = FakeApi()
      ..failScore = const BattleException('aityx answered HTTP 503');
    final c = battle(api);
    c.start();
    for (var i = 0; i < 200 && !c.canRetryScore; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(c.canRetryScore, isTrue);
    expect(c.error, contains('Scoring failed'));
    await tester.pump(const Duration(seconds: 3));
    expect(c.round, 1, reason: 'it does not move on unscored');
    expect(c.roundScores, isEmpty);

    c.retryScore();
    for (var i = 0; i < 200 && c.round == 1; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(c.roundScores, hasLength(1));
    expect(c.round, 2);
    expect(c.error, isNull);
    c.dispose();
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a death makes a big explosion', (tester) async {
    final c = battle(FakeApi());
    c.start();
    var big = false;
    for (var i = 0; i < 200 && !big; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      big = c.explosions.any((e) => e.big);
    }
    expect(big, isTrue);
    c.dispose();
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a failed call pauses the battle and says why', (tester) async {
    final api = FakeApi()
      ..failNext = const BattleException('aityx answered HTTP 422');
    final c = battle(api);
    c.start();
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.state, BattleState.paused);
    expect(c.error, contains('422'));
    c.resume();
    for (var i = 0; i < 50 && c.world!.tick == 0; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(c.world!.tick, greaterThan(0));
    expect(c.error, isNull);
    c.dispose();
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('the window shows the robots, and opens one\'s rules', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = battle(FakeApi());
    await tester.pumpWidget(RoboRulesApp(controller: c));
    expect(find.text(c.robots[0].name), findsWidgets);
    expect(find.text(c.robots[1].name), findsWidgets);
    expect(find.text('Start'), findsOneWidget);

    await tester.tap(find.text(c.robots[0].name).last);
    await tester.pumpAndSettle();
    expect(find.text('Rules of ${c.robots[0].name}'), findsOneWidget);
    expect(find.text('Rule 1'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    c.dispose();
  });
}
