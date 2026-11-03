import 'package:flutter/material.dart';
import 'add_account_info_screen.dart';

class RegisterAccountScreen extends StatefulWidget {
  const RegisterAccountScreen({super.key});

  @override
  State<RegisterAccountScreen> createState() => _RegisterAccountScreenState();
}

class _RegisterAccountScreenState extends State<RegisterAccountScreen> {
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
    return emailController.text.isNotEmpty && passwordController.text.isNotEmpty;
  }

  void onPressConfirm() async {
    setState(() {
      _isSubmitting = true;
    });

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
                      'Sign up',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: "Enter your email",
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text('Password'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          enabled: !_isSubmitting,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: "Enter your password",
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
                            child: CircularProgressIndicator(strokeWidth: 2)
                          )
                        : const Text('Confirm'),
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
