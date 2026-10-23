import 'package:flutter/material.dart';

import '../battle/controller.dart';
import '../battle/model.dart';
import 'classic.dart';

/// What New Battle sets: how many robots, how many rounds.
typedef BattleSetup = ({int robots, int rounds});

/// Battle › New: the number of robots (two by default) and rounds; the
/// robots are made with random rules.
class NewBattleDialog extends StatefulWidget {
  const NewBattleDialog({
    super.key,
    required this.robots,
    required this.rounds,
  });

  final int robots;
  final int rounds;

  @override
  State<NewBattleDialog> createState() => _NewBattleDialogState();
}

class _NewBattleDialogState extends State<NewBattleDialog> {
  late double _robots = widget.robots.toDouble();
  late double _rounds = widget.rounds.toDouble();

  @override
  Widget build(BuildContext context) {
    Widget row(
      String label,
      double value,
      double max,
      ValueChanged<double> on,
    ) => Row(
      children: [
        SizedBox(width: 150, child: Text(label)),
        Expanded(
          child: Slider(
            value: value,
            min: label.startsWith('Robots') ? 2 : 1,
            max: max,
            divisions: (max - (label.startsWith('Robots') ? 2 : 1)).toInt(),
            label: '${value.toInt()}',
            onChanged: on,
          ),
        ),
        SizedBox(
          width: 28,
          child: Text('${value.toInt()}', textAlign: TextAlign.right),
        ),
      ],
    );
    return ClassicDialog(
      title: 'New Battle',
      width: 460,
      actions: [
        ClassicButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        ClassicButton(
          label: 'Start Battle',
          icon: Icons.play_arrow,
          onPressed: () => Navigator.of(context).pop<BattleSetup>((
            robots: _robots.toInt(),
            rounds: _rounds.toInt(),
          )),
        ),
      ],
      child: Bevel(
        pressed: true,
        color: Classic.panelLight,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            row(
              'Robots in the battle',
              _robots,
              10,
              (v) => setState(() => _robots = v),
            ),
            row(
              'Number of rounds',
              _rounds,
              10,
              (v) => setState(() => _rounds = v),
            ),
            const SizedBox(height: 8),
            const Text(
              'Every robot gets random rules: a mix of classic tactics with '
              'random numbers. Select a robot to change them. Every turn of '
              'the battle is played by aityx.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Battle › Results: each robot's totals over the rounds, ranked, as
/// Robocode's results table has them.
class ResultsDialog extends StatelessWidget {
  const ResultsDialog({super.key, required this.controller});

  final BattleController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    const head = TextStyle(fontWeight: FontWeight.bold, fontSize: 12);
    const cell = TextStyle(fontSize: 12);
    final ranking = c.ranking;
    String ord(int n) => switch (n) {
      1 => '1st',
      2 => '2nd',
      3 => '3rd',
      _ => '${n}th',
    };
    return ClassicDialog(
      title:
          'Results for ${c.roundScores.length} '
          'round${c.roundScores.length == 1 ? '' : 's'}',
      width: 640,
      actions: [
        ClassicButton(
          label: 'OK',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      child: Bevel(
        pressed: true,
        color: Colors.white,
        padding: EdgeInsets.zero,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 30,
            dataRowMinHeight: 26,
            dataRowMaxHeight: 30,
            columnSpacing: 18,
            headingRowColor: const WidgetStatePropertyAll(Classic.panel),
            columns: const [
              DataColumn(label: Text('Rank', style: head)),
              DataColumn(label: Text('Robot Name', style: head)),
              DataColumn(
                label: Text('Total Score', style: head),
                numeric: true,
              ),
              DataColumn(label: Text('Survival', style: head), numeric: true),
              DataColumn(label: Text('Surv Bonus', style: head), numeric: true),
              DataColumn(label: Text('Bullet Dmg', style: head), numeric: true),
              DataColumn(label: Text('1sts', style: head), numeric: true),
            ],
            rows: [
              for (var k = 0; k < ranking.length; k++)
                () {
                  final i = ranking[k];
                  final r = c.robots[i];
                  final t = c.totals['r${i + 1}'] ?? Totals();
                  return DataRow(
                    color: WidgetStatePropertyAll(
                      k == 0 ? const Color(0xFFFFF6C8) : Colors.white,
                    ),
                    cells: [
                      DataCell(Text(ord(k + 1), style: cell)),
                      DataCell(
                        Row(
                          children: [
                            Container(width: 10, height: 10, color: r.color),
                            const SizedBox(width: 6),
                            Text(r.name, style: cell),
                          ],
                        ),
                      ),
                      DataCell(Text('${t.total}', style: cell)),
                      DataCell(Text('${t.survival}', style: cell)),
                      DataCell(Text('${t.lastSurvivor}', style: cell)),
                      DataCell(Text('${t.bulletDamage}', style: cell)),
                      DataCell(Text('${t.firsts}', style: cell)),
                    ],
                  );
                }(),
            ],
          ),
        ),
      ),
    );
  }
}

/// A short summary of a robot's rules, for its tooltip.
String rulesSummary(Robot r) => [
  for (var i = 0; i < r.rules.length; i++)
    '${i + 1}. ${r.rules[i].why.isEmpty ? '(no reason)' : r.rules[i].why}',
].join('\n');
