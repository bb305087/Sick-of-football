import 'package:flutter/material.dart';

class EventDraft {
  final String type;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;
  final String location;

  const EventDraft({
    required this.type,
    required this.title,
    required this.startsAt,
    required this.endsAt,
    required this.location,
  });
}

class EventEditorScreen extends StatefulWidget {
  const EventEditorScreen({super.key});

  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends State<EventEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  String _type = 'match';
  DateTime _startsAt = DateTime.now().add(const Duration(hours: 1));
  DateTime _endsAt = DateTime.now().add(const Duration(hours: 3));

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool start}) async {
    final initial = start ? _startsAt : _endsAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (!mounted || date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted || time == null) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (start) {
        _startsAt = selected;
        if (!_endsAt.isAfter(selected)) {
          _endsAt = selected.add(const Duration(hours: 2));
        }
      } else {
        _endsAt = selected;
      }
    });
  }

  String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month.${value.year}, $hour:$minute';
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (!_endsAt.isAfter(_startsAt)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Koniec musi być później niż początek.')),
      );
      return;
    }
    Navigator.of(context).pop(
      EventDraft(
        type: _type,
        title: _titleController.text.trim(),
        startsAt: _startsAt,
        endsAt: _endsAt,
        location: _locationController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dodaj wydarzenie')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Rodzaj wydarzenia'),
              items: const [
                DropdownMenuItem(value: 'match', child: Text('Mecz')),
                DropdownMenuItem(value: 'training', child: Text('Trening')),
              ],
              onChanged: (value) => setState(() => _type = value!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Nazwa wydarzenia',
                hintText: 'np. Mecz z KS Gliwice',
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Podaj nazwę wydarzenia.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Lokalizacja'),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: const Text('Początek'),
              subtitle: Text(_formatDateTime(_startsAt)),
              onTap: () => _pickDateTime(start: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Koniec'),
              subtitle: Text(_formatDateTime(_endsAt)),
              onTap: () => _pickDateTime(start: false),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Zapisz wydarzenie'),
            ),
          ],
        ),
      ),
    );
  }
}
