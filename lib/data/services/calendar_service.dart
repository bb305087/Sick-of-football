import 'package:device_calendar/device_calendar.dart';

import '../models/dashboard_models.dart';

class CalendarService {
  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();

  Future<void> addEvent(EventModel match) async {
    final permission = await _plugin.requestPermissions();
    if (permission.data != true) {
      throw const CalendarException(
        'Brak zgody na dostęp do kalendarza urządzenia.',
      );
    }

    final calendars = await _plugin.retrieveCalendars();
    if (!calendars.isSuccess || calendars.data == null) {
      throw CalendarException(
        calendars.errors.isEmpty
            ? 'Nie udało się pobrać kalendarzy urządzenia.'
            : calendars.errors.first.errorMessage,
      );
    }

    final writableCalendars = calendars.data!
        .where((calendar) => calendar.id != null && calendar.isReadOnly != true)
        .toList();
    if (writableCalendars.isEmpty) {
      throw const CalendarException(
        'Nie znaleziono kalendarza, do którego można dodać wydarzenie.',
      );
    }

    final calendar = writableCalendars.firstWhere(
      (item) => item.isDefault == true,
      orElse: () => writableCalendars.first,
    );
    final end = match.endsAt ?? match.startsAt.add(const Duration(hours: 2));
    final event = Event(
      calendar.id,
      title: match.title,
      description: 'Wydarzenie z aplikacji Sick of Football',
      location: match.location,
      start: TZDateTime.from(match.startsAt, local),
      end: TZDateTime.from(end, local),
    );
    final result = await _plugin.createOrUpdateEvent(event);
    if (result?.isSuccess != true) {
      throw CalendarException(
        result?.errors.isEmpty == true
            ? 'Nie udało się zapisać wydarzenia w kalendarzu.'
            : result!.errors.first.errorMessage,
      );
    }
  }
}

class CalendarException implements Exception {
  final String message;

  const CalendarException(this.message);

  @override
  String toString() => message;
}
