import 'package:flutter/material.dart';

import '../../../data/datasources/api_client.dart';
import '../../../data/models/dashboard_models.dart';
import '../../../logic/medical_reports/medical_report_form_controller.dart';

class AddMedicalReportScreen extends StatefulWidget {
  final MedicalReportFormController? controller;

  const AddMedicalReportScreen({super.key, this.controller});

  @override
  State<AddMedicalReportScreen> createState() => _AddMedicalReportScreenState();
}

class _AddMedicalReportScreenState extends State<AddMedicalReportScreen> {
  late final MedicalReportFormController _controller;
  final _formKey = GlobalKey<FormState>();
  final _diagnosisController = TextEditingController();
  final _detailsController = TextEditingController();
  List<TeamMemberModel> _players = [];
  String? _selectedPlayerId;
  DateTime? _occurredOn;
  DateTime? _clearedOn;
  bool _isLoadingPlayers = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? MedicalReportFormController();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    try {
      final players = await _controller.loadPlayers();
      if (!mounted) return;
      setState(() {
        _players = players.where((player) => player.role == 'player').toList();
        _isLoadingPlayers = false;
        if (_players.isEmpty) {
          _error = 'Brak zawodników w tej drużynie.';
        }
      });
    } on ApiException catch (error) {
      _setLoadError(error.message);
    } on FormatException {
      _setLoadError('Serwer zwrócił nieprawidłowe dane.');
    }
  }

  void _setLoadError(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _isLoadingPlayers = false;
    });
  }

  Future<void> _selectDate({required bool occurredDate}) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: occurredDate
          ? (_occurredOn ?? DateTime.now())
          : (_clearedOn ?? DateTime.now()),
    );
    if (!mounted || selected == null) return;
    setState(() {
      if (occurredDate) {
        _occurredOn = selected;
      } else {
        _clearedOn = selected;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedPlayerId == null) {
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await _controller.submit(
        playerId: _selectedPlayerId!,
        diagnosis: _diagnosisController.text.trim(),
        details: _detailsController.text.trim().isEmpty
            ? null
            : _detailsController.text.trim(),
        occurredOn: _occurredOn,
        clearedOn: _clearedOn,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      _showError(error.message);
    } on FormatException {
      _showError('Serwer zwrócił nieprawidłowe dane.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red[700]),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Wybierz datę';
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dodaj raport medyczny')),
      body: _isLoadingPlayers
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPlayerId,
                    decoration: const InputDecoration(
                      labelText: 'Zawodnik',
                      border: OutlineInputBorder(),
                    ),
                    items: _players
                        .map(
                          (player) => DropdownMenuItem(
                            value: player.id,
                            child: Text(player.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedPlayerId = value),
                    validator: (value) =>
                        value == null ? 'Wybierz zawodnika' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _diagnosisController,
                    decoration: const InputDecoration(
                      labelText: 'Diagnoza',
                      border: OutlineInputBorder(),
                    ),
                    maxLength: 200,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Wprowadź diagnozę'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _detailsController,
                    decoration: const InputDecoration(
                      labelText: 'Szczegóły (opcjonalnie)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    maxLength: 10000,
                  ),
                  const SizedBox(height: 8),
                  _dateTile(
                    label: 'Data urazu',
                    date: _occurredOn,
                    onTap: () => _selectDate(occurredDate: true),
                  ),
                  _dateTile(
                    label: 'Data powrotu (opcjonalnie)',
                    date: _clearedOn,
                    onTap: () => _selectDate(occurredDate: false),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Zapisz raport'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _dateTile({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(_formatDate(date)),
      trailing: const Icon(Icons.calendar_today_outlined),
      onTap: onTap,
    );
  }
}
