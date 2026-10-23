/// Writes the pattern catalogue into the Life model
/// (../cellfie_api/models/life.json): the `identify` function's table,
/// one row per phase of each pattern, from the seeds below. Each seed is
/// run by Conway's rules for its period and every phase's canonical shape
/// (lib/life/board.dart, the same code the app uses to describe a
/// cluster) becomes a row, so aityx recognizes a pattern whichever way
/// it's turned and at any point of its cycle.
///
///   dart run tool/catalogue.dart          # rewrites the model's table
///   dart run tool/catalogue.dart --check  # exits 1 if it would change
library;

import 'dart:convert';
import 'dart:io';

import 'package:cellfie_app/life/board.dart';

/// A pattern as Wikipedia's Game of Life page lists it: its id in the
/// model, its name, its period (1 for a still life; a methuselah's seed
/// is one phase), and one phase's layout.
class Seed {
  const Seed(this.id, this.name, this.period, this.shape);

  final String id;
  final String name;
  final int period;
  final String shape;
}

const seeds = [
  // Still lifes
  Seed('block', 'Block', 1, 'oo/oo'),
  Seed('beehive', 'Beehive', 1, '.oo./o..o/.oo.'),
  Seed('loaf', 'Loaf', 1, '.oo./o..o/.o.o/..o.'),
  Seed('boat', 'Boat', 1, 'oo./o.o/.o.'),
  Seed('tub', 'Tub', 1, '.o./o.o/.o.'),
  // Oscillators
  Seed('blinker', 'Blinker', 2, 'ooo'),
  Seed('toad', 'Toad', 2, '.ooo/ooo.'),
  Seed('beacon', 'Beacon', 2, 'oo../oo../..oo/..oo'),
  Seed(
    'pulsar',
    'Pulsar',
    3,
    '..ooo...ooo../............./o....o.o....o/o....o.o....o/o....o.o....o/'
        '..ooo...ooo../............./..ooo...ooo../o....o.o....o/o....o.o....o/'
        'o....o.o....o/............./..ooo...ooo..',
  ),
  Seed(
    'pentadecathlon',
    'Penta-decathlon',
    15,
    '..o....o../oo.oooo.oo/..o....o..',
  ),
  // Spaceships
  Seed('glider', 'Glider', 4, '.o./..o/ooo'),
  Seed('lwss', 'Light-weight spaceship', 4, 'o..o./....o/o...o/.oooo'),
  Seed(
    'mwss',
    'Middle-weight spaceship',
    4,
    '..o.../o...o./.....o/o....o/.ooooo',
  ),
  Seed(
    'hwss',
    'Heavy-weight spaceship',
    4,
    '...oo../.o....o/o....../o.....o/oooooo.',
  ),
  // Methuselahs: recognized as seeded, before they grow
  Seed('r_pentomino', 'R-pentomino', 1, '.oo/oo./.o.'),
  Seed('diehard', 'Diehard', 1, '......o./oo....../.o...ooo'),
  Seed('acorn', 'Acorn', 1, '.o...../...o.../oo..ooo'),
];

/// The catalogue's rows after the header: cells, width, height, shape(s),
/// the pattern, and why.
List<List<String>> catalogueRows() {
  final rows = <List<String>>[];
  for (final seed in seeds) {
    var cells = cellsOf(seed.shape);
    // Every phase's canonical shape, deduplicated: a glider's four phases
    // are two shapes, each the other's mirror image.
    final phases = <String, Set<Cell>>{};
    for (var phase = 0; phase < seed.period; phase++) {
      phases.putIfAbsent(canonicalShape(cells), () => cells);
      cells = nextByConway(cells);
    }
    if (seed.period > 1 &&
        canonicalShape(cells) != canonicalShape(cellsOf(seed.shape))) {
      throw StateError('${seed.name} does not repeat after ${seed.period}');
    }
    // One row per distinct (cells, width, height); the shapes of that size
    // as a comma list.
    final bySize = <(int, int, int), List<String>>{};
    for (final MapEntry(key: shape, value: phaseCells) in phases.entries) {
      final cluster = Cluster(phaseCells);
      (bySize[(
                cluster.cells.length,
                cluster.shapeWidth,
                cluster.shapeHeight,
              )] ??=
              [])
          .add(shape);
    }
    for (final MapEntry(key: (count, width, height), value: shapes)
        in bySize.entries) {
      final phase = phases.length == 1
          ? ''
          : ', ${shapes.length == 1 ? 'one phase' : '${shapes.length} phases'}'
                ' of its ${seed.period}-generation cycle';
      rows.add([
        '$count',
        '$width',
        '$height',
        shapes.map(jsonEncode).join(', '),
        seed.id,
        '${seed.name}$phase.',
      ]);
    }
  }
  return rows;
}

/// The whole `identify` table: the header, the rows, and the else row.
List<List<String>> catalogueTable() => [
  ['cells', 'width', 'height', 'shape', '=>', '# why'],
  ...catalogueRows(),
  ['-', '-', '-', '-', 'unknown', 'Not a pattern in the catalogue.'],
];

Future<void> main(List<String> args) async {
  final file = File('../cellfie_api/models/life.json');
  final model = jsonDecode(await file.readAsString()) as Map<String, Object?>;
  final functions = (model['decision'] as Map)['functions'] as Map;
  final identify = functions['identify'] as Map;
  final table = catalogueTable();
  final changed = jsonEncode(identify['body']) != jsonEncode(table);
  if (args.contains('--check')) {
    stdout.writeln(changed ? 'the catalogue is out of date' : 'up to date');
    exit(changed ? 1 : 0);
  }
  identify['body'] = table;
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(model)}\n',
  );
  stdout.writeln(
    '${table.length - 2} rows for ${seeds.length} patterns '
    '${changed ? 'written' : 'unchanged'} in ${file.path}',
  );
}
