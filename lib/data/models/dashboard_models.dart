class EventModel {
  final String id;
  final String type;
  final String title;
  final String startsAt;
  final String location;

  const EventModel({
    required this.id,
    required this.type,
    required this.title,
    required this.startsAt,
    required this.location,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'].toString(),
      type: json['type'] as String,
      title: json['title'] as String,
      startsAt: json['starts_at'].toString(),
      location: (json['location'] ?? 'Brak lokalizacji') as String,
    );
  }
}

class TeamMemberModel {
  final String id;
  final String name;
  final String availability;
  final String role;

  const TeamMemberModel({
    required this.id,
    required this.name,
    required this.availability,
    required this.role,
  });

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) {
    return TeamMemberModel(
      id: json['id'].toString(),
      name: (json['name'] ?? json['full_name']) as String,
      availability: (json['availability'] ?? 'unknown') as String,
      role: (json['role'] ?? 'player').toString(),
    );
  }
}

class TacticModel {
  final String id;
  final String title;
  final String content;
  final bool published;

  const TacticModel({
    required this.id,
    required this.title,
    required this.content,
    required this.published,
  });

  factory TacticModel.fromJson(Map<String, dynamic> json) {
    return TacticModel(
      id: json['id'].toString(),
      title: json['title'] as String,
      content: (json['content'] ?? json['description'] ?? '') as String,
      published: (json['published'] ?? json['is_published'] ?? false) as bool,
    );
  }
}

class MedicalReportModel {
  final String playerId;
  final String diagnosis;
  final String? details;

  const MedicalReportModel({
    required this.playerId,
    required this.diagnosis,
    required this.details,
  });

  factory MedicalReportModel.fromJson(Map<String, dynamic> json) {
    return MedicalReportModel(
      playerId: json['player_id'].toString(),
      diagnosis: (json['diagnosis'] ?? json['reason']) as String,
      details: json['details'] as String?,
    );
  }
}
