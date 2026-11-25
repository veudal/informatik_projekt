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
  static const _colors = [
    Color(0xFF5EA89B),
    Color(0xFFF2855C),
    Color(0xFF8198C4),
    Color(0xFFE48CBF),
    Color(0xFFACCF53),
    Color(0xFFFCD13B),
    Color(0xFF9E8AD8),
  ];

  final _api = ApiService();

  bool _isLoading = true;
  String? _error;
  Map<String, String> _memberNames = {};
  List<GoalContribution> _contributions = [];
  int _touchedIndex = -1;

  Goal get _goal => widget.goal;
  double get _goalAmount => _goal.targetCents / 100;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.getFamilyMemberNames(_goal.familyId),
        _api.getContributionsForGoal(_goal.id),
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

  String _nameOf(String id) => _memberNames[id] ?? 'Unbekannt';
  String _euro(num cents) =>
      '${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  int? _parseCents(String input) {
    final euros = double.tryParse(input.trim().replaceAll(',', '.'));
    return (euros == null || euros <= 0) ? null : (euros * 100).round();
  }

  Map<String, int> get _sumPerUser {
    final sums = <String, int>{};
    for (final c in _contributions) {
      sums[c.userId] = (sums[c.userId] ?? 0) + c.amountCents;
    }
    return sums;
  }

  int get _savedCents => _contributions.fold(0, (s, c) => s + c.amountCents);

  double get _progress => _goal.targetCents <= 0
      ? 0
      : (_savedCents / _goal.targetCents).clamp(0.0, 1.0);

  /// Teilnehmer + alle, die eingezahlt haben, die > 0 beigetragen haben.
  List<String> get _pieUsers => {
    ..._goal.participantIds,
    ..._sumPerUser.keys,
  }.where((id) => (_sumPerUser[id] ?? 0) > 0).toList();

  Color _colorForUser(String id) {
    final i = _pieUsers.indexOf(id);
    return i < 0 ? Colors.grey.shade300 : _colors[i % _colors.length];
  }

  void _snack(String text, Color color) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(text), backgroundColor: color));

  void _showDepositDialog() {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialog) {
          Future<void> submit() async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            final cents = _parseCents(controller.text)!;
            setDialog(() => isSubmitting = true);
            try {
              await _api.createGoalContribution(
                goalId: _goal.id,
                amountCents: cents,
              );
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!mounted) return;
              _snack(
                '${_euro(cents)} für "${_goal.name}" eingezahlt.',
                Colors.green,
              );
              _load();
            } catch (e) {
              setDialog(() => isSubmitting = false);
              if (mounted) _snack('Einzahlung fehlgeschlagen: $e', Colors.red);
            }
          }

          return AlertDialog(
            actionsOverflowAlignment: OverflowBarAlignment.center,
            titlePadding: const EdgeInsets.fromLTRB(28, 28, 28, 8),
            contentPadding: const EdgeInsets.fromLTRB(28, 16, 28, 8),
            actionsPadding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
            actionsOverflowButtonSpacing: 2,
            title: const Text('Einzahlen'),
            content: SizedBox(
              width: 400,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 16),
                    TextFormField(
                      controller: controller,
                      onChanged: (_) => setDialog(() {}),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Betrag (€)',
                        hintText: 'z. B. 2,50',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => _parseCents(v ?? '') == null
                          ? 'Bitte gültigen Betrag eingeben'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final q in const [5, 10, 25, 50])
                          ChoiceChip(
                            label: Text('$q €'),
                            showCheckmark: true,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            selected: controller.text == '$q',
                            onSelected: (_) =>
                                setDialog(() => controller.text = '$q'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              SizedBox(height: 32),
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Abbrechen'),
              ),
              SizedBox(height: 8),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Zieldetails')),
    body: _buildBody(),
  );

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
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

    final remaining = max(0.0, _goalAmount - _savedCents / 100);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildHeaderCard(remaining),
          _buildChartCard(remaining),
          _buildLegendCard(remaining),
          _buildContributionsCard(),
        ].expand((w) => [w, const SizedBox(height: 16)]).toList()..removeLast(),
      ),
    );
  }

  Widget _buildHeaderCard(double remaining) {
    final theme = Theme.of(context);
    final isActive = _goal.status == 'active';
    final statusColor = isActive ? Colors.green : Colors.grey;
    final goalReached = remaining <= 0 && _savedCents > 0;

    Widget infoChip(IconData icon, String label) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.primary),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );

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
                    _goal.name.isEmpty ? 'Unbenanntes Ziel' : _goal.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isActive ? 'Aktiv' : _goal.status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (_goal.deadline != null)
                  infoChip(Icons.event, 'Bis ${_formatDate(_goal.deadline!)}'),
                infoChip(
                  Icons.group,
                  '${_goal.participantIds.length} Teilnehmer',
                ),
                if (_memberNames.containsKey(_goal.ownerId))
                  infoChip(
                    Icons.emoji_events,
                    'Ziel von ${_nameOf(_goal.ownerId!)}',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: _progress, minHeight: 10),
            ),
            const SizedBox(height: 8),
            Text(
              '${_euro(_savedCents)} von ${_euro(_goal.targetCents)} erreicht',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              goalReached
                  ? 'Ziel erreicht! 🎉'
                  : 'Noch ${_euro(remaining * 100)} bis zum Ziel',
              style: theme.textTheme.bodySmall?.copyWith(
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

  Widget _buildChartCard(double remaining) {
    final theme = Theme.of(context);
    final percent = _goalAmount > 0
        ? min(_savedCents / 100, _goalAmount) / _goalAmount * 100
        : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 16),
        child: Column(
          children: [
            Text('Aufteilung', style: theme.textTheme.titleMedium),
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
                          setState(
                            () => _touchedIndex =
                                (!event.isInterestedForInteractions ||
                                    response?.touchedSection == null)
                                ? -1
                                : response!.touchedSection!.touchedSectionIndex,
                          );
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 4,
                      centerSpaceRadius: 60,
                      sections: _sections(remaining),
                    ),
                  ),
                  IgnorePointer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${percent.toStringAsFixed(0)} %',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_euro(_savedCents)} / ${_euro(_goal.targetCents)}',
                          style: theme.textTheme.bodySmall,
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
    final others =
        _memberNames.keys
            .where((id) => !_goal.participantIds.contains(id))
            .toList()
          ..sort(
            (a, b) =>
                _nameOf(a).toLowerCase().compareTo(_nameOf(b).toLowerCase()),
          );
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Beiträge der Familienmitglieder',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final id in [..._goal.participantIds, ...others])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _colorForUser(id),
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
                          if (!_goal.participantIds.contains(id))
                            Text(
                              ' · kein Teilnehmer',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _euro(sums[id] ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            if (remaining > 0) ...[
              const Divider(),
              Row(
                children: [
                  Container(width: 12, height: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Übrig')),
                  Text(
                    _euro(remaining * 100),
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
    const maxEntries = 8;
    final theme = Theme.of(context);
    final sorted = [..._contributions]
      ..sort(
        (a, b) =>
            (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)),
      );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Letzte Einzahlungen', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (sorted.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Noch keine Einzahlungen. Sei der Erste!',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else
              ...sorted.take(maxEntries).map(_buildContributionTile),
            if (sorted.length > maxEntries)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '… und ${sorted.length - maxEntries} weitere',
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContributionTile(GoalContribution c) {
    final name = _nameOf(c.userId);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: _colorForUser(c.userId).withValues(alpha: 0.25),
            child: Text(
              _initials(name),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
          if (c.createdAt != null)
            Text(
              _formatDate(c.createdAt!),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(width: 10),
          Text(
            '+${_euro(c.amountCents)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) =>
      name.substring(0, min(2, name.length)).toUpperCase();

  List<PieChartSectionData> _sections(double remaining) {
    final users = _pieUsers;
    final sums = _sumPerUser;
    final total = max(_goalAmount, _savedCents / 100);

    PieChartSectionData section(
      int i,
      double value,
      Color color,
      String? badge,
    ) {
      final touched = _touchedIndex == i;
      return PieChartSectionData(
        color: color,
        value: value,
        title: '${(total > 0 ? value / total * 100 : 0).toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        radius: touched ? 85 : 75,
        badgeWidget: badge == null
            ? null
            : _UserBadge(name: badge, size: touched ? 55 : 40, color: color),
        badgePositionPercentageOffset: 1.05,
      );
    }

    return [
      for (var i = 0; i < users.length; i++)
        section(
          i,
          (sums[users[i]] ?? 0) / 100,
          _colors[i % _colors.length],
          _nameOf(users[i]),
        ),
      if (remaining > 0)
        section(users.length, remaining, Colors.grey.shade400, null),
    ];
  }
}

/// Badge mit den Initialen eines Users am Rand des Kreisdiagramms.
class _UserBadge extends StatelessWidget {
  const _UserBadge({
    required this.name,
    required this.size,
    required this.color,
  });

  final String name;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: PieChart.defaultDuration,
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: color.withValues(alpha: 0.8), width: 2.5),
      boxShadow: const [
        BoxShadow(color: Colors.black12, offset: Offset(0, 3), blurRadius: 4),
      ],
    ),
    child: Center(
      child: Text(
        name.substring(0, min(2, name.length)).toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.35,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    ),
  );
}
