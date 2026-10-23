import 'package:flutter/material.dart';
import '../../data/datasources/api_client.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/dashboard_repository.dart';

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
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    try {
      final results = await Future.wait([
        _dashboardRepository.fetchEvents(),
        _dashboardRepository.fetchTeamMembers(),
      ]);
      if (!mounted) return;
      setState(() {
        _events = results[0] as List<EventModel>;
        _teamMembers = results[1] as List<TeamMemberModel>;
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
    return ListView(
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
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  nextEvent == null
                      ? 'Brak zaplanowanych wydarzeń'
                      : '${nextEvent.title} (${nextEvent.startsAt})',
                ),
                const SizedBox(height: 12),
                if (!isCoach)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () {
                      _showPresenceDialog(context);
                    },
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text('Zgłoś obecność / absencję', style: TextStyle(color: Colors.white)),
                  )
                else
                  const Text(' Zgłoszonych zawodników: 14/18', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Ostatnie powiadomienia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const ListTile(
          leading: Icon(Icons.fitness_center, color: Colors.green),
          title: Text('Trening: Wtorek 18:30'),
          subtitle: Text('Boisko boczne (zbiórka 18:15)'),
        ),
      ],
    );
  }

  // WIDOK 2: Taktyka
  Widget _buildTacticsScreen(bool isCoach) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.developer_board, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              isCoach ? 'Panel Tworzenia Taktyki (Dla Trenera)' : 'Udostępniona Taktyka na Mecz',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isCoach
                  ? 'Tutaj możesz publikować schematy stałych fragmentów gry i ustalać skład.'
                  : 'Podgląd schematów i pierwszego składu ustalonego przez trenera.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  // WIDOK 3: Raporty / Kadra
  Widget _buildTeamScreen(bool isCoach) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(child: Text(_loadError!));
    }
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          isCoach ? 'Raporty Medyczne i Absencje' : 'Kadra Zespołu',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ..._teamMembers.map(
          (member) => ListTile(
            leading: CircleAvatar(child: Text(member.name.substring(0, 1))),
            title: Text(member.name),
            subtitle: Text(
              member.availability == 'present' ? 'Obecny' : 'Nieobecny',
            ),
            trailing: isCoach && member.availability != 'present'
                ? const Icon(Icons.lock, color: Colors.red)
                : null,
          ),
        ),
      ],
    );
  }

  // WIDOK 4: Profil
  Widget _buildProfileScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
          const SizedBox(height: 16),
          Text('Zalogowany jako: ${widget.userRole}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Wersja aplikacji: 1.0.0-dev'),
        ],
      ),
    );
  }

  // Okienko zgłaszania nieobecności przez zawodnika
  void _showPresenceDialog(BuildContext context) {
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
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.work, color: Colors.orange),
              title: const Text('Nieobecny: Praca'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.healing, color: Colors.red),
              title: const Text('Nieobecny: Kontuzja / Choroba'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}