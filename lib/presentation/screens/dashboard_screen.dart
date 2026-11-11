import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/datasources/api_client.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/models/profile_photo_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/dashboard_repository.dart';
import 'tactics/tactic_detail_screen.dart';
import 'tactics/tactic_editor_screen.dart';
import 'player/add_medical_report_screen.dart';
import 'player/medical_report_detail_screen.dart';
import 'profile/add_profile_photo_screen.dart';
import 'profile/profile_details_screen.dart';
import 'event_detail_screen.dart';
import 'event_editor_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userRole;

  const DashboardScreen({super.key, required this.userRole});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final DashboardRepository _dashboardRepository = DashboardRepository();
  final AuthRepository _authRepository = AuthRepository();
  List<EventModel> _events = [];
  List<TeamMemberModel> _teamMembers = [];
  List<TacticModel> _tactics = [];
  List<MedicalReportModel> _medicalReports = [];
  File? _profilePhoto;
  Uint8List? _profilePhotoBytes;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final requests = <Future<dynamic>>[
        _dashboardRepository.fetchEvents(),
        _dashboardRepository.fetchTeamMembers(),
        _dashboardRepository.fetchTactics(),
      ];
      if (widget.userRole == 'Trener') {
        requests.add(_dashboardRepository.fetchMedicalReports());
      }
      final results = await Future.wait(requests);
      ProfilePhotoModel? profilePhoto;
      try {
        profilePhoto = await _dashboardRepository.fetchProfilePhoto();
      } on ApiException {
        profilePhoto = null;
      }
      if (!mounted) return;
      setState(() {
        _events = results[0] as List<EventModel>;
        _teamMembers = results[1] as List<TeamMemberModel>;
        _tactics = results[2] as List<TacticModel>;
        _profilePhotoBytes = profilePhoto?.bytes;
        if (results.length > 3) {
          _medicalReports = results[3] as List<MedicalReportModel>;
        }
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = error.message;
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Serwer zwrócił nieprawidłowe dane.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCoach = widget.userRole == 'Trener';

    // Lista widoków zmieniających się po kliknięciu w menu na dole
    final List<Widget> pages = [
      // Zakładka 1: Strona główna / Wydarzenia
      _buildHomeScreen(isCoach),

      // Zakładka 2: Taktyka i Składy
      _buildTacticsScreen(isCoach),

      // Zakładka 3: Kadra / Raporty
      _buildTeamScreen(isCoach),

      // Zakładka 4: Profil / Ustawienia
      _buildProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Szatnia Manager (${widget.userRole})'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Wyloguj',
            onPressed: () async {
              await _authRepository.logout();
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.green[800],
        unselectedItemColor: Colors.grey[600],
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Terminarz',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.sports),
            label: 'Taktyka',
          ),
          BottomNavigationBarItem(
            icon: Icon(isCoach ? Icons.medical_services : Icons.group),
            label: isCoach ? 'Raporty' : 'Drużyna',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  // WIDOK 1: Terminarz i Wydarzenia
  Widget _buildHomeScreen(bool isCoach) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_loadError!, textAlign: TextAlign.center),
        ),
      );
    }
    final nextEvent = _events.isEmpty ? null : _events.first;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Card(
              color: Colors.green[50],
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Najbliższy mecz',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      nextEvent == null
                          ? 'Brak zaplanowanych wydarzeń'
                          : '${nextEvent.title} (${_formatEventDate(nextEvent.startsAt)})',
                    ),
                    const SizedBox(height: 12),
                    if (!isCoach)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: nextEvent == null
                            ? null
                            : () => _showPresenceDialog(context, nextEvent.id),
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text(
                          'Zgłoś obecność / absencję',
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    else
                      const Text(
                        ' Zgłoszonych zawodników: 14/18',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Wszystkie wydarzenia',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            if (_events.isEmpty)
              const Text('Brak zaplanowanych wydarzeń.')
            else
              ..._events.map(
                (event) => Card(
                  child: ListTile(
                    leading: Icon(
                      event.type == 'match'
                          ? Icons.sports_soccer
                          : Icons.fitness_center,
                      color: Colors.green[700],
                    ),
                    title: Text(event.title),
                    subtitle: Text(
                      '${_formatEventDate(event.startsAt)}\n${event.location}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EventDetailScreen(event: event),
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Text(
              'Ostatnie powiadomienia',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const ListTile(
              leading: Icon(Icons.fitness_center, color: Colors.green),
              title: Text('Trening: Wtorek 18:30'),
              subtitle: Text('Boisko boczne (zbiórka 18:15)'),
            ),
          ],
        ),
        if (isCoach)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: _openEventEditor,
              icon: const Icon(Icons.add),
              label: const Text('Dodaj wydarzenie'),
            ),
          ),
      ],
    );
  }

  Future<void> _openEventEditor() async {
    final draft = await Navigator.of(context).push<EventDraft>(
      MaterialPageRoute(builder: (_) => const EventEditorScreen()),
    );
    if (!mounted || draft == null) return;
    try {
      final event = await _dashboardRepository.createEvent(
        type: draft.type,
        title: draft.title,
        startsAt: draft.startsAt,
        endsAt: draft.endsAt,
        location: draft.location,
      );
      if (!mounted) return;
      setState(
        () => _events = [..._events, event]
          ..sort((first, second) => first.startsAt.compareTo(second.startsAt)),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wydarzenie zostało zapisane.')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    } on FormatException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Serwer zwrócił nieprawidłowe dane.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatEventDate(DateTime value) {
    final date = value.toLocal();
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.${date.year}, $hour:$minute';
  }

  // WIDOK 2: Taktyka
  Widget _buildTacticsScreen(bool isCoach) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_tactics.isEmpty) {
      return Stack(
        children: [
          Center(
            child: Text(
              isCoach
                  ? 'Brak zapisanych taktyk.'
                  : 'Trener nie opublikował jeszcze taktyki.',
            ),
          ),
          if (isCoach) _buildCreateTacticButton(),
        ],
      );
    }
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _tactics.length,
          itemBuilder: (context, index) {
            final tactic = _tactics[index];
            return Card(
              child: ExpansionTile(
                leading: const Icon(Icons.sports_soccer, color: Colors.green),
                title: Text(tactic.title),
                subtitle: Text(tactic.published ? 'Opublikowana' : 'Szkic'),
                trailing: IconButton(
                  tooltip: 'Otwórz taktykę',
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => _openTacticDetails(tactic),
                ),
                children: [
                  if (tactic.content.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(tactic.content),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        if (isCoach) _buildCreateTacticButton(),
      ],
    );
  }

  Future<void> _openTacticDetails(TacticModel tactic) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TacticDetailScreen(
          tactic: tactic,
          players: _teamMembers,
          canDelete: widget.userRole == 'Trener',
          onDelete: () => _deleteTactic(tactic),
        ),
      ),
    );
  }

  Future<void> _deleteTactic(TacticModel tactic) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń taktykę?'),
        content: Text('Taktyka „${tactic.title}” zostanie usunięta.'),
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
    if (confirmed != true || !mounted) return;
    try {
      await _dashboardRepository.deleteTactic(tactic.id);
      if (!mounted) return;
      setState(() => _tactics.removeWhere((item) => item.id == tactic.id));
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Taktyka została usunięta.')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildCreateTacticButton() {
    return Positioned(
      right: 16,
      bottom: 16,
      child: FloatingActionButton.extended(
        onPressed: _openTacticEditor,
        icon: const Icon(Icons.add),
        label: const Text('Nowa taktyka'),
      ),
    );
  }

  Future<void> _openTacticEditor() async {
    final draft = await Navigator.of(context).push<TacticDraft>(
      MaterialPageRoute(
        builder: (_) => TacticEditorScreen(players: _teamMembers),
      ),
    );
    if (!mounted || draft == null) return;
    await _createTactic(
      title: draft.title,
      content: 'Formacja ${draft.formation}',
      published: draft.published,
      formation: draft.formation,
      lineup: draft.lineup,
    );
  }

  Future<void> _createTactic({
    required String title,
    required String content,
    required bool published,
    String formation = '4-3-3',
    List<Map<String, dynamic>> lineup = const [],
  }) async {
    try {
      final tactic = await _dashboardRepository.createSquadTactic(
        title: title,
        formation: formation,
        lineup: lineup,
        published: published,
      );
      if (!mounted) return;
      setState(() => _tactics = [tactic, ..._tactics]);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Taktyka została zapisana.')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    }
  }

  // WIDOK 3: Raporty / Kadra
  Widget _buildTeamScreen(bool isCoach) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(child: Text(_loadError!));
    }
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Text(
              isCoach ? 'Raporty Medyczne i Absencje' : 'Kadra Zespołu',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (isCoach)
              OutlinedButton.icon(
                onPressed: _createInvitation,
                icon: const Icon(Icons.person_add),
                label: const Text('Zaproś zawodnika do drużyny'),
              ),
            if (isCoach) const SizedBox(height: 8),
            if (isCoach && _medicalReports.isNotEmpty)
              ..._medicalReports.map(
                (report) => ListTile(
                  leading: const Icon(
                    Icons.medical_services,
                    color: Colors.red,
                  ),
                  title: Text(report.diagnosis),
                  subtitle: Text(_playerNameFor(report.playerId)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openMedicalReport(report),
                ),
              ),
            ..._teamMembers.map(
              (member) => ListTile(
                leading: CircleAvatar(child: Text(member.name.substring(0, 1))),
                title: Text(member.name),
                subtitle: Text(
                  member.availability == 'present'
                      ? 'Obecny'
                      : member.availability == 'unknown'
                      ? 'Brak danych o obecności'
                      : 'Nieobecny',
                ),
                trailing:
                    isCoach &&
                        member.availability != 'present' &&
                        member.availability != 'unknown'
                    ? const Icon(Icons.lock, color: Colors.red)
                    : null,
              ),
            ),
          ],
        ),
        if (isCoach)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: _openMedicalReportForm,
              icon: const Icon(Icons.add),
              label: const Text('Dodaj raport'),
            ),
          ),
      ],
    );
  }

  Future<void> _createInvitation() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final invitation = await _dashboardRepository.createInvitation();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Link zaproszenia'),
          content: SelectableText(invitation.deepLink),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: invitation.deepLink),
                );
                if (!context.mounted) return;
                Navigator.of(context).pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Link zaproszenia skopiowany.')),
                );
              },
              child: const Text('Kopiuj link'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Zamknij'),
            ),
          ],
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    }
  }

  String _playerNameFor(String playerId) {
    final player = _teamMembers.where((member) => member.id == playerId);
    return player.isEmpty ? 'Nieznany zawodnik' : player.first.name;
  }

  Future<void> _openMedicalReport(MedicalReportModel report) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MedicalReportDetailScreen(
          report: report,
          playerName: _playerNameFor(report.playerId),
          onDelete: () => _dashboardRepository.deleteMedicalReport(report.id!),
        ),
      ),
    );
    if (deleted == true && mounted) {
      setState(() {
        _medicalReports.removeWhere((item) => item.id == report.id);
      });
    }
  }

  Future<void> _openMedicalReportForm() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddMedicalReportScreen()),
    );
    if (created != true || !mounted) return;
    try {
      final reports = await _dashboardRepository.fetchMedicalReports();
      if (mounted) setState(() => _medicalReports = reports);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  // WIDOK 4: Profil
  Widget _buildProfileScreen() {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: CircleAvatar(
            radius: 40,
            backgroundImage: _profilePhoto == null
                ? (_profilePhotoBytes == null
                      ? null
                      : MemoryImage(_profilePhotoBytes!))
                : FileImage(_profilePhoto!),
            child: _profilePhoto == null && _profilePhotoBytes == null
                ? const Icon(Icons.person, size: 40)
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Zalogowany jako: ${widget.userRole}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () async {
            final photo = await Navigator.of(context).push<File>(
              MaterialPageRoute(builder: (_) => const AddProfilePhotoScreen()),
            );
            if (photo != null && mounted) {
              try {
                await _dashboardRepository.saveProfilePhoto(photo);
                if (!mounted) return;
                setState(() {
                  _profilePhoto = photo;
                  _profilePhotoBytes = null;
                });
              } on ApiException catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error.message),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(
            _profilePhoto == null && _profilePhotoBytes == null
                ? 'Dodaj zdjęcie profilowe'
                : 'Zmień zdjęcie profilowe',
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileDetailsScreen()),
            );
          },
          icon: const Icon(Icons.badge_outlined),
          label: const Text('Uzupełnij dane osobowe'),
        ),
        const SizedBox(height: 16),
        const Center(child: Text('Wersja aplikacji: 1.0.0-dev')),
      ],
    );
  }

  // Okienko zgłaszania nieobecności przez zawodnika
  void _showPresenceDialog(BuildContext context, String eventId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zgłoś status na mecz'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('Będę obecny'),
              onTap: () => _submitAttendance(context, eventId, 'present'),
            ),
            ListTile(
              leading: const Icon(Icons.work, color: Colors.orange),
              title: const Text('Nieobecny: Praca'),
              onTap: () => _submitAttendance(context, eventId, 'work', 'Praca'),
            ),
            ListTile(
              leading: const Icon(Icons.healing, color: Colors.red),
              title: const Text('Nieobecny: Kontuzja / Choroba'),
              onTap: () => _submitAttendance(
                context,
                eventId,
                'injury_illness',
                'Kontuzja / Choroba',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitAttendance(
    BuildContext context,
    String eventId,
    String status, [
    String? reason,
  ]) async {
    Navigator.pop(context);
    try {
      await _dashboardRepository.setAttendance(
        eventId: eventId,
        status: status,
        reason: reason,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status obecności został zapisany.')),
      );
    } on ApiException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.red),
      );
    }
  }
}
