import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/goal.dart';
import '../../models/goal_contribution.dart';
import '../../services/api_service.dart';

class GoalDetailsScreen extends StatefulWidget {
  const GoalDetailsScreen({super.key, required this.goal});

  final Goal goal;

  @override
  State<GoalDetailsScreen> createState() => _GoalDetailsScreenState();
}

class _GoalDetailsScreenState extends State<GoalDetailsScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _error;

  /// User-ID -> Name aller Familienmitglieder (vom Server geladen).
  Map<String, String> _memberNames = {};

  /// Alle Einzahlungen zu diesem Ziel (vom Server geladen).
  List<GoalContribution> _contributions = [];

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ---------------------------------------------------------------------------
  // Daten laden (Familienmitglieder + echte Einzahlungen zum Ziel)
  // ---------------------------------------------------------------------------

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _apiService.getFamilyMemberNames(widget.goal.familyId),
        _apiService.getContributionsForGoal(widget.goal.id),
      ]);
      if (!mounted) return;
      setState(() {
        _memberNames = results[0] as Map<String, String>;
        _contributions = results[1] as List<GoalContribution>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Formatierung & Berechnungen
  // ---------------------------------------------------------------------------

  double get goalAmount => widget.goal.targetCents / 100;

  String _nameOf(String userId) => _memberNames[userId] ?? 'Unbekannt';

  String _formatEuro(double euros) =>
      '${euros.toStringAsFixed(2).replaceAll('.', ',')} €';

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.${date.year}';

  int? _parseAmountCents(String input) {
    final euroAmount = double.tryParse(input.trim().replaceAll(',', '.'));
    if (euroAmount == null || euroAmount <= 0) return null;
    return (euroAmount * 100).round();
  }

  /// Summe der Einzahlungen pro User (in Cents).
  Map<String, int> get _sumPerUser {
    final sums = <String, int>{};
    for (final c in _contributions) {
      sums[c.userId] = (sums[c.userId] ?? 0) + c.amountCents;
    }
    return sums;
  }

  /// Insgesamt in das Ziel eingezahlter Betrag (in Cents).
  int get _savedCents =>
      _contributions.fold(0, (sum, c) => sum + c.amountCents);

  /// Fortschritt 0.0..1.0, berechnet aus den echten Einzahlungen
  /// (das Backend erhöht goal.currentCents beim Einzahlen nicht).
  double get _progress {
    if (widget.goal.targetCents <= 0) return 0;
    return (_savedCents / widget.goal.targetCents).clamp(0.0, 1.0);
  }

  /// Reihenfolge im Diagramm: Teilnehmer zuerst, danach alle User,
  /// die (ohne Teilnehmer zu sein) eingezahlt haben.
  List<String> get _chartUsers {
    final users = <String>[];
    for (final id in widget.goal.participantIds) {
      if (!users.contains(id)) users.add(id);
    }
    for (final id in _sumPerUser.keys) {
      if (!users.contains(id)) users.add(id);
    }
    return users;
  }

  /// Nur User mit einem tatsächlichen Anteil erscheinen im Kreisdiagramm.
  List<String> get _pieUsers =>
      _chartUsers.where((id) => (_sumPerUser[id] ?? 0) > 0).toList();

  List<double> get _pieAmounts =>
      _pieUsers.map((id) => (_sumPerUser[id] ?? 0) / 100).toList();

  List<String> get _pieNames => _pieUsers.map(_nameOf).toList();

  /// Diagrammfarbe eines Users (grau, wenn er nicht im Diagramm ist).
  Color colorForUser(String userId) {
    final index = _pieUsers.indexOf(userId);
    if (index < 0) return Colors.grey.shade300;
    return colors[index % colors.length];
  }

  // ---------------------------------------------------------------------------
  // Dialog: Einzahlen
  // ---------------------------------------------------------------------------

  void _showDepositDialog() {
    final formKey = GlobalKey<FormState>();
    final amountController = TextEditingController();
    final goal = widget.goal;

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            Future<void> submit() async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final cents = _parseAmountCents(amountController.text);
              if (cents == null) return;
              setStateDialog(() => isSubmitting = true);
              try {
                await _apiService.createGoalContribution(
                  goalId: goal.id,
                  amountCents: cents,
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${_formatEuro(cents / 100)} für "${goal.name}" eingezahlt.',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
                _load();
              } catch (e) {
                setStateDialog(() => isSubmitting = false);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Einzahlung fehlgeschlagen: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return AlertDialog(
              title: const Text('Einzahlen'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Betrag (€)',
                        hintText: 'z. B. 10,50',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          _parseAmountCents(value ?? '') == null
                              ? 'Bitte gültigen Betrag eingeben'
                              : null,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final quick in const [5, 10, 25, 50])
                          ActionChip(
                            label: Text('$quick €'),
                            onPressed: () =>
                                amountController.text = quick.toString(),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Abbrechen'),
                ),
                FilledButton.icon(
                  onPressed: isSubmitting ? null : submit,
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.savings),
                  label: const Text('Einzahlen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zieldetails')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                'Zieldetails konnten nicht geladen werden:\n$_error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      );
    }

    final pieAmounts = _pieAmounts;
    final pieNames = _pieNames;
    final remaining = max(0.0, goalAmount - _savedCents / 100);

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildChartCard(pieAmounts, pieNames, remaining),
            const SizedBox(height: 16),
            _buildLegendCard(remaining),
            const SizedBox(height: 16),
            _buildContributionsCard(),
          ],
        ),
      ),
    );
  }

  Widget _statusChip() {
    final isActive = widget.goal.status == 'active';
    final color = isActive ? Colors.green : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Aktiv' : widget.goal.status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color.withValues(alpha: 1.0),
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildHeaderCard() {
    final goal = widget.goal;
    final savedEuros = _savedCents / 100;
    final remaining = max(0.0, goalAmount - savedEuros);
    final goalReached = remaining <= 0 && _savedCents > 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    goal.name.isEmpty ? 'Unbenanntes Ziel' : goal.name,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                _statusChip(),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (goal.deadline != null)
                  _infoChip(Icons.event, 'Bis ${_formatDate(goal.deadline!)}'),
                _infoChip(
                    Icons.group, '${goal.participantIds.length} Teilnehmer'),
                if (goal.ownerId != null &&
                    _memberNames.containsKey(goal.ownerId))
                  _infoChip(
                      Icons.emoji_events, 'Ziel von ${_nameOf(goal.ownerId!)}'),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: _progress, minHeight: 10),
            ),
            const SizedBox(height: 8),
            Text(
              '${_formatEuro(savedEuros)} von ${_formatEuro(goalAmount)} erreicht',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              goalReached
                  ? 'Ziel erreicht! 🎉'
                  : 'Noch ${_formatEuro(remaining)} bis zum Ziel',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: goalReached ? Colors.green : Colors.grey,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _showDepositDialog,
                icon: const Icon(Icons.savings),
                label: const Text('Einzahlen'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(
      List<double> values, List<String> userNames, double remaining) {
    final totalSaved = values.fold<double>(0, (s, e) => s + e);
    final percent =
        goalAmount > 0 ? (min(totalSaved, goalAmount) / goalAmount) * 100 : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
        child: Column(
          children: [
            Text('Aufteilung', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
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
                      sections: showingSections(values, userNames, remaining),
                    ),
                  ),
                  IgnorePointer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${percent.toStringAsFixed(0)} %',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatEuro(totalSaved)} / ${_formatEuro(goalAmount)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendCard(double remaining) {
    final sums = _sumPerUser;

    // Erst die Teilnehmer des Ziels, danach die übrigen Familienmitglieder.
    final ids = <String>[...widget.goal.participantIds];
    final others = _memberNames.keys
        .where((id) => !ids.contains(id))
        .toList()
      ..sort((a, b) =>
          _nameOf(a).toLowerCase().compareTo(_nameOf(b).toLowerCase()));
    ids.addAll(others);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Beiträge der Familienmitglieder',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final id in ids)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colorForUser(id),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              _nameOf(id),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!widget.goal.participantIds.contains(id)) ...[
                            const SizedBox(width: 4),
                            Text(
                              '· kein Teilnehmer',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatEuro((sums[id] ?? 0) / 100),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            if (remaining > 0) ...[
              const Divider(),
              Row(
                children: [
                  Container(
                      width: 12, height: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Übrig')),
                  Text(
                    _formatEuro(remaining),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContributionsCard() {
    final sorted = [..._contributions]..sort((a, b) {
        final aDate = a.createdAt ?? DateTime(0);
        final bDate = b.createdAt ?? DateTime(0);
        return bDate.compareTo(aDate);
      });
    const maxEntries = 8;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Letzte Einzahlungen',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (sorted.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Noch keine Einzahlungen. Sei der Erste!',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              ...sorted.take(maxEntries).map(_buildContributionTile),
            if (sorted.length > maxEntries)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '… und ${sorted.length - maxEntries} weitere',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContributionTile(GoalContribution contribution) {
    final name = _nameOf(contribution.userId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor:
                colorForUser(contribution.userId).withValues(alpha: 0.25),
            child: Text(
              name.isEmpty
                  ? '?'
                  : name.substring(0, min(2, name.length)).toUpperCase(),
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
          if (contribution.createdAt != null)
            Text(
              _formatDate(contribution.createdAt!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(width: 10),
          Text(
            '+${_formatEuro(contribution.amountCents / 100)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> showingSections(
      List<double> values, List<String> userNames, double remaining) {
    final totalSaved = values.fold<double>(0, (s, e) => s + e);
    final total = max(goalAmount, totalSaved);
    final sections = <PieChartSectionData>[];

    for (int i = 0; i < values.length; i++) {
      final isTouched = touchedIndex == i;
      final radius = isTouched ? 85.0 : 75.0;
      final color = colors[i % colors.length];
      final percentage = total > 0 ? (values[i] / total) * 100 : 0.0;
      final widgetSize = isTouched ? 55.0 : 40.0;

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
      final percentage = total > 0 ? (remaining / total) * 100 : 0.0;

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
}

/// Badge mit den Initialen eines Users am Rand des Kreisdiagramms.
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