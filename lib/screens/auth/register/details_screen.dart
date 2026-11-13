import 'package:flutter/material.dart';
import 'package:birth_picker/birth_picker.dart';
import 'package:informatik_projekt/services/api_service.dart';
import 'package:informatik_projekt/screens/splash_screen.dart';

class AddAccountInfoScreen extends StatefulWidget {
  const AddAccountInfoScreen({
    super.key,
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  @override
  State<StatefulWidget> createState() =>
      _AddAccountInfoScreenState(email, password);
}

class _AddAccountInfoScreenState extends State<AddAccountInfoScreen> {
  final TextEditingController displayNameController = TextEditingController();
  final String email;
  final String password;
  DateTime? birthDate;
  bool _isSubmitting = false;
  final ApiService _apiService = ApiService();

  _AddAccountInfoScreenState(this.email, this.password);

  @override
  void initState() {
    super.initState();
    displayNameController.addListener(onInputChange);
  }

  @override
  void dispose() {
    displayNameController.removeListener(onInputChange);
    displayNameController.dispose();
    super.dispose();
  }

  void onInputChange() {
    setState(() {});
  }

  bool isConfirmButtonEnabled() {
    if (displayNameController.text.isNotEmpty && birthDate != null) {
      return true;
    }

    return false;
  }

  void onPressConfirm() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _apiService.register(
        email,
        password,
        displayNameController.text,
        birthDate!,
      );

      if (!result['success']) {
        if (!mounted) return;
        String errorMessage = 'Registrierung fehlgeschlagen. Bitte versuchen Sie es erneut.';
        if (result['statusCode'] == 409) {
          errorMessage = 'Diese E-Mail ist bereits registriert. Bitte melden Sie sich an.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFD32F2F),
            content: Text(
              errorMessage,
              style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 18),
            ),
          ),
        );
        return;
      }

      // Automatically login to get the token
      bool loginSuccess = await _apiService.login(email, password);

      if (!loginSuccess) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFD32F2F),
            content: Text(
              'Konto erstellt, aber Anmeldung fehlgeschlagen.',
              style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 18),
            ),
          ),
        );
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SplashScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ein Fehler ist aufgetreten: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize
                .min, // prevent column from taking up all available space
            children: [
              const Center(
                child: Text(
                  'Details hinzufügen',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 320,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment
                      .start, // align widgets to left side of column
                  children: [
                    const SizedBox(height: 24),
                    const Text('E-Mail'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(text: email),
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Gib deine E-Mail ein",
                      ),
                      enabled: false,
                    ),
                    const SizedBox(height: 24),
                    const Text('Passwort'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(text: password),
                      obscureText: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Gib dein Passwort ein",
                      ),
                      enabled: false,
                    ),
                    const SizedBox(height: 24),
                    const Text('Anzeigename'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: displayNameController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Gib deinen Anzeigenamen ein",
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Geburtsdatum'),
                    const SizedBox(height: 8),
                    BirthPicker(
                      locale: 'de_DE',
                      decorationBuilder: (bool isFocused) {
                        return BoxDecoration(
                          border: Border.all(
                            color: isFocused ? Colors.blue : Colors.grey,
                            width: isFocused ? 2.0 : 1.0,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        );
                      },
                      onChanged: (DateTime? dateTime) {
                        birthDate = dateTime;
                        onInputChange();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
               onPressed: (isConfirmButtonEnabled() && !_isSubmitting) ? onPressConfirm : null,
                child: const Text('Bestätigen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
