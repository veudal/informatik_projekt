import 'package:flutter/material.dart';

import '../../models/family.dart';
import '../../models/wallet.dart';
import '../../services/api_service.dart';
import '../calendar/calendar.dart';
import '../wallet_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  late Future<_HomeData> _homeData;
  bool _isCreatingFamilyWallet = false;

  @override
  void initState() {
    super.initState();
    _homeData = _loadHomeData();
  }

  Future<_HomeData> _loadHomeData() async {
    final family = await _apiService.getFamily();
    if (family == null) return const _HomeData(family: null, accounts: []);

    final wallets = await Future.wait([
      _apiService.getWalletsForFamily(family.id),
      _apiService.getFamilyWalletsForFamily(family.id),
    ]);
    final memberAccounts = await Future.wait(
      wallets.first.map((wallet) async {
        final balance = await _apiService.getWalletBalance(wallet.id);
        return _AccountData(wallet: wallet, balanceCents: balance);
      }),
    );
    final familyAccounts = wallets.last
        .map(
          (wallet) =>
              _AccountData(wallet: wallet, balanceCents: wallet.balanceCents),
        )
        .toList();

    return _HomeData(
      family: family,
      familyWalletId: familyAccounts.firstOrNull?.wallet.id,
      accounts: [...familyAccounts, ...memberAccounts],
    );
  }

  Future<void> _createFamilyWallet(Family family) async {
    setState(() {
      _isCreatingFamilyWallet = true;
    });
    try {
      await _apiService.createFamilyWallet(family.id, 'Familienkonto');
      if (!mounted) return;
      setState(() {
        _homeData = _loadHomeData();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Familienkonto konnte nicht erstellt werden: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingFamilyWallet = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HomeData>(
      future: _homeData,
      builder: (context, snapshot) {
        final familyName = snapshot.data?.family?.name ?? 'Konten';
        return Scaffold(
          appBar: AppBar(title: Text(familyName)),
          body: _buildBody(snapshot),
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<_HomeData> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Konten konnten nicht geladen werden: ${snapshot.error}'),
        ),
      );
    }

    final data = snapshot.data!;
    if (data.family == null) {
      return const Center(child: Text('Du bist keiner Familie zugeordnet.'));
    }
    // Accounts, optional family wallet setup, and the calendar as last item.
    final itemCount =
        data.accounts.length + (data.familyWalletId == null ? 1 : 0) + 1;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == itemCount - 1) {
          return Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Calendar(familyId: data.family!.id),
          );
        }
        if (index >= data.accounts.length) {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.family_restroom),
              title: const Text('Familienkonto einrichten'),
              subtitle: const Text(
                'Für diese Familie ist noch kein Familienkonto vorhanden.',
              ),
              trailing: _isCreatingFamilyWallet
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add),
              onTap: _isCreatingFamilyWallet
                  ? null
                  : () => _createFamilyWallet(data.family!),
            ),
          );
        }

        final account = data.accounts[index];
final isFamilyAccount = account.wallet.kind.toLowerCase() == 'family';

// Fallback: Wenn balanceCents null ist, setze es auf 0
final balanceCents = account.balanceCents ?? 0; 
final balance = (balanceCents / 100).toStringAsFixed(2).replaceAll('.', ',');

return Card(
  child: ListTile(
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 8,
    ),
    title: Text(account.wallet.name),
    trailing: Text('$balance €'), // Hier wird jetzt immer der Betrag mit € angezeigt
    onTap: () {
      Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => WalletDetailsScreen(
      walletId: account.wallet.id,
      familyWalletId: isFamilyAccount ? null : data.familyWalletId,
      accountName: account.wallet.name,
      isFamilyWallet: isFamilyAccount,
      initialBalanceCents: balanceCents,
      familyId: data.family?.id, // <-- Hier die familyId übergeben
    ),
  ),
);
            },
          ),
        );
      },
    );
  }
}

class _HomeData {
  const _HomeData({
    required this.family,
    required this.accounts,
    this.familyWalletId,
  });

  final Family? family;
  final String? familyWalletId;
  final List<_AccountData> accounts;
}

class _AccountData {
  const _AccountData({required this.wallet, required this.balanceCents});

  final WalletAccount wallet;
  final int? balanceCents;
}
