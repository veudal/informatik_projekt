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
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final FocusNode lastNameFocusNode = FocusNode();
  final FocusNode displayNameFocusNode = FocusNode();
  final String email;
  final String password;
  DateTime? birthDate;
  bool _isSubmitting = false;
  final ApiService _apiService = ApiService();

  static final BorderRadius _radius = BorderRadius.circular(12);

  _AddAccountInfoScreenState(this.email, this.password);

  @override
  void initState() {
    super.initState();
    displayNameController.addListener(onInputChange);
    firstNameController.addListener(onInputChange);
    lastNameController.addListener(onInputChange);
  }

  @override
  void dispose() {
    displayNameController.removeListener(onInputChange);
    firstNameController.removeListener(onInputChange);
    lastNameController.removeListener(onInputChange);
    displayNameController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    lastNameFocusNode.dispose();
    displayNameFocusNode.dispose();
    super.dispose();
  }

  void focusLastNameField([String? _]) {
    FocusScope.of(context).requestFocus(lastNameFocusNode);
  }

  void focusDisplayNameField([String? _]) {
    FocusScope.of(context).requestFocus(displayNameFocusNode);
  }

  void onDisplayNameSubmitted([String? _]) {
    FocusScope.of(context).unfocus();
    if (isConfirmButtonEnabled() && !_isSubmitting) {
      onPressConfirm();
    }
  }

  void onInputChange() {
    setState(() {});
  }

  bool isConfirmButtonEnabled() {
    if (displayNameController.text.isNotEmpty &&
        firstNameController.text.isNotEmpty &&
        lastNameController.text.isNotEmpty &&
        birthDate != null) {
      return true;
    }

    return false;
  }

  double get _progress {
    final done = [
      firstNameController.text.isNotEmpty,
      lastNameController.text.isNotEmpty,
      displayNameController.text.isNotEmpty,
      birthDate != null,
    ].where((e) => e).length;
    return done / 6 + 1 / 3;
  }

  InputDecoration _decoration(String hint) {
    return InputDecoration(
      border: OutlineInputBorder(borderRadius: _radius),
      hintText: hint,
    );
  }

  void onPressConfirm() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _apiService.register(
        email,
        password,
        firstNameController.text,
        lastNameController.text,
        displayNameController.text,
        birthDate!,
      );

      if (!result['success']) {
        if (!mounted) return;
        String errorMessage =
            'Registrierung fehlgeschlagen. Bitte versuche es erneut.';
        if (result['statusCode'] == 409) {
          errorMessage =
              'Diese E-Mail ist bereits registriert. Bitte melden dich an.';
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ein Fehler ist aufgetreten: $e')));
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
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        flexibleSpace: PreferredSize(
          preferredSize: const Size.fromHeight(5),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _progress),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            builder: (context, value, _) => LinearProgressIndicator(
              // null = indefinite animation while registering
              value: _isSubmitting ? null : value,
              minHeight: 5,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
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
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
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
                      decoration: _decoration("Gib deine E-Mail ein"),
                      enabled: false,
                    ),
                    const SizedBox(height: 24),
                    const Text('Passwort'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(text: password),
                      obscureText: true,
                      decoration: _decoration("Gib dein Passwort ein"),
                      enabled: false,
                    ),
                    const SizedBox(height: 24),
                    const Text('Vorname'),
                    const SizedBox(height: 8),
                    TextField(
                      autofocus: true,
                      controller: firstNameController,
                      textInputAction: TextInputAction.next,
                      onSubmitted: focusLastNameField,
                      decoration: _decoration("Gib deinen Vornamen ein"),
                    ),
                    const SizedBox(height: 24),
                    const Text('Nachname'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: lastNameController,
                      focusNode: lastNameFocusNode,
                      textInputAction: TextInputAction.next,
                      onSubmitted: focusDisplayNameField,
                      decoration: _decoration("Gib deinen Nachnamen ein"),
                    ),
                    const SizedBox(height: 24),
                    const Text('Anzeigename'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: displayNameController,
                      focusNode: displayNameFocusNode,
                      textInputAction: TextInputAction.done,
                      onSubmitted: onDisplayNameSubmitted,
                      decoration: _decoration("Gib deinen Anzeigenamen ein"),
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
                          borderRadius: _radius,
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
              const SizedBox(height: 64),
              SizedBox(
                width: 320,
                child: FilledButton(
                  onPressed: (isConfirmButtonEnabled() && !_isSubmitting)
                      ? onPressConfirm
                      : null,
                  child: const Text('Bestätigen'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
