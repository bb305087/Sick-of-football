import 'package:flutter/material.dart';

import '../../data/models/dashboard_models.dart';
import '../../data/services/calendar_service.dart';

class EventDetailScreen extends StatefulWidget {
  final EventModel event;

  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final CalendarService _calendarService = CalendarService();
  bool _isAddingToCalendar = false;

  String _formatDateTime(DateTime value) {
    final date = value.toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.${date.year}, $hour:$minute';
  }

  Future<void> _addToCalendar() async {
    setState(() => _isAddingToCalendar = true);
    try {
      await _calendarService.addEvent(widget.event);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mecz dodano do kalendarza.')),
      );
    } on CalendarException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isAddingToCalendar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final end = event.endsAt ?? event.startsAt.add(const Duration(hours: 2));
    return Scaffold(
      appBar: AppBar(title: const Text('Szczegóły wydarzenia')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(event.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('Termin'),
            subtitle: Text(
              '${_formatDateTime(event.startsAt)} - ${_formatDateTime(end)}',
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.location_on_outlined),
            title: const Text('Lokalizacja'),
            subtitle: Text(event.location),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isAddingToCalendar ? null : _addToCalendar,
            icon: _isAddingToCalendar
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.event_available),
            label: Text(
              _isAddingToCalendar ? 'Dodawanie...' : 'Dodaj do kalendarza',
            ),
          ),
        ],
      ),
    );
  }
}
