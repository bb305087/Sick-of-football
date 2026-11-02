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
  final String? formation;
  final List<Map<String, dynamic>> lineup;
  final int version;

  const TacticModel({
    required this.id,
    required this.title,
    required this.content,
    required this.published,
    required this.formation,
    required this.lineup,
    required this.version,
  });

  factory TacticModel.fromJson(Map<String, dynamic> json) {
    return TacticModel(
      id: json['id'].toString(),
      title: (json['title'] ?? '') as String,
      content: (json['content'] ?? json['description'] ?? '') as String,
      published: (json['published'] ?? json['is_published'] ?? false) as bool,
      formation: json['formation'] as String?,
      lineup: (json['lineup'] as List<dynamic>? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      version: (json['version'] as num?)?.toInt() ?? 1,
    );
  }
}

class MedicalReportModel {
  final String? id;
  final String playerId;
  final String diagnosis;
  final String? details;
  final String? occurredOn;
  final String? clearedOn;

  const MedicalReportModel({
    this.id,
    required this.playerId,
    required this.diagnosis,
    required this.details,
    this.occurredOn,
    this.clearedOn,
  });

  factory MedicalReportModel.fromJson(Map<String, dynamic> json) {
    return MedicalReportModel(
      id: json['id']?.toString(),
      playerId: json['player_id'].toString(),
      diagnosis: (json['diagnosis'] ?? json['reason']) as String,
      details: json['details'] as String?,
      occurredOn: json['occurred_on']?.toString(),
      clearedOn: json['cleared_on']?.toString(),
    );
  }
}

class InvitationModel {
  final String token;
  final String deepLink;
  final DateTime expiresAt;
  final int maxUses;

  const InvitationModel({
    required this.token,
    required this.deepLink,
    required this.expiresAt,
    required this.maxUses,
  });

  factory InvitationModel.fromJson(Map<String, dynamic> json) {
    final token = json['token'] as String;
    return InvitationModel(
      token: token,
      deepLink: (json['deep_link'] ?? 'bklasa://invite/$token') as String,
      expiresAt: DateTime.parse(json['expires_at'].toString()),
      maxUses: (json['max_uses'] as num?)?.toInt() ?? 1,
    );
  }
}
