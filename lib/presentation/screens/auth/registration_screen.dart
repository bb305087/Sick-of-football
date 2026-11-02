import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../data/datasources/api_client.dart';
import '../../../data/repositories/auth_repository.dart';

enum RegistrationRole { player, coach }

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authRepository = AuthRepository();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _clubNameController = TextEditingController();
  final _inviteTokenController = TextEditingController();

  RegistrationRole _role = RegistrationRole.player;
  bool _isLoading = false;
  bool _obscurePassword = true;

  bool get _isCoach => _role == RegistrationRole.coach;

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (_isCoach) {
        await _authRepository.registerCoach(
          email: _emailController.text.trim().toLowerCase(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          clubName: _clubNameController.text.trim(),
        );
      } else {
        await _authRepository.registerPlayer(
          email: _emailController.text.trim().toLowerCase(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          inviteToken: _inviteTokenController.text.trim(),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Konto utworzone. Możesz się teraz zalogować.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      _showError(error.message);
    } on http.ClientException {
      _showError('Nie można połączyć się z serwerem.');
    } on FormatException {
      _showError('Nie można odczytać odpowiedzi serwera.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) return 'Wprowadź $label';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty || !value.contains('@')) {
      return 'Wprowadź poprawny adres e-mail';
    }
    return null;
  }

  String? _validateInviteToken(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Wprowadź token zaproszenia';
    }
    if (value.trim().length < 20) {
      return 'Token zaproszenia musi mieć co najmniej 20 znaków';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.length < 12) {
      return 'Hasło musi mieć co najmniej 12 znaków';
    }
    return null;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    _clubNameController.dispose();
    _inviteTokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rejestracja')),
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.person_add_alt_1,
                      size: 56,
                      color: Colors.lightGreen,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Utwórz konto',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SegmentedButton<RegistrationRole>(
                      segments: const [
                        ButtonSegment(
                          value: RegistrationRole.player,
                          label: Text('Zawodnik'),
                          icon: Icon(Icons.sports_soccer),
                        ),
                        ButtonSegment(
                          value: RegistrationRole.coach,
                          label: Text('Trener'),
                          icon: Icon(Icons.sports),
                        ),
                      ],
                      selected: {_role},
                      onSelectionChanged: _isLoading
                          ? null
                          : (selection) =>
                                setState(() => _role = selection.first),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _fullNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Imię i nazwisko',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => _required(value, 'imię i nazwisko'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Adres E-mail',
                        prefixIcon: Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: 16),
                    if (_isCoach)
                      TextFormField(
                        controller: _clubNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nazwa klubu',
                          prefixIcon: Icon(Icons.shield),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) => _required(value, 'nazwę klubu'),
                      )
                    else
                      TextFormField(
                        controller: _inviteTokenController,
                        decoration: const InputDecoration(
                          labelText: 'Token zaproszenia',
                          prefixIcon: Icon(Icons.link),
                          border: OutlineInputBorder(),
                        ),
                        validator: _validateInviteToken,
                      ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Hasło',
                        prefixIcon: const Icon(Icons.lock),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmationController,
                      obscureText: _obscurePassword,
                      decoration: const InputDecoration(
                        labelText: 'Powtórz hasło',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value != _passwordController.text
                          ? 'Hasła muszą być takie same'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegistration,
                        child: _isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Zarejestruj się'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
