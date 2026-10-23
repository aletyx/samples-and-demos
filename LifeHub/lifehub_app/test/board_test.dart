import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lifehub_app/life/board.dart';

/// A horizontal blinker at the origin.
final blinker = cellsOf('ooo');

void main() {
  test('neighbours are counted for every cell that has any', () {
    final counts = neighbourCounts(cellsOf('oo/oo'));
    // Each cell of a block has 3 live neighbours.
    for (final cell in cellsOf('oo/oo')) {
      expect(counts[cell], 3);
    }
    // The cells beside the block have 2, the corners 1.
    expect(counts[(x: -1, y: 0)], 2);
    expect(counts[(x: -1, y: -1)], 1);
    expect(counts[(x: 5, y: 5)], isNull);
    expect(counts, hasLength(16));
  });

  test('situations group the cells, live ones first', () {
    final groups = situationsOf(blinker);
    expect(groups.keys.toList(), [
      (alive: true, neighbours: 1),
      (alive: true, neighbours: 2),
      (alive: false, neighbours: 1),
      (alive: false, neighbours: 2),
      (alive: false, neighbours: 3),
    ]);
    expect(groups[(alive: true, neighbours: 1)], hasLength(2));
    expect(groups[(alive: true, neighbours: 2)], [(x: 1, y: 0)]);
    expect(groups[(alive: false, neighbours: 3)], hasLength(2));
    expect(groups[(alive: false, neighbours: 2)], hasLength(4));
    expect(groups[(alive: false, neighbours: 1)], hasLength(6));
  });

  test('Conway\'s rules turn a blinker', () {
    expect(nextByConway(blinker), cellsOf('o/o/o', x: 1, y: -1));
    expect(nextByConway(nextByConway(blinker)), blinker);
  });

  test('the next generation follows what aityx answered, marking births', () {
    final board = Board(alive: blinker, generation: 3);
    final groups = board.situations;
    // aityx's answer, in the order of the situations: the ends die, the
    // middle survives, the cells above and below the middle are born.
    final next = board.next(groups, [false, true, false, false, true]);
    expect(next.generation, 4);
    expect(next.alive, cellsOf('o/o/o', x: 1, y: -1));
    expect(next.born, {(x: 1, y: -1), (x: 1, y: 1)});
  });

  test('a shape reads the same whichever way it faces', () {
    final glider = cellsOf('.o./..o/ooo');
    final shape = canonicalShape(glider);
    expect(shape, '..o/o.o/.oo');
    // Turned, flipped and moved.
    final turned = {for (final c in glider) (x: -c.y + 7, y: c.x - 3)};
    expect(canonicalShape(turned), shape);
    final flipped = {for (final c in glider) (x: -c.x, y: c.y)};
    expect(canonicalShape(flipped), shape);
  });

  test('a cluster describes itself by its shape\'s own size', () {
    final standing = Cluster(cellsOf('o/o/o'));
    expect(standing.width, 1);
    expect(standing.height, 3);
    expect(standing.toJson(), {
      'cells': 3,
      'width': 1,
      'height': 3,
      'shape': 'o/o/o',
    });
    // Lying down: the same description.
    expect(Cluster(blinker).toJson(), standing.toJson());
  });

  test('clusters are cells within two of each other, top to bottom', () {
    final alive = {
      ...cellsOf('.o./..o/ooo', x: 10, y: 10), // a glider
      ...cellsOf('oo/oo', x: 0, y: 0), // a block
      ...cellsOf('oo../oo../..oo/..oo', x: 20, y: 0), // a beacon, one cluster
      ...cellsOf('ooo/.../.../ooo', x: 0, y: 20), // two blinkers 3 apart
    };
    final clusters = clustersOf(alive);
    expect(clusters.map((c) => c.cells.length), [4, 8, 5, 3, 3]);
    expect(clusters[0].minX, 0);
    expect(clusters[1].shape, Cluster(cellsOf('oo../oo../..oo/..oo')).shape);
    expect(clusters[2].shape, '..o/o.o/.oo');
  });

  test('cells of a shape, and back', () {
    const shape = '.oo./o..o/.oo.';
    expect(canonicalShape(cellsOf(shape, x: 4, y: -2)), '.o./o.o/o.o/.o.');
    expect(cellsOf(shape), hasLength(6));
  });

  test('a random board fills the region at about the density', () {
    final board = Board.random(
      x: -10,
      y: -5,
      width: 40,
      height: 20,
      density: 0.3,
      random: Random(1),
    );
    expect(board.generation, 0);
    expect(board.population, inInclusiveRange(150, 330));
    for (final cell in board.alive) {
      expect(cell.x, inInclusiveRange(-10, 29));
      expect(cell.y, inInclusiveRange(-5, 14));
    }
  });

  test('toggling a cell flips it', () {
    const board = Board();
    final one = board.toggled((x: 2, y: 3));
    expect(one.alive, {(x: 2, y: 3)});
    expect(one.toggled((x: 2, y: 3)).alive, isEmpty);
  });
}
