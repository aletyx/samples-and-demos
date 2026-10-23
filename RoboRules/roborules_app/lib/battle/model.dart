import 'dart:ui' show Color;

/// The battlefield's size, as the world model has it (`arena_w`, `arena_h`).
const arenaWidth = 800.0;
const arenaHeight = 600.0;

/// A robot's radius: the world model keeps robots this far from walls.
const robotRadius = 18.0;

/// What a robot senses each turn: the inputs of its aityx model, with
/// their types and what they mean. The world model computes them.
const sensors = <String, (String type, String desc)>{
  'enemy_distance': (
    'number',
    'Distance to the nearest enemy, in pixels (9999 when none is left)',
  ),
  'enemy_bearing': (
    'number',
    'Where the nearest enemy is, in degrees from where the robot faces: '
        'negative to the left, positive to the right (-180 to 180)',
  ),
  'gun_bearing': (
    'number',
    'Where the nearest enemy is, in degrees from where the gun points',
  ),
  'enemy_in_sight': (
    'boolean',
    'Is the nearest enemy within 10 degrees of the gun?',
  ),
  'my_energy': ('number', 'The robot\'s energy (it starts at 100)'),
  'enemy_energy': ('number', "The nearest enemy's energy"),
  'near_wall': ('boolean', 'Is a wall within 80 pixels straight ahead?'),
  'wall_distance': ('number', 'Distance to the nearest wall, in pixels'),
  'gun_ready': ('boolean', 'Has the gun cooled down enough to fire?'),
  'was_hit': ('boolean', 'Was the robot hit by a bullet last turn?'),
  'speed': ('number', 'The robot\'s speed, -8 to 8 pixels a turn'),
  'enemies_left': ('number', 'How many enemies are still alive'),
};

/// The commands a rule sets, and their values (`fire` is a power, 0 to 3).
const commandValues = <String, List<String>>{
  'drive': ['ahead', 'back', 'stop'],
  'turn': [
    'left',
    'right',
    'none',
    'toward_enemy',
    'away_from_enemy',
    'perpendicular',
  ],
  'gun': ['aim', 'sweep_left', 'sweep_right', 'hold'],
};

/// One rule of a robot: conditions on sensors (any it leaves out match
/// anything), the four commands, and why.
class Rule {
  Rule({
    Map<String, String>? when,
    this.drive = 'ahead',
    this.turn = 'none',
    this.gun = 'hold',
    this.fire = 0,
    this.why = '',
  }) : when = when ?? {};

  /// Sensor → condition, as aityx writes them: `true`, `< 200`, `[0..50]`.
  final Map<String, String> when;
  String drive;
  String turn;
  String gun;
  num fire;
  String why;

  Rule copy() => Rule(
    when: Map.of(when),
    drive: drive,
    turn: turn,
    gun: gun,
    fire: fire,
    why: why,
  );
}

/// A robot: its name and color, and its behavior, a FIRST table of
/// [rules]. [toModel] is the robot as aityx runs it.
class Robot {
  Robot({required this.name, required this.color, required this.rules});

  String name;
  Color color;
  List<Rule> rules;

  Robot copy() =>
      Robot(name: name, color: color, rules: [for (final r in rules) r.copy()]);

  /// The sensors its rules test, in [sensors]' order.
  List<String> get columns => [
    for (final s in sensors.keys)
      if (rules.any(
        (r) => (r.when[s] ?? '-').trim() != '-' && r.when[s]!.trim().isNotEmpty,
      ))
        s,
  ];

  /// The robot as an aityx model: the sensors as inputs, and one decision,
  /// `action`, its rules as a FIRST decision table with the four commands
  /// as outputs. It runs on its own too, given the sensors as the state.
  Map<String, Object?> toModel() {
    final cols = columns;
    return {
      'name': name,
      'inputs': {
        for (final MapEntry(:key, :value) in sensors.entries)
          key: {'type': value.$1, 'desc': value.$2},
      },
      'decisions': {
        'action': {
          'desc': 'What $name does this turn: the first rule that matches',
          'table': [
            [
              ...cols,
              '=> drive: ${commandValues['drive']!.join('|')}',
              '=> turn: ${commandValues['turn']!.join('|')}',
              '=> gun: ${commandValues['gun']!.join('|')}',
              '=> fire: number [0..3]',
              '# why',
            ],
            for (final r in rules)
              [
                for (final c in cols) _cell(r.when[c]),
                r.drive,
                r.turn,
                r.gun,
                _number(r.fire),
                r.why,
              ],
          ],
        },
      },
    };
  }

  /// A robot from an aityx model as [toModel] writes it; throws
  /// [FormatException] when it isn't one.
  static Robot fromModel(Object? model, {required Color color}) {
    if (model is! Map) throw const FormatException('not a JSON object');
    final decisions = model['decisions'];
    final action = decisions is Map ? decisions['action'] : null;
    final table = action is Map ? action['table'] : null;
    if (table is! List || table.length < 2 || table.first is! List) {
      throw const FormatException(
        'decisions.action.table needs a header and at least one rule',
      );
    }
    final rawHeader = table.first as List;
    if (rawHeader.any((h) => h is! String)) {
      throw const FormatException('table headers must be strings');
    }
    final header = rawHeader.cast<String>();
    String command(String h) => h.substring(2).split(':').first.trim();
    final commands = <String>{};
    for (final h in header) {
      if (h.startsWith('=>')) {
        final name = command(h);
        if (!{'drive', 'turn', 'gun', 'fire'}.contains(name) ||
            !commands.add(name)) {
          throw FormatException('unknown or duplicate command "$name"');
        }
      } else if (!h.startsWith('#') && !sensors.containsKey(h)) {
        throw FormatException('unknown sensor "$h"');
      }
    }
    if (commands.length != 4) {
      throw const FormatException(
        'table must define drive, turn, gun and fire',
      );
    }
    final rules = <Rule>[];
    for (final raw in table.skip(1)) {
      if (raw is Map &&
          ((raw['when'] != null && raw['when'] is! Map) ||
              (raw['then'] != null && raw['then'] is! Map))) {
        throw const FormatException(
          'rule when and then fields must be objects',
        );
      }
      final row = switch (raw) {
        List l => l.map((c) => '$c').toList(),
        Map m => [
          for (final h in header)
            if (h.startsWith('=>'))
              '${(m['then'] as Map?)?[command(h)] ?? '-'}'
            else if (h.startsWith('#'))
              '${m['why'] ?? ''}'
            else
              '${(m['when'] as Map?)?[h] ?? '-'}',
        ],
        _ => throw const FormatException('a rule must be a list or object'),
      };
      if (row.length != header.length) {
        throw const FormatException('a rule has the wrong number of cells');
      }
      final rule = Rule();
      for (var i = 0; i < header.length; i++) {
        final h = header[i];
        if (h.startsWith('=>')) {
          switch (command(h)) {
            case 'drive':
              if (!commandValues['drive']!.contains(row[i])) {
                throw FormatException('invalid drive command "${row[i]}"');
              }
              rule.drive = row[i];
            case 'turn':
              if (!commandValues['turn']!.contains(row[i])) {
                throw FormatException('invalid turn command "${row[i]}"');
              }
              rule.turn = row[i];
            case 'gun':
              if (!commandValues['gun']!.contains(row[i])) {
                throw FormatException('invalid gun command "${row[i]}"');
              }
              rule.gun = row[i];
            case 'fire':
              final fire = num.tryParse(row[i]);
              if (fire == null || !fire.isFinite || fire < 0 || fire > 3) {
                throw FormatException('invalid fire power "${row[i]}"');
              }
              rule.fire = fire;
            default:
              throw FormatException('unknown command "${command(h)}"');
          }
        } else if (h.startsWith('#')) {
          rule.why = row[i];
        } else if (sensors.containsKey(h)) {
          if (row[i].trim() != '-') rule.when[h] = row[i];
        } else {
          throw FormatException('unknown sensor "$h"');
        }
      }
      rules.add(rule);
    }
    return Robot(
      name: '${model['name'] ?? 'Robot'}',
      color: color,
      rules: rules,
    );
  }
}

String _cell(String? c) => c == null || c.trim().isEmpty ? '-' : c.trim();

String _number(num n) => n == n.roundToDouble() ? '${n.toInt()}' : '$n';

/// A robot on the battlefield, as the world model has it after a turn.
class Bot {
  const Bot({
    required this.id,
    required this.x,
    required this.y,
    required this.heading,
    required this.v,
    required this.gun,
    required this.energy,
    required this.heat,
    required this.alive,
    required this.rule,
    required this.hit,
    required this.damage,
    required this.fired,
    required this.died,
  });

  factory Bot.fromJson(Map json) => Bot(
    id: json['id'] as String,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    heading: (json['heading'] as num).toDouble(),
    v: (json['v'] as num).toDouble(),
    gun: (json['gun'] as num).toDouble(),
    energy: (json['energy'] as num).toDouble(),
    heat: (json['heat'] as num).toDouble(),
    alive: json['alive'] as bool,
    rule: (json['rule'] as num).toInt(),
    hit: json['hit'] as bool,
    damage: (json['damage'] as num).toDouble(),
    fired: (json['fired'] as num).toDouble(),
    died: (json['died'] as num).toInt(),
  );

  /// A robot ready to fight at ([x], [y]), facing [heading].
  factory Bot.start(String id, double x, double y, double heading) => Bot(
    id: id,
    x: x,
    y: y,
    heading: heading,
    v: 0,
    gun: heading,
    energy: 100,
    heat: 3,
    alive: true,
    rule: 0,
    hit: false,
    damage: 0,
    fired: 0,
    died: 0,
  );

  final String id;
  final double x;
  final double y;

  /// Compass degrees: 0 up, clockwise.
  final double heading;
  final double v;
  final double gun;
  final double energy;
  final double heat;
  final bool alive;

  /// The number of the rule it followed this turn (0 before any).
  final int rule;
  final bool hit;

  /// Bullet damage dealt so far this round.
  final double damage;

  /// The power it fired this turn (0 if it didn't).
  final double fired;

  /// The turn it died, 0 while alive.
  final int died;

  Map<String, Object?> toJson() => {
    'id': id,
    'x': x,
    'y': y,
    'heading': heading,
    'v': v,
    'gun': gun,
    'energy': energy,
    'heat': heat,
    'alive': alive,
    'rule': rule,
    'hit': hit,
    'damage': damage,
    'fired': fired,
    'died': died,
  };
}

/// A bullet in flight.
class Bullet {
  const Bullet({
    required this.owner,
    required this.x,
    required this.y,
    required this.heading,
    required this.power,
  });

  factory Bullet.fromJson(Map json) => Bullet(
    owner: json['owner'] as String,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    heading: (json['heading'] as num).toDouble(),
    power: (json['power'] as num).toDouble(),
  );

  final String owner;
  final double x;
  final double y;
  final double heading;
  final double power;

  Map<String, Object?> toJson() => {
    'owner': owner,
    'x': x,
    'y': y,
    'heading': heading,
    'power': power,
  };
}

/// The battlefield after a turn: the world model's `World`.
class World {
  const World({required this.tick, required this.bots, required this.bullets});

  factory World.fromJson(Map json) => World(
    tick: (json['tick'] as num).toInt(),
    bots: [for (final b in json['bots'] as List) Bot.fromJson(b as Map)],
    bullets: [
      for (final b in json['bullets'] as List) Bullet.fromJson(b as Map),
    ],
  );

  final int tick;
  final List<Bot> bots;
  final List<Bullet> bullets;

  int get alive => bots.where((b) => b.alive).length;

  Map<String, Object?> toJson() => {
    'tick': tick,
    'bots': [for (final b in bots) b.toJson()],
    'bullets': [for (final b in bullets) b.toJson()],
  };
}
