import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../data/datasources/api_client.dart';
import '../../../data/repositories/auth_repository.dart';

class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({super.key});

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  final AuthRepository _authRepository = AuthRepository();
  final _nationalityController = TextEditingController();
  final _positionController = TextEditingController();
  DateTime? _dateOfBirth;
  String? _preferredFoot;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = await _authRepository.fetchCurrentUser();
      if (!mounted) return;
      _nationalityController.text = user.nationality ?? '';
      _positionController.text = user.position ?? '';
      setState(() {
        _dateOfBirth = user.dateOfBirth;
        _preferredFoot = user.preferredFoot;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      _showMessage(error.message, isError: true);
    } on http.ClientException {
      _showMessage('Nie można połączyć się z serwerem.', isError: true);
    } on FormatException {
      _showMessage('Serwer zwrócił nieprawidłowe dane.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateOfBirth() async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialDate: _dateOfBirth ?? DateTime(2000),
    );
    if (selected != null && mounted) {
      setState(() => _dateOfBirth = selected);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final user = await _authRepository.updateProfile(
        nationality: _optionalValue(_nationalityController.text),
        dateOfBirth: _dateOfBirth,
        position: _optionalValue(_positionController.text),
        preferredFoot: _preferredFoot,
      );
      if (!mounted) return;
      _showMessage('Dane profilu zostały zapisane.');
      Navigator.of(context).pop(user);
    } on ApiException catch (error) {
      _showMessage(error.message, isError: true);
    } on http.ClientException {
      _showMessage('Nie można połączyć się z serwerem.', isError: true);
    } on FormatException {
      _showMessage('Serwer zwrócił nieprawidłowe dane.', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _optionalValue(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.${date.year}';

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[700] : null,
      ),
    );
  }

  @override
  void dispose() {
    _nationalityController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dane osobowe')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Uzupełnij profil',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Wszystkie pola są opcjonalne. Możesz je zostawić puste.',
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nationalityController,
                  decoration: const InputDecoration(
                    labelText: 'Narodowość',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.public),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data urodzenia'),
                  subtitle: Text(
                    _dateOfBirth == null
                        ? 'Nie podano'
                        : _formatDate(_dateOfBirth!),
                  ),
                  leading: const Icon(Icons.cake_outlined),
                  trailing: _dateOfBirth == null
                      ? null
                      : IconButton(
                          tooltip: 'Wyczyść',
                          onPressed: () => setState(() => _dateOfBirth = null),
                          icon: const Icon(Icons.clear),
                        ),
                  onTap: _selectDateOfBirth,
                ),
                const Divider(),
                const SizedBox(height: 16),
                TextField(
                  controller: _positionController,
                  decoration: const InputDecoration(
                    labelText: 'Pozycja na boisku',
                    hintText: 'np. napastnik, obrońca',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.sports_soccer),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _preferredFoot,
                  decoration: const InputDecoration(
                    labelText: 'Preferowana noga',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.directions_run),
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Nie podano')),
                    DropdownMenuItem(value: 'left', child: Text('Lewa')),
                    DropdownMenuItem(value: 'right', child: Text('Prawa')),
                    DropdownMenuItem(value: 'both', child: Text('Obie')),
                  ],
                  onChanged: _isSaving
                      ? null
                      : (value) => setState(
                          () => _preferredFoot = value?.isEmpty == true
                              ? null
                              : value,
                        ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  child: _isSaving
                      ? const CircularProgressIndicator()
                      : const Text('Zapisz dane'),
                ),
              ],
            ),
    );
  }
}
