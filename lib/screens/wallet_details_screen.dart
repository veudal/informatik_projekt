import 'package:flutter/material.dart';

import '../models/transaction.dart';

import 'package:fl_chart/fl_chart.dart';

import '../services/api_service.dart';
import '../models/wallet.dart';

class WalletDetailsScreen extends StatefulWidget {
  final String walletId;
  final String? familyWalletId;
  final String accountName;
  final bool isFamilyWallet;
  final int? initialBalanceCents;

  final String? familyId;

const WalletDetailsScreen({
  super.key,
  required this.walletId,
  required this.familyWalletId,
  required this.accountName,
  required this.isFamilyWallet,
  this.initialBalanceCents,
  this.familyId, // <-- Im Konstruktor aufnehmen
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

  Future<Map<String, dynamic>> _fetchData() async {
    if (widget.isFamilyWallet) {
      // Transaktionen für das Familienkonto laden
      final transactions = await _apiService.getTransactionsByFamilyWallet(
        widget.walletId,
      );
      transactions.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Kontostand dynamisch aus den Transaktionen berechnen!
      // Da eine User-Überweisung negativ ist (-32€), ist es für das Familienkonto ein Zufluss (+32€).
      int calculatedBalanceCents = 0;
      for (var tx in transactions) {
        calculatedBalanceCents += (-tx.amountCents);
      }

      return {'balance': calculatedBalanceCents, 'transactions': transactions};
    }

    // Für persönliche Konten:
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
    // Für das Familienkonto müssen wir die Beträge für den Graphen invertieren (+/-),
    // da eine Abbuchung des Users dort als Einzahlung (+ Guthaben) verbucht wird.
    final adjustedTransactions = widget.isFamilyWallet
        ? transactions.map((tx) => Transaction(
            id: tx.id,
            amountCents: -tx.amountCents,
            kind: tx.kind,
            note: tx.note,
            createdAt: tx.createdAt,
          )).toList()
        : transactions;

    if (adjustedTransactions.isEmpty) return [FlSpot(0, currentBalance / 100)];

    List<FlSpot> spots = [];
    int totalSumChange = adjustedTransactions.fold(
      0,
      (sum, tx) => sum + tx.amountCents,
    );
    double runningBalance = (currentBalance - totalSumChange) / 100;

    spots.add(FlSpot(0, runningBalance));

    for (int i = 0; i < adjustedTransactions.length; i++) {
      runningBalance += (adjustedTransactions[i].amountCents / 100);
      spots.add(FlSpot((i + 1).toDouble(), runningBalance));
    }

    return spots;
  }

  // Dialog für Überweisung / Transaktion öffnen
  void _showTransferDialog() async {
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  bool isWithdrawal = true; // true = Senden, false = Anfordern
  
  // Verfügbare Zielkonten laden
  List<WalletAccount> availableWallets = [];
  try {
    if (widget.familyId != null) {
      final memberWallets = await _apiService.getWalletsForFamily(widget.familyId!);
      final familyWallets = await _apiService.getFamilyWalletsForFamily(widget.familyId!);
      availableWallets = [...familyWallets, ...memberWallets];
      // Das eigene Konto aus der Auswahlliste entfernen, damit man nicht an sich selbst überweist
      availableWallets.removeWhere((w) => w.id == widget.walletId);
    }
  } catch (_) {}

  WalletAccount? selectedTargetWallet = availableWallets.isNotEmpty ? availableWallets.first : null;

  if (!mounted) return;

  showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Geld überweisen'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Dropdown für Zielkonto-Auswahl
                if (availableWallets.isNotEmpty)
                  DropdownButtonFormField<WalletAccount>(
                    value: selectedTargetWallet,
                    decoration: const InputDecoration(
                      labelText: 'Zielkonto',
                      border: OutlineInputBorder(),
                    ),
                    items: availableWallets.map((wallet) {
  return DropdownMenuItem(
    value: wallet,
    child: Text(wallet.name),
  );
}).toList(), // <-- WICHTIG: Hier müssen Klammern hin!
                    onChanged: (val) {
                      setStateDialog(() {
                        selectedTargetWallet = val;
                      });
                    },
                  ),
                if (availableWallets.isNotEmpty) const SizedBox(height: 16),
                
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Abbrechen'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final double? euroAmount = double.tryParse(
                    amountController.text.replaceAll(',', '.'),
                  );
                  if (euroAmount == null || euroAmount <= 0) return;

                  int amountCents = (euroAmount * 100).round();
                  if (isWithdrawal) {
                    amountCents = -amountCents; // Abzug beim Sender
                  }

                  // Wir nutzen die ID des ausgewählten Zielkontos oder das Standard-Familienkonto als Fallback
                  final targetFamilyWalletId = selectedTargetWallet?.id ?? widget.familyWalletId;
                  if (targetFamilyWalletId == null) return;

                  try {
                    await _apiService.createTransaction(
                      widget.walletId,
                      targetFamilyWalletId,
                      amountCents,
                      'transfer',
                      noteController.text.isEmpty ? 'Überweisung' : noteController.text,
                    );

                    if (mounted) {
                      Navigator.pop(context);
                      _loadWalletData(); // UI aktualisieren
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Überweisung erfolgreich ausgeführt!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Fehler: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isFamilyWallet ? 'Familienkonto' : 'Persönliches Konto',
        ),
      ),
      floatingActionButton:
          widget.isFamilyWallet || widget.familyWalletId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _showTransferDialog,
              icon: const Icon(Icons.send),
              label: const Text('Überweisen'),
            ),
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
                              if (index == 0 && transactions.isNotEmpty)
                                return const Text(
                                  'Start',
                                  style: TextStyle(fontSize: 9),
                                );
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
                    itemCount: reversedTransactions.length,
                    itemBuilder: (context, index) {
                      final tx = reversedTransactions[index];
                      
                      // HIER: Vorzeichen für das Familienkonto umkehren
                      final displayAmountCents = widget.isFamilyWallet ? -tx.amountCents : tx.amountCents;
                      final amountEuro = (displayAmountCents / 100).toStringAsFixed(2);
                      final isPositive = displayAmountCents >= 0;
                      
                      final dateFormatted =
                          '${tx.createdAt.day}.${tx.createdAt.month}.${tx.createdAt.year} ${tx.createdAt.hour.toString().padLeft(2, '0')}:${tx.createdAt.minute.toString().padLeft(2, '0')}';

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          // HIER KOMMT DER CODE HIN:
                          leading: CircleAvatar(
                            backgroundColor: isPositive
                                ? Colors.green.shade100
                                : Colors.red.shade100,
                            child: Icon(
                              isPositive
                                  ? Icons.arrow_downward
                                  : Icons.arrow_upward,
                              color: isPositive ? Colors.green : Colors.red,
                            ),
                          ),
                          title: Text(
                            tx.kind.toUpperCase(),
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
                          // UND HIER DER ZWEITE TEIL:
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
