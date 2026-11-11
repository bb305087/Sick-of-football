import 'package:flutter/material.dart';

import '../../../core/security/screen_capture_protection.dart';
import '../../../data/models/dashboard_models.dart';

class MedicalReportDetailScreen extends StatefulWidget {
  final MedicalReportModel report;
  final String playerName;
  final Future<void> Function() onDelete;

  const MedicalReportDetailScreen({
    super.key,
    required this.report,
    required this.playerName,
    required this.onDelete,
  });

  @override
  State<MedicalReportDetailScreen> createState() =>
      _MedicalReportDetailScreenState();
}

class _MedicalReportDetailScreenState extends State<MedicalReportDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScreenCaptureProtection.enable();
      }
    });
  }

  @override
  void dispose() {
    ScreenCaptureProtection.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Raport medyczny'),
        actions: [
          IconButton(
            tooltip: 'Usuń raport',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.medical_services_outlined,
            color: Colors.red,
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            widget.report.diagnosis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _DetailRow(label: 'Zawodnik', value: widget.playerName),
          _DetailRow(
            label: 'Data urazu',
            value: _formatDate(widget.report.occurredOn) ?? 'Nie podano',
          ),
          _DetailRow(
            label: 'Data powrotu',
            value: _formatDate(widget.report.clearedOn) ?? 'Nie podano',
          ),
          const SizedBox(height: 20),
          const Text(
            'Szczegóły',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            widget.report.details?.trim().isNotEmpty == true
                ? widget.report.details!
                : 'Brak dodatkowych informacji.',
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń raport?'),
        content: const Text('Ten raport medyczny zostanie trwale usunięty.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await widget.onDelete();
      if (context.mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  String? _formatDate(String? value) {
    if (value == null || value.isEmpty) return null;
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
