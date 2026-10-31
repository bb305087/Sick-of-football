import '../../data/models/dashboard_models.dart';
import '../../data/repositories/dashboard_repository.dart';

class MedicalReportFormController {
  final DashboardRepository _repository;

  MedicalReportFormController({DashboardRepository? repository})
    : _repository = repository ?? DashboardRepository();

  Future<List<TeamMemberModel>> loadPlayers() {
    return _repository.fetchTeamMembers();
  }

  Future<MedicalReportModel> submit({
    required String playerId,
    required String diagnosis,
    String? details,
    DateTime? occurredOn,
    DateTime? clearedOn,
  }) {
    return _repository.createMedicalReport(
      playerId: playerId,
      diagnosis: diagnosis,
      details: details,
      occurredOn: occurredOn,
      clearedOn: clearedOn,
    );
  }
}
