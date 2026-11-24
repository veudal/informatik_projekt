import 'package:flutter/material.dart';
import 'package:informatik_projekt/services/api_service.dart';

import 'details_screen.dart';

class RegisterAccountScreen extends StatefulWidget {
  const RegisterAccountScreen({super.key});

  @override
  State<RegisterAccountScreen> createState() => _RegisterAccountScreenState();
}

class _RegisterAccountScreenState extends State<RegisterAccountScreen> {
  static final BorderRadius _radius = BorderRadius.circular(12);

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  String? _emailError;
  bool _emailTouched = false;
  final ApiService _apiService = ApiService();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    emailController.addListener(onInputChange);
    passwordController.addListener(onInputChange);
    confirmPasswordController.addListener(onInputChange);
  }

  @override
  void dispose() {
    emailController.removeListener(onInputChange);
    passwordController.removeListener(onInputChange);
    confirmPasswordController.removeListener(onInputChange);
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void onInputChange() {
    if (emailController.text.isNotEmpty) {
      _emailError = null;
    }
    setState(() {});
  }

  String? get _emailFieldError {
    if (_emailError != null) return _emailError;
    if (_emailTouched && emailController.text.isEmpty) {
      return 'Bitte gib deine E-Mail ein';
    }
    return null;
  }

  bool isConfirmButtonEnabled() {
    return emailController.text.isNotEmpty &&
        passwordController.text.isNotEmpty &&
        confirmPasswordController.text.isNotEmpty &&
        passwordController.text == confirmPasswordController.text;
  }

  bool get passwordsDoNotMatch {
    return confirmPasswordController.text.isNotEmpty &&
        passwordController.text != confirmPasswordController.text;
  }

  InputDecoration _decoration(String hint, {String? errorText}) {
    return InputDecoration(
      border: OutlineInputBorder(borderRadius: _radius),
      errorBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: _radius,
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      hintText: hint,
      errorText: errorText,
    );
  }

  void onPressConfirm() async {
    setState(() {
      _isSubmitting = true;
      _emailError = null;
    });

    try {
      bool isRegistered = await _apiService.isEmailRegistered(
        emailController.text,
      );
      if (isRegistered) {
        setState(() {
          _emailError = 'Diese E-Mail ist bereits registriert.';
          _isSubmitting = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            persist: false,
            duration: const Duration(seconds: 4),
            content: const Text(
              'Diese E-Mail ist bereits registriert. Bitte melde dich an.',
            ),
            action: SnackBarAction(
              label: 'Login',
              textColor: Colors.white,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        );
        return;
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ein Fehler bei der E-Mail-Überprüfung ist aufgetreten.',
          ),
          action: SnackBarAction(
            label: 'Zurück',
            textColor: Colors.white,
            onPressed: () => Navigator.pop(context),
          ),
        ),
      );
      return;
    }

    // Simulation of a brief delay to show loading state before navigating
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAccountInfoScreen(
          email: emailController.text,
          password: passwordController.text,
        ),
      ),
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        flexibleSpace: _isSubmitting
            ? const Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(minHeight: 5),
              )
            : null,
      ),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'Konto Erstellen',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 128),
                  SizedBox(
                    width: 320,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Email'),
                        const SizedBox(height: 8),
                        Focus(
                          onFocusChange: (hasFocus) {
                            if (!hasFocus) setState(() => _emailTouched = true);
                          },
                          child: TextField(
                            controller: emailController,
                            autofocus: true,
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_isSubmitting,
                            decoration: _decoration(
                              "Gib deine E-Mail ein",
                              errorText: _emailFieldError,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('Passwort'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          enabled: !_isSubmitting,
                          decoration: _decoration("Gib dein Passwort ein"),
                        ),
                        const SizedBox(height: 24),
                        const Text('Passwort bestätigen'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: true,
                          enabled: !_isSubmitting,
                          decoration: _decoration(
                            "Wiederhole dein Passwort",
                            errorText: passwordsDoNotMatch
                                ? 'Passwörter stimmen nicht überein'
                                : null,
                          ),
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
                      child: _isSubmitting
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            )
                          : const Text('Weiter'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
