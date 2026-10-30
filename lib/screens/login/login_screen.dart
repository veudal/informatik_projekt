import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    emailController.addListener(onInputChange);
    passwordController.addListener(onInputChange);
  }

  @override
  void dispose() {
    super.dispose();
    emailController.removeListener(onInputChange);
    passwordController.removeListener(onInputChange);
    emailController.dispose();
    passwordController.dispose();
  }

  void onInputChange() {
    // trigger ui rebuild
    setState(() {});
  }

  void onPressConfirm() {
  }

  bool isConfirmButtonEnabled() {
    if (emailController.text.isNotEmpty && passwordController.text.isNotEmpty) {
      return true;
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min, // prevent column from taking up all available space
            children: [
              const Center(
                child: Text(
                  'Sign in',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                )
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 320,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // align widgets to left side of column
                  children: [
                    const Text('Email'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Enter your email"
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Password'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Enter your email"
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: isConfirmButtonEnabled() ? onPressConfirm : null, // null will display the widget as disabled
                child: const Text('Confirm')
              ),
              const SizedBox(height: 32)
            ]
          )
        )
      ),
    );
  }
}

