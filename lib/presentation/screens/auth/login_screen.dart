import 'package:flutter/material.dart';
import '../dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Klucz formularza do walidacji pól
  final _formKey = GlobalKey<FormState>();

  // Kontrolery do pobierania wpisanego tekstu
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Wybrana rola domyślna
  String _selectedRole = 'Zawodnik';

  bool _isLoading = false;
  bool _obscurePassword = true;

  // Zmień zawartość metody _handleLogin w pliku login_screen.dart

  // Zaktualizowana metoda _handleLogin w login_screen.dart

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;

      // Dane dostępowe dla Trenera
      const String coachEmail = 'admin';
      const String coachPassword = 'admin';

      String userRole = 'Zawodnik';

      // Jeśli podano e-mail trenera, weryfikujemy jego hasło
      if (email == coachEmail) {
        if (password != coachPassword) {
          _showErrorSnackBar('Nieprawidłowe hasło dla konta Trenera.');
          return;
        }
        userRole = 'Trener';
      }

      setState(() {
        _isLoading = true;
      });

      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        // Przejście do Dashboardu z automatycznie wyznaczoną rolą
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DashboardScreen(userRole: userRole),
          ),
        );
      });
    }
  }

// Pomocnicza metoda do wyświetlania komunikatów o błędzie
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Ikona / Logo aplikacji
                    const Icon(
                      Icons.sports_soccer,
                      size: 64,
                      color: Colors.lightGreen,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Sick of football',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Zarządzaj drużyną i frekwencją',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Pole E-mail
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Adres E-mail',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.email),
                      ),
                      validator: (value) {
                        // Pobieramy aktualnie wpisany e-mail z kontrolera
                        const String coachEmail = 'admin';

                        // Jeśli to konto trenera, pomijamy sprawdzanie poprawności maila
                        if (value == coachEmail) {
                          return null;
                        }
                        if (value == null || value.isEmpty || !value.contains('@')) {
                          cache:
                          return 'Wprowadź poprawny adres e-mail';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Pole Hasło
                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Hasło',
                        prefixIcon: Icon(Icons.lock),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Wprowadź hasło';
                        }

                        // Pobieramy aktualnie wpisany e-mail z kontrolera
                        final email = _emailController.text.trim().toLowerCase();
                        const String coachEmail = 'admin';

                        // Jeśli to konto trenera, pomijamy sprawdzanie długości (pozwalamy na krótkie hasło do testów)
                        if (email == coachEmail) {
                          return null;
                        }

                        // Standardowa walidacja długości dla pozostałych użytkowników
                        if (value.length < 8) {
                          return 'Hasło musi mieć co najmniej 8 znaków';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Przycisk logowania
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightGreen[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                          'Zaloguj się',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Opcjonalne wejście na biometrię / link zaproszeniowy
                    TextButton(
                      onPressed: () {
                        // Tutaj można dodać obsługę głębokiego linku (Deep Link) np. bklasa://invite/...
                      },
                      child: const Text(
                        'Masz link z zaproszeniem do szatni? Kliknij tutaj',
                        style: TextStyle(color: Colors.grey),
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