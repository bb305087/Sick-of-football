import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sick_of_football/data/models/dashboard_models.dart';
import 'package:sick_of_football/presentation/screens/tactics/tactic_detail_screen.dart';

void main() {
  testWidgets('displays the substitute player below the pitch', (
    WidgetTester tester,
  ) async {
    const starter = TeamMemberModel(
      id: 'player-1',
      name: 'Starting Player',
      availability: 'available',
      role: 'player',
    );
    const substitute = TeamMemberModel(
      id: 'player-12',
      name: 'Bench Player',
      availability: 'available',
      role: 'player',
    );
    const tactic = TacticModel(
      id: 'tactic-1',
      title: 'Test tactic',
      content: 'Skład 4-3-3',
      published: false,
      formation: '4-3-3',
      lineup: [
        {'position': 'GK', 'player_id': 'player-1'},
        {'position': 'GK', 'player_id': 'player-12', 'substitute': true},
      ],
      version: 1,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: TacticDetailScreen(
          tactic: tactic,
          players: [starter, substitute],
          canDelete: false,
          onDelete: null,
          onEdit: null,
        ),
      ),
    );

    expect(find.text('Ławka rezerwowych'), findsOneWidget);
    expect(find.text('Bench Player'), findsOneWidget);
    expect(find.text('Player'), findsOneWidget);
    expect(find.text('Starting Player'), findsNothing);
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
  });
}
