import '../entities/patrol.dart';
import '../repositories/patrol_repository.dart';

class GetAssignedPatrols {
  const GetAssignedPatrols(this._repository);
  final PatrolRepository _repository;

  Future<List<Patrol>> call(String rangerId) =>
      _repository.getAssignedPatrols(rangerId);
}
