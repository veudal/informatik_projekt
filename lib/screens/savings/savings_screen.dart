import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

// Example User class structure as you described
class User {
  final String firstName;
  final String lastName;

  User({required this.firstName, required this.lastName});
}

class SavingsScreen extends StatefulWidget {
  final double totalGoalAmount;
  const SavingsScreen({super.key, this.totalGoalAmount = 1400.0});

  @override
  State<SavingsScreen> createState() => SavingsScreenState();
}

class SavingsScreenState extends State<SavingsScreen> {
  int touchedIndex = -1;

  final List<User> users = [
    User(firstName: 'John', lastName: 'Doe'),
    User(firstName: 'Alice', lastName: 'Smith'),
    User(firstName: 'Bob', lastName: 'Johnson'),
    User(firstName: 'Emma', lastName: 'Brown'),
    User(firstName: 'Michael', lastName: 'Chance'),
    User(firstName: 'Sophia', lastName: 'Lorrence'),
  ];

  // Super nice pastel color palette
  final List<Color> colors = const [
    Color(0xFF5EA89B), // Seafoam Teal
    Color(0xFFF2855C), // Warm Coral
    Color(0xFF8198C4), // Slate Periwinkle Blue
    Color(0xFFE48CBF), // Dusty Rose Pink
    Color(0xFFACCF53), // Chartreuse Lime
    Color(0xFFFCD13B), // Golden Yellow
    Color(0xFF9E8AD8), // Soft Lavender
  ];

  @override
  Widget build(BuildContext context) {
    final List<double> rawAmounts = [350, 200, 150, 150, 100, 50];
    final double totalSaved = rawAmounts.fold(0, (sum, item) => sum + item);
    final double remaining = widget.totalGoalAmount - totalSaved;

    return Column(
      children: [
        Expanded(
          flex: 4, // Increased flex to make the pie chart much bigger
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: PieChart(
                PieChartData(
                  startDegreeOffset: -90,
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      setState(() {
                        if (!event.isInterestedForInteractions ||
                            pieTouchResponse == null ||
                            pieTouchResponse.touchedSection == null) {
                          touchedIndex = -1;
                          return;
                        }
                        touchedIndex =
                            pieTouchResponse.touchedSection!.touchedSectionIndex;
                      });
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 4,
                  centerSpaceRadius: 60, // Larger center space for bigger chart ring
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
    );
  }

  List<PieChartSectionData> showingSections(List<double> values, double remaining) {
    final double totalSaved = values.fold(0, (sum, item) => sum + item);
    final double total = max(widget.totalGoalAmount, totalSaved);
    List<PieChartSectionData> sections = [];
    
    for (int i = 0; i < values.length; i++) {
      final isTouched = i == touchedIndex;
      final radius = isTouched ? 85.0 : 75.0; // Increased radius for bigger chart
      final widgetSize = isTouched ? 50.0 : 38.0;
      final color = colors[i % colors.length];

      final double percentage = total > 0 ? (values[i] / total) * 100 : 0;

      sections.add(PieChartSectionData(
        color: color,
        value: values[i], // Uses raw currency amounts for proportions
        title: '${percentage.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white, // White percentage text inside slices
        ),
        radius: radius,
        badgeWidget: _UserBadge(
          user: users[i % users.length],
          size: widgetSize,
          backgroundColor: color,
        ),
        badgePositionPercentageOffset: 1.05,
      ));
    }

    if (remaining > 0) {
      final isTouched = touchedIndex == values.length;
      final radius = isTouched ? 85.0 : 75.0;
      final double percentage = total > 0 ? (remaining / total) * 100 : 0;

      sections.add(PieChartSectionData(
        color: Colors.grey.shade400, // Nice gray shade for unreached goal
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
    final double totalSaved = values.fold(0, (sum, item) => sum + item);
    // Base total on widget.totalGoalAmount (or totalSaved if it exceeds goal)
    final double total = max(widget.totalGoalAmount, totalSaved);
    List<Widget> legend = [];

    for (int i = 0; i < values.length; i++) {
      final double percentage = total > 0 ? (values[i] / total) * 100 : 0;
      legend.add(_LegendItem(
        color: colors[i % colors.length],
        label: users[i % users.length].firstName,
        amount: values[i],
        percentage: percentage,
      ));
    }

    if (remaining > 0) {
      final double percentage = total > 0 ? (remaining / total) * 100 : 0;
      legend.add(_LegendItem(
        color: Colors.grey.shade400,
        label: 'Remaining',
        amount: remaining,
        percentage: percentage,
      ));
    }

    return legend;
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final double amount;
  final double percentage;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.amount,
    required this.percentage,
  });

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

// Clean badge widget that displays user initials
class _UserBadge extends StatelessWidget {
  const _UserBadge({
    required this.user,
    required this.size,
    required this.backgroundColor,
  });

  final User user;
  final double size;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final String initials = '${user.firstName[0]}${user.firstName[1]}';

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
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Colors.black12,
            offset: Offset(0, 3),
            blurRadius: 4,
          ),
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