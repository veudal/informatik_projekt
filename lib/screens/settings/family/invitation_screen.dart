import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:informatik_projekt/screens/settings/settings_screen.dart';
import 'package:informatik_projekt/services/api_service.dart';
import 'package:informatik_projekt/services/structs/join_request.dart';
import 'package:informatik_projekt/widgets/colored_button.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

class InvitationScreen extends StatefulWidget {
  const InvitationScreen({super.key});

  @override
  State<StatefulWidget> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends State<InvitationScreen> {
  final ApiService _apiService = ApiService();
  late final Future<String> _invitationCode;
  bool _isPolling = false;

  @override
  void initState() {
    super.initState();
    _invitationCode = _apiService.createInvitation();
  }

  @override
  void dispose() {
    _isPolling = false;
    super.dispose();
  }

  void poll(String id) async {
    while (_isPolling && mounted) {
      JoinRequest? joinRequest;

      try {
        joinRequest = await _apiService.pollJoinRequest(id);
      } on Exception catch (e) {
        _isPolling = false;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ein unerwarteter Fehler ist aufgetreten. Generiere um sicher zu gehen einen neuen Einladungscode. Fehler: $e',
              ),
            ),
          );
        }
      }

      if (!_isPolling || !mounted) break;

      if (joinRequest != null) {
        _isPolling = false;
        _onReceiveRequest(id, joinRequest.displayName, joinRequest.id);
      } else {
        await Future.delayed(Duration(milliseconds: 750));
      }
    }
  }

  void _onReceiveRequest(
    String invitationId,
    String displayName,
    UuidValue uuid,
  ) {
    if (!mounted) {
      return;
    }

    double defaultCornerRadius = 20.0;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(defaultCornerRadius * 0.5),
          child: SizedBox(
            height: 300,
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
                        text: displayName,
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
                        _onDecide(invitationId, false, displayName);
                      },
                      child: const Text('Ablehnen'),
                    ),
                    ColoredButton(
                      color: Colors.green,
                      onPressed: () {
                        _onDecide(invitationId, true, displayName);
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

  void _onDecide(String invitationId, bool accept, String displayName) async {
    try {
      await _apiService.respondRedeemer(invitationId, accept);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$displayName wurde in die Familie aufgenommen.'),
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ein unerwarteter Fehler ist aufgetreten. Möglicherweise konnte die eingeladene Person nicht in die Familie aufgenommen werden. Fehler: $e',
            ),
          ),
        );
      }
    }

    if (mounted) {
      // pop modal bottom sheet
      Navigator.maybePop(context);

      if (mounted) {
        // check if for some reason this screen was popped accidentally
        setState(() {
          _invitationCode = _apiService.createInvitation();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Familienmitglied einladen')),
      body: FutureBuilder(
        future: _invitationCode,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Ein unerwarteter Fehler ist aufgetreten.'),
            );
          } else if (snapshot.hasData) {
            String id = snapshot.data ?? '';

            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await Future.delayed(Duration(milliseconds: 1000));
              if (mounted) {
                _isPolling = true;
                poll(id);
              }
            });

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 24,
                children: [
                  QrImageView(
                    data: id,
                    version: QrVersions.auto,
                    size: 280,
                    backgroundColor: Colors.white,
                    errorStateBuilder: (context, error) => Text(
                      'Der QR code konnte nicht generiert werden :$error',
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 14,
                    children: [
                      SelectableText(
                        id,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24.0,
                        ),
                      ),
                      IconButton.filled(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: id),
                          );
                          // copied successfully
                        },
                        icon: const Icon(Icons.content_copy),
                        tooltip: 'In die Zwischenablage kopieren',
                        style: IconButton.styleFrom(
                          fixedSize: const Size(24, 24),
                          padding: EdgeInsets.all(0),
                          iconSize: 20,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Reiche den Einladungs code weiter an das Familienmitflied dass du einladen möchtest.',
                    textAlign: TextAlign.center,
                  ),
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
