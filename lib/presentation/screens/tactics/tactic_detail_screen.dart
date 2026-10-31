import 'package:flutter/material.dart';

import '../../../data/models/dashboard_models.dart';

class TacticDetailScreen extends StatelessWidget {
  final TacticModel tactic;
  final List<TeamMemberModel> players;
  final bool canDelete;
  final Future<void> Function()? onDelete;

  const TacticDetailScreen({
    super.key,
    required this.tactic,
    required this.players,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tactic.title),
        actions: [
          if (canDelete)
            IconButton(
              tooltip: 'Usuń taktykę',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              const Icon(Icons.sports_soccer, color: Colors.green, size: 28),
              const SizedBox(width: 12),
              Text(
                tactic.published ? 'Opublikowana' : 'Szkic',
                style: TextStyle(
                  color: tactic.published
                      ? Colors.green[700]
                      : Colors.orange[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (tactic.formation != null) _buildPitch(tactic.formation!),
          if (tactic.content.isNotEmpty &&
              tactic.content != 'Skład ${tactic.formation}') ...[
            const SizedBox(height: 20),
            Text(
              tactic.content,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPitch(String formation) {
    final slots = _slotsFor(formation);
    final substitutes = tactic.lineup
        .where((player) => player['substitute'] == true)
        .toList();
    final startingLineup = tactic.lineup
        .where((player) => player['substitute'] != true)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Skład wyjściowy  •  $formation',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 0.68,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [Colors.green[800]!, Colors.green[600]!],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                _pitchLines(),
                ...List.generate(
                  slots.length,
                  (index) => _playerChip(
                    slots[index],
                    index < startingLineup.length
                        ? startingLineup[index]
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Ustawienie zawodników',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          startingLineup.isEmpty
              ? 'Brak przypisanych zawodników.'
              : '${startingLineup.length > 11 ? 11 : startingLineup.length} z 11 pozycji obsadzonych',
          style: TextStyle(color: Colors.grey[700]),
        ),
        if (substitutes.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Ławka rezerwowych',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: substitutes.map(_substituteChip).toList(),
          ),
        ],
      ],
    );
  }

  Widget _substituteChip(Map<String, dynamic> player) {
    final playerId = player['player_id']?.toString();
    final matchingPlayers = players.where((item) => item.id == playerId);
    final name = matchingPlayers.isEmpty
        ? 'Zawodnik'
        : matchingPlayers.first.name;
    return Chip(
      avatar: const Icon(Icons.person_outline, size: 18),
      label: Text(name),
    );
  }

  Widget _pitchLines() {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _PitchPainter())),
          const Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: Text(
              'BRAMKA PRZECIWNIKA',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 9),
            ),
          ),
          const Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Text(
              'TWOJA BRAMKA',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerChip(_PitchSlot slot, Map<String, dynamic>? player) {
    final playerId = player?['player_id']?.toString();
    final matchingPlayers = players.where((item) => item.id == playerId);
    final name = matchingPlayers.isEmpty
        ? 'Nie wybrano'
        : matchingPlayers.first.name;
    return Align(
      alignment: Alignment(slot.x * 2 - 1, slot.y * 2 - 1),
      child: SizedBox(
        width: 104,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: player == null
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.white,
              child: Text(
                slot.position,
                style: TextStyle(
                  color: player == null ? Colors.white : Colors.green[900],
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              name,
              maxLines: 2,
              softWrap: true,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_PitchSlot> _slotsFor(String formation) {
    const goalkeeper = _PitchSlot('GK', 0.5, 0.9);
    switch (formation) {
      case '4-4-2':
        return [
          goalkeeper,
          const _PitchSlot('LB', 0.06, 0.72),
          const _PitchSlot('CB', 0.26, 0.76),
          const _PitchSlot('CB', 0.74, 0.76),
          const _PitchSlot('RB', 0.94, 0.72),
          const _PitchSlot('LM', 0.12, 0.48),
          const _PitchSlot('CM', 0.38, 0.52),
          const _PitchSlot('CM', 0.62, 0.52),
          const _PitchSlot('RM', 0.88, 0.48),
          const _PitchSlot('ST', 0.36, 0.2),
          const _PitchSlot('ST', 0.64, 0.2),
        ];
      case '3-5-2':
        return [
          goalkeeper,
          const _PitchSlot('CB', 0.25, 0.72),
          const _PitchSlot('CB', 0.5, 0.76),
          const _PitchSlot('CB', 0.75, 0.72),
          const _PitchSlot('LM', 0.08, 0.5),
          const _PitchSlot('CM', 0.32, 0.52),
          const _PitchSlot('CM', 0.5, 0.58),
          const _PitchSlot('CM', 0.68, 0.52),
          const _PitchSlot('RM', 0.92, 0.5),
          const _PitchSlot('ST', 0.36, 0.2),
          const _PitchSlot('ST', 0.64, 0.2),
        ];
      default:
        return [
          goalkeeper,
          const _PitchSlot('LB', 0.15, 0.72),
          const _PitchSlot('CB', 0.38, 0.76),
          const _PitchSlot('CB', 0.62, 0.76),
          const _PitchSlot('RB', 0.85, 0.72),
          const _PitchSlot('CM', 0.25, 0.52),
          const _PitchSlot('CM', 0.5, 0.58),
          const _PitchSlot('CM', 0.75, 0.52),
          const _PitchSlot('LW', 0.18, 0.34),
          const _PitchSlot('ST', 0.5, 0.28),
          const _PitchSlot('RW', 0.82, 0.34),
        ];
    }
  }
}

class _PitchSlot {
  final String position;
  final double x;
  final double y;

  const _PitchSlot(this.position, this.x, this.y);
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);
    canvas.drawCircle(center, size.width * 0.14, paint);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.22,
        0,
        size.width * 0.56,
        size.height * 0.16,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.22,
        size.height * 0.84,
        size.width * 0.56,
        size.height * 0.16,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
