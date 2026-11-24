import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:informatik_projekt/services/api_service.dart';
import 'package:informatik_projekt/services/structs/invitation_response.dart';
import 'package:informatik_projekt/widgets/colored_button.dart';
import 'package:qr_flutter/qr_flutter.dart';

class InvitationScreen extends StatefulWidget {
  const InvitationScreen({super.key});

  @override
  State<StatefulWidget> createState() => _InvitationScreenState();
}

class _InvitationScreenState extends State<InvitationScreen> {
  static final double _modalDefaultCornerRadius = 20.0;
  final ApiService _apiService = ApiService();
  late Future<String> _invitationCode;
  bool _isPolling = false;

  @override
  void initState() {
    super.initState();
    _invitationCode = _apiService.createInvitation();
  }

  @override
  void dispose() {
    _isPolling = false;

    // notify server that client doesn't use this code anymore
    _invitationCode.then((id) {
      unawaited(_apiService.respondRedeemer(id, InvitationResponse.expire));
    });

    super.dispose();
  }

  void poll(String id) async {
    while (_isPolling && mounted) {
      String? redeemerName;

      try {
        redeemerName = await _apiService.pollJoinRequest(id);
      } on Exception catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Ein unerwarteter Fehler ist aufgetreten. Generiere einen neuen Einladungscode. Fehler: $e',
              ),
            ),
          );
        }

        break;
      }

      if (!_isPolling || !mounted) {
        break;
      }

      if (redeemerName != null) {
        // code was redeemed
        InvitationResponse response;

        try {
          response = (await _showRequestPopup(redeemerName)) ?? InvitationResponse.expire;

          await _apiService.respondRedeemer(id, response);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  response == InvitationResponse.accept
                      ? '$redeemerName wurde in die Familie aufgenommen.'
                      : '$redeemerName wurde abgelehnt.',
                ),
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
          setState(() {
            _invitationCode = Future.delayed(Duration(milliseconds: 500)).then((_) => _apiService.createInvitation());
          });
        }

        break;
      } else {
        await Future.delayed(Duration(milliseconds: 750));
      }
    }

    _isPolling = false;
  }

  Future<InvitationResponse?> _showRequestPopup(String displayName) async {
    return showModalBottomSheet<InvitationResponse>(
      context: context,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.all(_modalDefaultCornerRadius * 0.5),
          child: SizedBox(
            height: 300,
            child: Column(
              children: [
                Align(
                  alignment: AlignmentGeometry.centerRight,
                  child: CloseButton(
                    onPressed: () {
                      Navigator.maybePop(context, InvitationResponse.expire);
                    },
                  ),
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
                        Navigator.maybePop(context, InvitationResponse.deny);
                      },
                      child: const Text('Ablehnen'),
                    ),
                    ColoredButton(
                      color: Colors.green,
                      onPressed: () {
                        Navigator.maybePop(context, InvitationResponse.accept);
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
      appBar: AppBar(title: const Text('Familienmitglied einladen')),
      body: FutureBuilder(
        future: _invitationCode,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Ein Fehler ist aufgetreten. Der Einleidungs code konnte nicht erstellt werden.'),
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
                          await Clipboard.setData(ClipboardData(text: id));
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
                    'Reiche den Einladungs code weiter an das Familienmitglied dass du einladen möchtest.',
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
