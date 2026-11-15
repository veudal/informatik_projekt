import 'package:flutter/material.dart';

import '../../models/family.dart';
import '../../models/goal.dart';
import '../../services/api_service.dart';
import 'goal_details_screen.dart';

class SavingsScreen extends StatefulWidget {
  const SavingsScreen({super.key});

  @override
  State<SavingsScreen> createState() => _SavingsScreenState();
}

class _SavingsScreenState extends State<SavingsScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _error;
  Family? _family;
  List<Goal> _goals = [];

  /// User-ID -> Name der Familienmitglieder (für die Teilnehmerauswahl).
  Map<String, String> _memberNames = {};

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
      final family = await _apiService.getFamily();
      var goals = <Goal>[];
      var memberNames = <String, String>{};
      if (family != null) {
        final results = await Future.wait([
          _apiService.getGoalsForFamily(family.id),
          _apiService.getFamilyMemberNames(family.id),
        ]);
        goals = results[0] as List<Goal>;
        memberNames = results[1] as Map<String, String>;
        goals.sort((a, b) {
          final aDate = a.createdAt ?? DateTime(0);
          final bDate = b.createdAt ?? DateTime(0);
          return aDate.compareTo(bDate);
        });
      }
      if (!mounted) return;
      setState(() {
        _family = family;
        _goals = goals;
        _memberNames = memberNames;
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

  String _formatEuro(int cents) =>
      '${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.${date.year}';

  int? _parseAmountCents(String input) {
    final euroAmount = double.tryParse(input.trim().replaceAll(',', '.'));
    if (euroAmount == null || euroAmount <= 0) return null;
    return (euroAmount * 100).round();
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialog: neues Ziel anlegen
  // ---------------------------------------------------------------------------
  void _showAddGoalDialog() {
    final family = _family;
    if (family == null) return;

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    DateTime? deadline;
    final selectedParticipants = <String>{};

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            Future<void> pickDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: dialogContext,
                initialDate: deadline ?? now.add(const Duration(days: 30)),
                firstDate: DateTime(now.year, now.month, now.day),
                lastDate: DateTime(now.year + 20),
              );
              if (picked != null) setStateDialog(() => deadline = picked);
            }

            Future<void> submit() async {
              if (!formKey.currentState!.validate()) return;
              setStateDialog(() => isSubmitting = true);
              try {
                final goal = await _apiService.createGoal(
                  familyId: family.id,
                  name: nameController.text.trim(),
                  targetCents: _parseAmountCents(amountController.text)!,
                  deadline: deadline,
                  participantIds: selectedParticipants.toList(),
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (!mounted) return;
                // Neues Ziel direkt in der Liste anzeigen
                setState(() => _goals = [..._goals, goal]);
                _showSnack('Ziel „${goal.name}“ erstellt');
              } catch (e) {
                setStateDialog(() => isSubmitting = false);
                _showSnack('Fehler: $e', error: true);
              }
            }

            return AlertDialog(
              title: const Text('Neues Ziel'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name des Ziels',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.flag_outlined),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Bitte einen Namen eingeben'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Betrag in €',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.euro),
                        ),
                        validator: (value) =>
                            _parseAmountCents(value ?? '') == null
                                ? 'Bitte einen gültigen Betrag eingeben'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: pickDate,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          deadline == null
                              ? 'Datum wählen'
                              : 'Bis ${_formatDate(deadline!)}',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Familienteilnehmer',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      if (_memberNames.isEmpty)
                        const Text('Keine Familienmitglieder gefunden.')
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _memberNames.entries.map((member) {
                            final selected =
                                selectedParticipants.contains(member.key);
                            return FilterChip(
                              label: Text(
                                member.value.isEmpty ? 'Unbenannt' : member.value,
                              ),
                              selected: selected,
                              onSelected: (value) => setStateDialog(() {
                                if (value) {
                                  selectedParticipants.add(member.key);
                                } else {
                                  selectedParticipants.remove(member.key);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : submit,
                  child: isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Erstellen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openGoal(Goal goal) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => GoalDetailsScreen(goal: goal)),
    ).then((_) {
      if (mounted) _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ziele')),
      floatingActionButton: _family == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _showAddGoalDialog,
              icon: const Icon(Icons.add),
              label: const Text('Hinzufügen'),
            ),
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
          child: Text('Ziele konnten nicht geladen werden: $_error'),
        ),
      );
    }
    if (_family == null) {
      return const Center(child: Text('Du bist keiner Familie zugeordnet.'));
    }
    if (_goals.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('Noch keine Ziele. Leg dein erstes Ziel an!')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        // Platz unten, damit der Button die letzte Karte nicht verdeckt
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: _goals.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _buildGoalCard(_goals[index]),
      ),
    );
  }

  Widget _buildGoalCard(Goal goal) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openGoal(goal),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      goal.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: goal.progress,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_formatEuro(goal.currentCents)} von '
                '${_formatEuro(goal.targetCents)} erreicht',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
