import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:informatik_projekt/screens/login/create_account_screen.dart';

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
    emailController.removeListener(onInputChange);
    passwordController.removeListener(onInputChange);
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void onInputChange() {
    // trigger ui rebuild
    setState(() {});
  }

  bool isConfirmButtonEnabled() {
    if (emailController.text.isNotEmpty && passwordController.text.isNotEmpty) {
      return true;
    }
    
    return false;
  }

  void onPressConfirm() {
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
              const SizedBox(height: 24),
              RichText(
                text: TextSpan(
                  text: 'Create Account',
                  style: TextStyle(color: Colors.blue),
                  recognizer: TapGestureRecognizer()..onTap = () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterAccountScreen()));
                  }
                ),
              )
            ]
          )
        )
      ),
    );
  }
}

