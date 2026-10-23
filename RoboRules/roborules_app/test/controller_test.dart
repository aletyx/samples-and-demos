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

  @override
  Future<Turns> turns(List<Robot> robots, World world, int turns) async {
    turnCalls++;
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

class DeferredApi extends FakeApi {
  final requests = <Completer<Turns>>[];

  @override
  Future<Turns> turns(List<Robot> robots, World world, int turns) {
    final request = Completer<Turns>();
    requests.add(request);
    return request.future;
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
    final turnCalls = api.turnCalls;
    c.start();
    expect(c.state, BattleState.running);
    expect(api.turnCalls, greaterThan(turnCalls));
    c.dispose();
  });

  testWidgets('a response from before restart cannot fill the new battle', (
    tester,
  ) async {
    final api = DeferredApi();
    final c = battle(api);
    c.start();
    final oldWorld = c.world!;
    expect(api.requests, hasLength(1));

    c.stop();
    c.start();
    api.requests.first.complete(await FakeApi().turns(c.robots, oldWorld, 1));
    await tester.pump();
    expect(c.world!.tick, 0);
    expect(c.buffered, 0);

    await tester.pump(const Duration(milliseconds: 20));
    expect(api.requests, hasLength(2));
    api.requests.last.complete(await FakeApi().turns(c.robots, c.world!, 1));
    await tester.pump(const Duration(milliseconds: 20));
    expect(c.world!.tick, 1);
    c.dispose();
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
