import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:informatik_projekt/screens/family/families_screen.dart';
import 'package:informatik_projekt/screens/auth/register/credentials_register.dart';
import 'package:informatik_projekt/screens/splash_screen.dart';
import 'package:informatik_projekt/services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    emailController.addListener(onInputChange);
    passwordController.addListener(onInputChange);
  }

  @override
  void dispose() {
    emailController.removeListener(onInputChange);
    passwordController.removeListener(onInputChange);
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void onInputChange() {
    setState(() {});
  }

  bool isConfirmButtonEnabled() {
    return emailController.text.isNotEmpty &&
        passwordController.text.isNotEmpty;
  }

  void onPressConfirm() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      bool success = await _apiService.login(
        emailController.text,
        passwordController.text,
      );
      if (!success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFD32F2F),
            content: Text(
              'Falsche E-Mail oder falsches Passwort',
              style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 20),
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
                      'Anmelden',
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
                        const Text('E-Mail'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_isSubmitting,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: "Gib deine E-Mail ein",
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('Passwordt'),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),
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
                        : const Text('Weiter'),
                  ),
                  const SizedBox(height: 64),
                  RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(text: 'Kein Konto?  ', style: TextStyle(color: Colors.black)),
                        TextSpan(
                          text: 'Erstelle eins!',
                          style: TextStyle(color: Colors.blue),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const RegisterAccountScreen(),
                                ),
                              );
                            },
                        ),
                      ],
                    ),
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
