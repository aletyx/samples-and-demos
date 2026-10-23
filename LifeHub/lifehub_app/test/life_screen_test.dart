import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifehub_app/life/board.dart';
import 'package:lifehub_app/life/generation.dart';
import 'package:lifehub_app/main.dart';

/// Answers as aityx would, with Conway's rules run here and a catalogue
/// of three patterns, and keeps what it was asked.
class FakeStepper implements GenerationStepper {
  final asked = <Map<String, Object?>>[];
  Object? failWith;

  static final catalogue = {
    canonicalShape(cellsOf('oo/oo')): ('block', 'still_life'),
    canonicalShape(cellsOf('ooo')): ('blinker', 'oscillator'),
    canonicalShape(cellsOf('.o./..o/ooo')): ('glider', 'spaceship'),
  };

  @override
  Future<GenerationOutcome> step(
    int generation,
    Map<String, bool> rules,
    Map<SituationKey, List<Cell>> situations,
    List<Cluster> clusters,
  ) async {
    final body = generationBody(generation, rules, situations, clusters);
    asked.add(body);
    if (failWith case final String message) {
      throw GenerationException(message);
    }
    final fates = [
      for (final key in situations.keys)
        switch ((key.alive, key.neighbours)) {
          (true, < 2) => 'dies_lonely',
          (true, 2 || 3) => 'survives',
          (true, _) => 'dies_crowded',
          (false, 3) => 'is_born',
          _ => 'stays_empty',
        },
    ];
    int cellsWhere(bool Function(int) test) {
      var n = 0;
      var i = 0;
      for (final cells in situations.values) {
        if (test(i++)) n += cells.length;
      }
      return n;
    }

    final population = cellsWhere((i) => situations.keys.elementAt(i).alive);
    final survivors = cellsWhere((i) => fates[i] == 'survives');
    final births = cellsWhere((i) => fates[i] == 'is_born');
    return GenerationOutcome(
      Generation.fromJson({
        'generation': generation,
        'next_generation': generation + 1,
        'population': population,
        'population_next': survivors + births,
        'births': births,
        'deaths': population - survivors,
        'survivors': survivors,
        'situations': [
          for (final (i, key) in situations.keys.indexed)
            {
              'alive': key.alive,
              'neighbours': key.neighbours,
              'cells': situations[key]!.length,
              'fate': fates[i],
              'alive_next': fates[i] == 'survives' || fates[i] == 'is_born',
              'rule': 1,
              'why': 'because',
            },
        ],
        'clusters': [
          for (final c in clusters)
            {
              ...c.toJson(),
              'pattern': catalogue[c.shape]?.$1 ?? 'unknown',
              'kind': catalogue[c.shape]?.$2 ?? 'unknown',
              'about': catalogue.containsKey(c.shape) ? 'A known pattern.' : null,
            },
        ],
        'recognized': clusters.where((c) => catalogue.containsKey(c.shape)).length,
      }),
      aityxRequest: {'decision': {'name': 'Life'}, 'state': body},
      aityxResponse: {'answers': {}},
      tookMs: 7,
      inputTokens: 100,
    );
  }
}

void main() {
  testWidgets('opens on the board, empty, with a hint', (tester) async {
    await tester.pumpWidget(LifeHubApp(stepper: FakeStepper()));

    expect(find.byType(LifeScreen), findsOneWidget);
    expect(find.text('Life Hub'), findsOneWidget);
    expect(find.byType(BoardView), findsOneWidget);
    expect(find.textContaining('Press Random start'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('Acceleration'), findsOneWidget);
    expect(find.textContaining('Generation 0 · 0 cells'), findsOneWidget);
    // A test build has no LIFEHUB_VERSION, so no X.Y.Z shows.
    expect(find.textContaining(RegExp(r'^\d+\.\d+\.\d+$')), findsNothing);
  });

  testWidgets('a random start fills the view, and Clear empties it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(home: LifeScreen(stepper: FakeStepper(), random: Random(3))),
    );

    await tester.tap(find.text('Random start'));
    await tester.pump();
    final status = find.textContaining(RegExp(r'Generation 0 · \d+ cells'));
    expect(status, findsOneWidget);
    final cells = int.parse(
      RegExp(r'(\d+) cells').firstMatch(tester.widget<Text>(status).data!)![1]!,
    );
    expect(cells, greaterThan(100));
    expect(find.textContaining('Press Random start'), findsNothing);

    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.textContaining('Generation 0 · 0 cells'), findsOneWidget);
  });

  testWidgets('Step asks for one generation and shows the call', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stepper = FakeStepper();
    await tester.pumpWidget(MaterialApp(home: LifeScreen(stepper: stepper)));

    // Draw a blinker at the origin by tapping three cells: the view is
    // centered on the origin at 14 px a cell.
    final view = tester.getRect(find.byType(BoardView));
    for (final x in [-1, 0, 1]) {
      await tester.tapAt(view.center + Offset(x * 14.0 + 7, 7));
    }
    await tester.pump();
    expect(find.textContaining('Generation 0 · 3 cells'), findsOneWidget);

    await tester.tap(find.text('Step'));
    await tester.pump();
    await tester.pump();
    expect(stepper.asked, hasLength(1));
    final body = stepper.asked.single;
    expect(body['generation'], 0);
    expect(body['rules'], {'conway': true, 'highlife': false, 'no_death': false});
    expect((body['situations'] as List), hasLength(5));
    expect((body['clusters'] as List).single, {
      'cells': 3,
      'width': 1,
      'height': 3,
      'shape': 'o/o/o',
    });
    // The blinker turned, still 3 cells, and the panel shows the call.
    expect(find.textContaining('Generation 1 · 3 cells'), findsOneWidget);
    expect(find.text('Generation 0 → 1'), findsOneWidget);
    expect(find.text('+2 born'), findsOneWidget);
    expect(find.text('−2 died'), findsOneWidget);
    expect(find.text('blinker'), findsWidgets);
    // A blinker appeared: a notice on the board and in the panel.
    expect(find.text('Generation 0: A blinker appeared'), findsNWidgets(2));
    expect(find.text('Patterns noticed'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('Play runs generations at the acceleration until paused', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stepper = FakeStepper();
    await tester.pumpWidget(MaterialApp(home: LifeScreen(stepper: stepper)));
    final view = tester.getRect(find.byType(BoardView));
    for (final x in [-1, 0, 1]) {
      await tester.tapAt(view.center + Offset(x * 14.0 + 7, 7));
    }
    await tester.pump();

    // 2 generations/s by default: one every 500 ms.
    expect(find.text('2 generations/s'), findsOneWidget);
    await tester.tap(find.text('Play'));
    await tester.pump();
    expect(find.text('Pause'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();
    expect(stepper.asked.length, inInclusiveRange(2, 3));

    await tester.tap(find.text('Pause'));
    await tester.pump();
    final asked = stepper.asked.length;
    await tester.pump(const Duration(seconds: 2));
    expect(stepper.asked.length, asked);
    expect(find.text('Play'), findsOneWidget);
    await tester.pump(const Duration(seconds: 9));
  });

  testWidgets('the Rules dialog switches rules for the next generation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stepper = FakeStepper();
    await tester.pumpWidget(MaterialApp(home: LifeScreen(stepper: stepper)));
    final view = tester.getRect(find.byType(BoardView));
    await tester.tapAt(view.center + const Offset(7, 7));
    await tester.pump();

    expect(find.text('Rules (1 of 3)'), findsOneWidget);
    await tester.tap(find.text('Rules (1 of 3)'));
    await tester.pumpAndSettle();
    expect(find.text('Conway\'s rules'), findsOneWidget);
    await tester.tap(find.text('Life without death'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Rules (2 of 3)'), findsOneWidget);

    await tester.tap(find.text('Step'));
    await tester.pump();
    await tester.pump();
    expect(stepper.asked.single['rules'], {
      'conway': true,
      'highlife': false,
      'no_death': true,
    });
  });

  testWidgets('a failed generation pauses and says why', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stepper = FakeStepper()..failWith = 'The API did not answer.';
    await tester.pumpWidget(MaterialApp(home: LifeScreen(stepper: stepper)));
    final view = tester.getRect(find.byType(BoardView));
    await tester.tapAt(view.center + const Offset(7, 7));
    await tester.pump();

    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump();
    expect(find.text('The API did not answer.'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
  });

  testWidgets('on a phone the calls open from the app bar', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: LifeScreen(stepper: FakeStepper())));

    expect(find.byType(CallsPanel), findsNothing);
    await tester.tap(find.text('Calls (0)'));
    await tester.pumpAndSettle();
    expect(find.byType(CallsPanel), findsOneWidget);
    expect(find.textContaining('Every generation is one call'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
