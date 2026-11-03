import 'package:flutter/material.dart';
import 'package:informatik_projekt/services/api_service.dart';

import 'details_screen.dart';

class RegisterAccountScreen extends StatefulWidget {
  const RegisterAccountScreen({super.key});

  @override
  State<RegisterAccountScreen> createState() => _RegisterAccountScreenState();
}

class _RegisterAccountScreenState extends State<RegisterAccountScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  String? _emailError;
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
      setState(() {
        _emailError = null;
      });
    }
    setState(() {});
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
          _emailError =
              'Diese E-Mail ist bereits registriert.';
          _isSubmitting = false;
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('${_emailError!}. Bitte melden Sie sich an.'),
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
      ),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'Konto Erstellen',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: 320,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Email'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_isSubmitting,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            hintText: "Gib deine E-Mail ein",
                            errorText: _emailError,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('Passwort'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          enabled: !_isSubmitting,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: "Gib dein Passwort ein",
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('Passwort bestätigen'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: true,
                          enabled: !_isSubmitting,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: "Wiederhole dein Passwort",
                          ),
                        ),
                        if (passwordsDoNotMatch)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Passwörter stimmen nicht überein',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: (isConfirmButtonEnabled() && !_isSubmitting)
                        ? onPressConfirm
                        : null,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Weiter ->'),
                  ),
                ],
              ),
            ),
          ),
          if (_isSubmitting)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 3),
            ),
        ],
      ),
    );
  }
}
