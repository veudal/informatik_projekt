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
    Navigator.push(context, MaterialPageRoute(builder: (context) => AddAccountInfoScreen(email: emailController.text, password: passwordController.text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back)
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min, // prevent column from taking up all available space
            children: [
              const Center(
                child: Text(
                  'Sign up',
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
                        hintText: "Enter your password"
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: isConfirmButtonEnabled() ? onPressConfirm : null,
                child: const Text('Confirm')
              ),
            ]
          )
        )
      ),
    );
  }
}









