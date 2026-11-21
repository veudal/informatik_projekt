import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/goal.dart';

class GoalDetailsScreen extends StatefulWidget {
  const GoalDetailsScreen({super.key, required this.goal});

  final Goal goal;

  @override
  State<GoalDetailsScreen> createState() => _GoalDetailsScreenState();
}

class _GoalDetailsScreenState extends State<GoalDetailsScreen> {
  int touchedIndex = -1;

  final List<Color> colors = const [
    Color(0xFF5EA89B),
    Color(0xFFF2855C),
    Color(0xFF8198C4),
    Color(0xFFE48CBF),
    Color(0xFFACCF53),
    Color(0xFFFCD13B),
    Color(0xFF9E8AD8),
  ];

  double get goalAmount => widget.goal.targetCents / 100;

  // TODO: replace with real names (lookup by participantId)
  List<String> get names {
    final ids = widget.goal.participantIds;
    return List.generate(ids.length, (i) => 'User ${i + 1}');
  }

  // TODO: replace with real per-participant contributions (in euros)
  List<double> get amounts {
    final n = widget.goal.participantIds.length;
    if (n == 0) return [];
    return List.filled(n, widget.goal.currentCents / 100 / n);
  }

  @override
  Widget build(BuildContext context) {
    final rawAmounts = amounts;
    final totalSaved = rawAmounts.fold<double>(0, (s, e) => s + e);
    final remaining = goalAmount - totalSaved;

    return Scaffold(
      appBar: AppBar(title: Text(widget.goal.name)),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: PieChart(
                  PieChartData(
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              response == null ||
                              response.touchedSection == null) {
                            touchedIndex = -1;
                            return;
                          }
                          touchedIndex =
                              response.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 4,
                    centerSpaceRadius: 60,
                    sections: showingSections(rawAmounts, remaining),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 20,
                  runSpacing: 10,
                  children: _buildLegend(rawAmounts, remaining),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> showingSections(
      List<double> values, double remaining) {
    final totalSaved = values.fold<double>(0, (s, e) => s + e);
    final total = max(goalAmount, totalSaved);
    final userNames = names;
    final sections = <PieChartSectionData>[];

    for (int i = 0; i < values.length; i++) {
      final isTouched = i == touchedIndex;
      final radius = isTouched ? 85.0 : 75.0;
      final widgetSize = isTouched ? 50.0 : 38.0;
      final color = colors[i % colors.length];
      final percentage = total > 0 ? (values[i] / total) * 100 : 0;

      sections.add(PieChartSectionData(
        color: color,
        value: values[i],
        title: '${percentage.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        radius: radius,
        badgeWidget: _UserBadge(
          name: userNames[i],
          size: widgetSize,
          backgroundColor: color,
        ),
        badgePositionPercentageOffset: 1.05,
      ));
    }

    if (remaining > 0) {
      final isTouched = touchedIndex == values.length;
      final radius = isTouched ? 85.0 : 75.0;
      final percentage = total > 0 ? (remaining / total) * 100 : 0;

      sections.add(PieChartSectionData(
        color: Colors.grey.shade400,
        value: remaining,
        title: '${percentage.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        radius: radius,
      ));
    }

    return sections;
  }

  List<Widget> _buildLegend(List<double> values, double remaining) {
    final userNames = names;
    final legend = <Widget>[];

    for (int i = 0; i < values.length; i++) {
      legend.add(_LegendItem(
        color: colors[i % colors.length],
        label: userNames[i],
        amount: values[i],
      ));
    }

    if (remaining > 0) {
      legend.add(_LegendItem(
        color: Colors.grey.shade400,
        label: 'Remaining',
        amount: remaining,
      ));
    }

    return legend;
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.amount,
  });

  final Color color;
  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 6),
        Text(
          '$label: ${amount.toStringAsFixed(0)}€',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _UserBadge extends StatelessWidget {
  const _UserBadge({
    required this.name,
    required this.size,
    required this.backgroundColor,
  });

  final String name;
  final double size;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final initials = name.length >= 2 ? name.substring(0, 2) : name;

    return AnimatedContainer(
      duration: PieChart.defaultDuration,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: backgroundColor.withValues(alpha: 0.8),
          width: 2.5,
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, offset: Offset(0, 3), blurRadius: 4),
        ],
      ),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: TextStyle(
            fontSize: size * 0.35,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}