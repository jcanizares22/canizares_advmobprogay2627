import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/auth_text_field.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _age = TextEditingController();
  final _contactNumber = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _hidePassword = true;
  bool _hideConfirmation = true;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _age.dispose();
    _contactNumber.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  String? _required(String? value, String label) {
    return value == null || value.trim().isEmpty ? '$label is required.' : null;
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final succeeded = await context.read<AuthProvider>().createAccount(
      email: _email.text.trim(),
      password: _password.text,
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      age: int.parse(_age.text.trim()),
      contactNumber: _contactNumber.text.trim(),
      username: _username.text.trim(),
    );
    if (!mounted) return;
    if (succeeded) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      final message = context.read<AuthProvider>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message ?? 'Unable to create account.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(
                'Your details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _firstName,
                label: 'First name',
                icon: Icons.person_outline,
                enabled: !auth.isLoading,
                validator: (value) => _required(value, 'First name'),
              ),
              const SizedBox(height: 12),
              AuthTextField(
                controller: _lastName,
                label: 'Last name',
                icon: Icons.person_outline,
                enabled: !auth.isLoading,
                validator: (value) => _required(value, 'Last name'),
              ),
              const SizedBox(height: 12),
              AuthTextField(
                controller: _age,
                label: 'Age',
                icon: Icons.cake_outlined,
                keyboardType: TextInputType.number,
                enabled: !auth.isLoading,
                validator: (value) {
                  final age = int.tryParse(value?.trim() ?? '');
                  if (age == null || age < 1 || age > 120) {
                    return 'Enter an age from 1 to 120.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              AuthTextField(
                controller: _contactNumber,
                label: 'Contact number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                enabled: !auth.isLoading,
                validator: (value) {
                  final contact = value?.trim() ?? '';
                  if (contact.isEmpty) {
                    return 'Contact number is required.';
                  }
                  if (!RegExp(r'^\+?[0-9 ()-]{7,20}$').hasMatch(contact)) {
                    return 'Enter a valid contact number.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              AuthTextField(
                controller: _username,
                label: 'Username',
                icon: Icons.alternate_email,
                enabled: !auth.isLoading,
                validator: (value) => _required(value, 'Username'),
              ),
              const SizedBox(height: 12),
              AuthTextField(
                controller: _email,
                label: 'Email address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                enabled: !auth.isLoading,
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Email is required.';
                  if (!_isValidEmail(email)) return 'Enter a valid email.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              AuthTextField(
                controller: _password,
                label: 'Password',
                icon: Icons.lock_outline,
                obscureText: _hidePassword,
                enabled: !auth.isLoading,
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Password is required.';
                  }
                  if (value.length < 8) {
                    return 'Use at least 8 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              AuthTextField(
                controller: _confirmPassword,
                label: 'Confirm password',
                icon: Icons.lock_reset_outlined,
                obscureText: _hideConfirmation,
                enabled: !auth.isLoading,
                suffixIcon: IconButton(
                  tooltip: _hideConfirmation
                      ? 'Show password'
                      : 'Hide password',
                  onPressed: () =>
                      setState(() => _hideConfirmation = !_hideConfirmation),
                  icon: Icon(
                    _hideConfirmation
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Confirm your password.';
                  }
                  if (value != _password.text) return 'Passwords do not match.';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: auth.isLoading ? null : _createAccount,
                child: auth.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
