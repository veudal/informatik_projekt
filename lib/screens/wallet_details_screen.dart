import 'package:flutter/material.dart';

import '../models/transaction.dart';

import 'package:fl_chart/fl_chart.dart';

import '../services/api_service.dart';
import '../models/wallet.dart';

/// Externe Banken für simulierte Ein-/Auszahlungen.
const List<String> kExternalBanks = [
  'Sparkasse',
  'Volksbank',
  'Deutsche Bank',
  'Commerzbank',
  'ING',
  'DKB',
  'Postbank',
  'N26',
];

class WalletDetailsScreen extends StatefulWidget {
  final String walletId;
  final String? familyWalletId;
  final String accountName;
  final bool isFamilyWallet;
  final int? initialBalanceCents;

  final String? familyId;
  final String? familyName;

  /// User-ID -> Name, um Zielkonten als `Einzelkonto <Name>` anzuzeigen.
  final Map<String, String> memberNames;

  const WalletDetailsScreen({
    super.key,
    required this.walletId,
    required this.familyWalletId,
    required this.accountName,
    required this.isFamilyWallet,
    this.initialBalanceCents,
    this.familyId,
    this.familyName,
    this.memberNames = const {},
  });

  @override
  State<WalletDetailsScreen> createState() => _WalletDetailsScreenState();
}

class _WalletDetailsScreenState extends State<WalletDetailsScreen> {
  final ApiService _apiService = ApiService();
  late Future<Map<String, dynamic>> _walletData;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  void _loadWalletData() {
    setState(() {
      _walletData = _fetchData();
    });
  }

  /// Liefert Saldo und Transaktionen. Alle Beträge sind aus Sicht
  /// des angezeigten Kontos vorzeichenbehaftet (+ Zufluss, - Abfluss).
  Future<Map<String, dynamic>> _fetchData() async {
    if (widget.isFamilyWallet) {
      final results = await Future.wait([
        _apiService.getTransactionsByFamilyWallet(widget.walletId),
        _apiService.getExternalTransfers(widget.walletId),
      ]);

      // Überweisung eines Mitglieds ist dort negativ -> für das Familienkonto ein Zufluss
      final memberTransfers = results[0]
          .map(
            (tx) => Transaction(
              id: tx.id,
              amountCents: -tx.amountCents,
              kind: tx.kind,
              note: tx.note,
              createdAt: tx.createdAt,
            ),
          )
          .toList();
      final transactions = [...memberTransfers, ...results[1]]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final balance = transactions.fold<int>(
        0,
        (sum, tx) => sum + tx.amountCents,
      );
      return {'balance': balance, 'transactions': transactions};
    }

    // Für Einzelkonten:
    final balance = await _apiService.getWalletBalance(widget.walletId);
    final transactions = await _apiService.getTransactionsByWallet(
      widget.walletId,
    );

    transactions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return {'balance': balance, 'transactions': transactions};
  }

  List<FlSpot> _generateChartData(
    int currentBalance,
    List<Transaction> transactions,
  ) {
    if (transactions.isEmpty) return [FlSpot(0, currentBalance / 100)];

    final spots = <FlSpot>[];
    final totalSumChange = transactions.fold<int>(
      0,
      (sum, tx) => sum + tx.amountCents,
    );
    double runningBalance = (currentBalance - totalSumChange) / 100;

    spots.add(FlSpot(0, runningBalance));

    for (int i = 0; i < transactions.length; i++) {
      runningBalance += (transactions[i].amountCents / 100);
      spots.add(FlSpot((i + 1).toDouble(), runningBalance));
    }

    return spots;
  }

  String _kindLabel(Transaction tx) {
    switch (tx.kind) {
      case 'transfer':
      case 'member_transfer':
        return tx.amountCents >= 0 ? 'Überweisung erhalten' : 'Überweisung gesendet';
      case 'external_deposit':
        return 'Einzahlung';
      case 'external_withdrawal':
        return 'Auszahlung';
      default:
        return tx.kind.toUpperCase();
    }
  }

  int? _parseAmountCents(String input) {
    final euroAmount = double.tryParse(input.replaceAll(',', '.'));
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
  // Einzelkonto: Überweisung an Familienkonto oder an andere Einzelkonten
  // ---------------------------------------------------------------------------
  void _showTransferDialog() async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();

    List<WalletAccount> availableWallets = [];
    try {
      if (widget.familyId != null) {
        final results = await Future.wait([
          _apiService.getFamilyWalletsForFamily(widget.familyId!),
          _apiService.getWalletsForFamily(widget.familyId!),
        ]);
        availableWallets = [...results[0], ...results[1]];
        // Das eigene Konto entfernen, damit man nicht an sich selbst überweist
        availableWallets.removeWhere((w) => w.id == widget.walletId);
      }
    } catch (_) {}

    WalletAccount? selectedTargetWallet =
        availableWallets.isNotEmpty ? availableWallets.first : null;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return AlertDialog(
              title: const Text('Geld überweisen'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (availableWallets.isEmpty)
                      const Text('Keine Zielkonten in der Familie gefunden.')
                    else
                      DropdownButtonFormField<WalletAccount>(
                        initialValue: selectedTargetWallet,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Empfänger',
                          border: OutlineInputBorder(),
                        ),
                        items: availableWallets.map((wallet) {
                          return DropdownMenuItem(
                            value: wallet,
                            child: Row(
                              children: [
                                Icon(
                                  wallet.isFamily
                                      ? Icons.family_restroom
                                      : Icons.person,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    wallet.displayName(
                                      familyName: widget.familyName,
                                      memberNames: widget.memberNames,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setStateDialog(() => selectedTargetWallet = val);
                        },
                      ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Betrag in €',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Verwendungszweck / Notiz',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting || selectedTargetWallet == null
                      ? null
                      : () async {
                          final amountCents =
                              _parseAmountCents(amountController.text);
                          if (amountCents == null) {
                            _showSnack('Bitte einen gültigen Betrag eingeben',
                                error: true);
                            return;
                          }
                          final target = selectedTargetWallet!;
                          final note = noteController.text.isEmpty
                              ? 'Überweisung'
                              : noteController.text;

                          setStateDialog(() => isSubmitting = true);
                          try {
                            if (target.isFamily) {
                              // Einzelkonto -> Familienkonto
                              await _apiService.createTransaction(
                                widget.walletId,
                                target.id,
                                -amountCents,
                                'transfer',
                                note,
                              );
                            } else {
                              // Einzelkonto -> anderes Einzelkonto
                              await _apiService.createMemberTransfer(
                                widget.walletId,
                                target.id,
                                amountCents,
                                note,
                              );
                            }
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            _loadWalletData();
                            _showSnack('Überweisung erfolgreich ausgeführt!');
                          } catch (e) {
                            setStateDialog(() => isSubmitting = false);
                            _showSnack('Fehler: $e', error: true);
                          }
                        },
                  child: const Text('Ausführen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Familienkonto: simulierte Ein-/Auszahlung von/an externe Bank
  // ---------------------------------------------------------------------------
  void _showExternalTransferDialog() {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    final otherBankController = TextEditingController();
    bool isDeposit = true;
    String selectedBank = kExternalBanks.first;
    const otherBankValue = '__other__';

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isSubmitting = false;
        return StatefulBuilder(
          builder: (dialogContext, setStateDialog) {
            return AlertDialog(
              title: const Text('Ein- / Auszahlung (Simulation)'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('Einzahlen'),
                          icon: Icon(Icons.arrow_downward),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('Auszahlen'),
                          icon: Icon(Icons.arrow_upward),
                        ),
                      ],
                      selected: {isDeposit},
                      onSelectionChanged: (s) =>
                          setStateDialog(() => isDeposit = s.first),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: selectedBank,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: isDeposit ? 'Von Bank' : 'An Bank',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.account_balance),
                      ),
                      items: [
                        ...kExternalBanks.map(
                          (b) => DropdownMenuItem(value: b, child: Text(b)),
                        ),
                        const DropdownMenuItem(
                          value: otherBankValue,
                          child: Text('Andere Bank …'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() => selectedBank = val);
                        }
                      },
                    ),
                    if (selectedBank == otherBankValue) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: otherBankController,
                        decoration: const InputDecoration(
                          labelText: 'Name der Bank',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Betrag in €',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: 'Verwendungszweck / Notiz',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final amountCents =
                              _parseAmountCents(amountController.text);
                          if (amountCents == null) {
                            _showSnack('Bitte einen gültigen Betrag eingeben',
                                error: true);
                            return;
                          }
                          final bankName = selectedBank == otherBankValue
                              ? otherBankController.text.trim()
                              : selectedBank;
                          if (bankName.isEmpty) {
                            _showSnack('Bitte eine Bank angeben', error: true);
                            return;
                          }

                          setStateDialog(() => isSubmitting = true);
                          try {
                            await _apiService.createExternalTransfer(
                              widget.walletId,
                              isDeposit: isDeposit,
                              amountCents: amountCents,
                              bankName: bankName,
                              note: noteController.text.trim().isEmpty
                                  ? null
                                  : noteController.text.trim(),
                            );
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            _loadWalletData();
                            _showSnack(isDeposit
                                ? 'Einzahlung von $bankName gebucht'
                                : 'Auszahlung an $bankName gebucht');
                          } catch (e) {
                            setStateDialog(() => isSubmitting = false);
                            _showSnack('Fehler: $e', error: true);
                          }
                        },
                  child: const Text('Ausführen'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget? _buildFab() {
    if (widget.isFamilyWallet) {
      return FloatingActionButton.extended(
        onPressed: _showExternalTransferDialog,
        icon: const Icon(Icons.account_balance),
        label: const Text('Ein-/Auszahlen'),
      );
    }
    if (widget.familyId == null) return null;
    return FloatingActionButton.extended(
      onPressed: _showTransferDialog,
      icon: const Icon(Icons.send),
      label: const Text('Überweisen'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isFamilyWallet ? 'Familienkonto' : 'Einzelkonto'),
      ),
      floatingActionButton: _buildFab(),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _walletData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }

          final balance = snapshot.data!['balance'] as int;
          final transactions =
              snapshot.data!['transactions'] as List<Transaction>;
          final balanceEuro = (balance / 100).toStringAsFixed(2);
          final reversedTransactions = transactions.reversed.toList();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.accountName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Saldo = $balanceEuro €',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Verlauf:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(
                        show: true,
                        drawVerticalLine: false,
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 45,
                            getTitlesWidget: (value, meta) => Text(
                              '${value.toInt()}€',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index == 0 && transactions.isNotEmpty) {
                                return const Text(
                                  'Start',
                                  style: TextStyle(fontSize: 9),
                                );
                              }
                              if (index > 0 && index <= transactions.length) {
                                final tx = transactions[index - 1];
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text(
                                    '${tx.createdAt.day}.${tx.createdAt.month}.',
                                    style: const TextStyle(fontSize: 9),
                                  ),
                                );
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _generateChartData(balance, transactions),
                          isCurved: false,
                          color: Colors.indigo,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.indigo.withOpacity(0.15),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                const Text(
                  'Transaktionen:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: reversedTransactions.length,
                    itemBuilder: (context, index) {
                      final tx = reversedTransactions[index];
                      final amountEuro = (tx.amountCents / 100)
                          .toStringAsFixed(2);
                      final isPositive = tx.amountCents >= 0;
                      final isExternal = tx.kind.startsWith('external_');

                      final dateFormatted =
                          '${tx.createdAt.day}.${tx.createdAt.month}.${tx.createdAt.year} ${tx.createdAt.hour.toString().padLeft(2, '0')}:${tx.createdAt.minute.toString().padLeft(2, '0')}';

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isPositive
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            child: Icon(
                              isExternal
                                  ? Icons.account_balance
                                  : (isPositive
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward),
                              color: isPositive ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(
                            _kindLabel(tx),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(tx.note.isEmpty ? 'Keine Notiz' : tx.note),
                              const SizedBox(height: 2),
                              Text(
                                dateFormatted,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          trailing: Text(
                            '${isPositive ? '+' : ''}$amountEuro €',
                            style: TextStyle(
                              color: isPositive ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
