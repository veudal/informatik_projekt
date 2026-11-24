import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:informatik_projekt/screens/main_navigation.dart';
import 'package:informatik_projekt/services/api_service.dart';
import 'package:informatik_projekt/services/structs/invitation_status.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:informatik_projekt/screens/family/qr_scanner_screen.dart';

class JoinFamilyScreen extends StatefulWidget {
  const JoinFamilyScreen({super.key});

  @override
  State<StatefulWidget> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends State<JoinFamilyScreen> {
  static final RegExp _pattern = RegExp(r'[A-Za-z0-9]');
  final ApiService _apiService = ApiService();
  final PinInputController _controller = PinInputController();
  bool _canJoin = false;
  bool _showLoadingButton = false;
  bool _isPolling = true;

  Future<void> _openQrScanner(BuildContext context) async {
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      final String? inviteCode = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(builder: (_) => const QrScannerScreen()),
      );

      if (inviteCode != null) {
        setState(() {
          _controller.textController.text = inviteCode;
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Die Platform des Gerätes unterstützt keinen QR Scanner.',
          ),
        ),
      );
    }
  }

  void onInputChanged(String input) {
    setState(() {
      _canJoin = input.length == 6;
    });
  }

  void onPressJoin() async {
    setState(() {
      _showLoadingButton = true;
    });

    if (!mounted) return;

    String id = _controller.textController.text;

    try {
      await _apiService.redeem(id);
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ein unerwarteter Fehler ist aufgetreten. Der Einladungscode konnte nicht eingelöst werden. Fehler: $e',
            ),
          ),
        );

        setState(() {
          _showLoadingButton = false;
        });
      }

      return;
    }

    await Future.delayed(Duration(milliseconds: 500));

    if (mounted) {
      _isPolling = true;
      _poll(id);
    }
  }

  void _poll(String id) async {
    while (_isPolling && mounted) {
      late InvitationStatus status;

      try {
        status = await _apiService.pollStatus(id);
      } on Exception catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ein unerwarteter Fehler ist aufgetreten. Bitte ein Elternteil um einen neuen Einladungscode. Fehler: $e',
              ),
            ),
          );
        }

        break;
      }

      if (!_isPolling || !mounted) break;

      if (status == InvitationStatus.accepted) {
        _isPolling = false;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Anfrage angenommen')));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => MainNavigation()),
          (_) => false,
        );
      } else if (status == InvitationStatus.denied) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Anfrage abgelehnt')));

        break;
      } else if (status == InvitationStatus.pending) {
        await Future.delayed(Duration(milliseconds: 500));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Anfrage wurde entwertet.')));

        break;
      }
    }

    _isPolling = false;

    setState(() {
      _showLoadingButton = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _isPolling = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Familienmitglied einladen'),
        automaticallyImplyLeading: !_showLoadingButton,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Benutze den Einladungs code eines Elternteils',
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 64),
            Row(
              spacing: 20,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MaterialPinField(
                  length: 6,
                  keyboardType: TextInputType.text,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(_pattern),
                  ],
                  pinController: _controller,
                  onChanged: onInputChanged,
                  enabled: !_showLoadingButton,
                ),
                IconButton.filled(
                  onPressed: () => _openQrScanner(context),
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Per QR code ausfüllen',
                  style: IconButton.styleFrom(
                    fixedSize: const Size(56, 56),
                    padding: EdgeInsets.all(0),
                    iconSize: 42,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 48),
            ElevatedButton(
              onPressed: !_showLoadingButton && _canJoin ? onPressJoin : null,
              child: _showLoadingButton
                  ? CircularProgressIndicator()
                  : Text('Beitreten'),
            ),
          ],
        ),
      ),
    );
  }
}
