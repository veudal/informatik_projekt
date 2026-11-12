import 'dart:async';

import 'package:flutter/material.dart';
import 'package:informatik_projekt/services/api_service.dart';
import 'package:informatik_projekt/widgets/colored_button.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

class InvitationScreen extends StatefulWidget {
  const InvitationScreen({super.key});

  @override
  State<StatefulWidget> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends State<InvitationScreen> {
  static final int _pollDelay = 500;
  final ApiService _apiService = ApiService();
  late final Future<String> _invitationCode;
  bool _pollRequests = false;

  @override
  void initState() {
    super.initState();
    _invitationCode = _apiService.requestFamilyInviteCode();
  }

  void _pollJoinRequests() async {
    while (_pollRequests) {
      // TODO

      await Future<void>.delayed(Duration(milliseconds: _pollDelay));
    }
  }

  @override
  void dispose() {
    _pollRequests = false;
    super.dispose();
  }

  void _onReceiveRequest(String name, UuidValue uuid) {
    if (!mounted) return;

    double defaultCornerRadius = 20.0;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(defaultCornerRadius * 0.5),
          child: SizedBox(
            height: 200,
            child: Column(
              children: [
                Align(
                  alignment: AlignmentGeometry.centerRight,
                  child: CloseButton(),
                ),
                SizedBox(height: 16),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: name,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: ' möchte deiner Familie beitreten!'),
                    ],
                  ),
                ),
                SizedBox(height: 32),
                Row(
                  spacing: 48,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ColoredButton(
                      color: Colors.red,
                      onPressed: () {
                        // TODO
                      },
                      child: const Text('Ablehnen'),
                    ),
                    ColoredButton(
                      color: Colors.green,
                      onPressed: () {
                        // TODO
                      },
                      child: const Text('Annehmen'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Familienmitglied einladen'),
      ),
      body: FutureBuilder(
        future: _invitationCode,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Ein unerwarteter Fehler ist aufgetreten.'),
            );
          } else if (snapshot.hasData) {
            Future.delayed(Duration(milliseconds: _pollDelay), () {
              _pollRequests = true;
              _pollJoinRequests();
            });

            String code = snapshot.data ?? '';

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 32,
                children: [
                  QrImageView(
                    data: code,
                    version: QrVersions.auto,
                    size: 280,
                    backgroundColor: Colors.white,
                    errorStateBuilder: (context, error) => Text(
                      'Der QR code konnte nicht generiert werden :$error',
                    ),
                  ),
                  const Text('Scanne den QR code auf dem Gerät des Familienmitglieds das du einladen möchtest', textAlign: TextAlign.center),
                ],
              ),
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
