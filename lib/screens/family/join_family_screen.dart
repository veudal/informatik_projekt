import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:informatik_projekt/screens/family/qr_scanner_screen.dart';

class JoinFamilyScreen extends StatefulWidget {
  const JoinFamilyScreen({super.key});

  @override
  State<StatefulWidget> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends State<JoinFamilyScreen> {
  static final RegExp _pattern = RegExp(r'[A-Za-z0-9]');
  final PinInputController _controller = PinInputController();
  bool _canJoin = false;

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
          content: Text('Plattform is not supporting QR scanning.'),
        ),
      );
    }
  }

  void onChanged(String input) {
    setState(() {
      _canJoin = input.length == 6;
    });
  }

  void onPressJoin() {

  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Familienmitglied einladen')),
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
                  onChanged: onChanged,
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
              onPressed: _canJoin ? onPressJoin : null,
              child: Text('Beitreten'),
            ),
          ],
        ),
      ),
    );
  }
}
