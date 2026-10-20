class EventModel {
  final int id;
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
      id: json['id'] as int,
      type: json['type'] as String,
      title: json['title'] as String,
      startsAt: json['starts_at'] as String,
      location: json['location'] as String,
    );
  }
}

class TeamMemberModel {
  final int id;
  final String name;
  final String availability;

  const TeamMemberModel({
    required this.id,
    required this.name,
    required this.availability,
  });

  factory TeamMemberModel.fromJson(Map<String, dynamic> json) {
    return TeamMemberModel(
      id: json['id'] as int,
      name: json['name'] as String,
      availability: json['availability'] as String,
    );
  }
}
