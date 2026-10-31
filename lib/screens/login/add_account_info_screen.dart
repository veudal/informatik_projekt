import 'package:flutter/material.dart';
import 'package:birth_picker/birth_picker.dart';

class AddAccountInfoScreen extends StatefulWidget {
  const AddAccountInfoScreen({super.key, required this.email, required this.password});

  final String email;
  final String password;

  @override
  State<StatefulWidget> createState() => _AddAccountInfoScreenState(email, password);
}

class _AddAccountInfoScreenState extends State<AddAccountInfoScreen> {
  final TextEditingController displayNameController = TextEditingController();
  final String email;
  final String password;
  DateTime? birthDate;
  
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

  void onPressConfirm() {

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
                  'Add details',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
                )
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 320,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // align widgets to left side of column
                  children: [
                    const SizedBox(height: 24),
                    const Text('Email'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(text: email),
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Enter your email"
                      ),
                      enabled: false
                    ),
                    const SizedBox(height: 24),
                    const Text('Password'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(text: password),
                      obscureText: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Enter your password"
                      ),
                      enabled: false
                    ),
                    const SizedBox(height: 24),
                    const Text('Display name'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: displayNameController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: "Enter your display name"
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Birthdate'),
                    const SizedBox(height: 8),
                    BirthPicker(
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
