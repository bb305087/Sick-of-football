import 'package:flutter/material.dart';

import '../../../data/models/dashboard_models.dart';

class TacticDraft {
  final String title;
  final String formation;
  final List<Map<String, dynamic>> lineup;
  final bool published;

  const TacticDraft({
    required this.title,
    required this.formation,
    required this.lineup,
    required this.published,
  });
}

class TacticEditorScreen extends StatefulWidget {
  final List<TeamMemberModel> players;

  const TacticEditorScreen({super.key, required this.players});

  @override
  State<TacticEditorScreen> createState() => _TacticEditorScreenState();
}

class _TacticEditorScreenState extends State<TacticEditorScreen> {
  static const _formations = {
    '4-3-3': ['GK', 'LB', 'CB', 'CB', 'RB', 'CM', 'CM', 'CM', 'LW', 'ST', 'RW'],
    '4-4-2': ['GK', 'LB', 'CB', 'CB', 'RB', 'LM', 'CM', 'CM', 'RM', 'ST', 'ST'],
    '3-5-2': ['GK', 'CB', 'CB', 'CB', 'LM', 'CM', 'CM', 'CM', 'RM', 'ST', 'ST'],
  };

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  String _formation = '4-3-3';
  bool _published = false;
  late List<String?> _selectedPlayers;
  final List<String?> _substitutePlayers = [];

  List<String> get _positions => _formations[_formation]!;

  @override
  void initState() {
    super.initState();
    _selectedPlayers = List<String?>.filled(_positions.length, null);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _changeFormation(String? formation) {
    if (formation == null) return;
    setState(() {
      _formation = formation;
      _selectedPlayers = List<String?>.filled(
        _formations[formation]!.length,
        null,
      );
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final lineup = <Map<String, dynamic>>[];
    for (var index = 0; index < _positions.length; index++) {
      final playerId = _selectedPlayers[index];
      if (playerId != null) {
        lineup.add({'position': _positions[index], 'player_id': playerId});
      }
    }
    for (final playerId in _substitutePlayers) {
      if (playerId != null) {
        lineup.add({
          'position': 'SUB',
          'player_id': playerId,
          'substitute': true,
        });
      }
    }
    Navigator.of(context).pop(
      TacticDraft(
        title: _titleController.text.trim(),
        formation: _formation,
        lineup: lineup,
        published: _published,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zbuduj skład'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Zapisz', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Nazwa taktyki',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Podaj nazwę taktyki'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: ValueKey(_formation),
              initialValue: _formation,
              decoration: const InputDecoration(
                labelText: 'Formacja',
                border: OutlineInputBorder(),
              ),
              items: _formations.keys
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: _changeFormation,
            ),
            const SizedBox(height: 16),
            _buildPitch(),
            const SizedBox(height: 16),
            ...List.generate(
              _positions.length,
              (index) => _buildPlayerPicker(index),
            ),
            const SizedBox(height: 12),
            _buildSubstitutesSection(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Opublikuj dla zawodników'),
              value: _published,
              onChanged: (value) => setState(() => _published = value),
            ),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Zapisz taktykę'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPitch() {
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: Colors.green[700],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Stack(
        children: [
          Center(child: Container(width: 2, color: Colors.white)),
          Center(
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
          const Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Text(
              'BRAMKA PRZECIWNIKA',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
          const Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Text(
              'TWOJA BRAMKA',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerPicker(int index) {
    final position = _positions[index];
    return DropdownButtonFormField<String>(
      key: ValueKey('$_formation-$index'),
      initialValue: _selectedPlayers[index],
      decoration: InputDecoration(labelText: '$position - zawodnik'),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('Nie wybrano')),
        ...widget.players.map(
          (player) =>
              DropdownMenuItem(value: player.id, child: Text(player.name)),
        ),
      ],
      onChanged: (value) => setState(() => _selectedPlayers[index] = value),
    );
  }

  Widget _buildSubstitutesSection() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ławka rezerwowych',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text('Opcjonalnie dodaj zawodników na ławkę.'),
            ...List.generate(
              _substitutePlayers.length,
              (index) => _buildSubstitutePicker(index),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _substitutePlayers.length >= widget.players.length
                    ? null
                    : () => setState(() => _substitutePlayers.add(null)),
                icon: const Icon(Icons.add),
                label: const Text('Dodaj rezerwowego'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubstitutePicker(int index) {
    final selectedStarting = _selectedPlayers.whereType<String>().toSet();
    final selectedSubstitutes = _substitutePlayers
        .whereType<String>()
        .toSet();
    final selected = _substitutePlayers[index];
    final availablePlayers = widget.players.where(
      (player) =>
          player.id == selected ||
          (!selectedStarting.contains(player.id) &&
              !selectedSubstitutes.contains(player.id)),
    );

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey('substitute-$index-$selected'),
            initialValue: selected,
            decoration: InputDecoration(labelText: 'Rezerwowy ${index + 1}'),
            items: availablePlayers
                .map(
                  (player) => DropdownMenuItem(
                    value: player.id,
                    child: Text(player.name),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => _substitutePlayers[index] = value),
          ),
        ),
        IconButton(
          tooltip: 'Usuń z ławki',
          onPressed: () => setState(() => _substitutePlayers.removeAt(index)),
          icon: const Icon(Icons.remove_circle_outline),
        ),
      ],
    );
  }
}
