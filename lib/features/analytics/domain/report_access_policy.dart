import '../../../core/enums/app_enums.dart';
import '../../../shared/demo/demo_data.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/park.dart';

/// Who may generate a UC04 report, and which parks they may read.
abstract final class ReportAccessPolicy {
  static bool canGenerate(UserRole role) =>
      role == UserRole.parkManager || role == UserRole.conservationResearcher;

  static List<Park> permittedParks(AppUser user) {
    if (!canGenerate(user.role) || user.parkId.trim().isEmpty) {
      return const [];
    }
    if (user.parkId == DemoData.park.id) return const [DemoData.park];
    return [Park(id: user.parkId, name: user.parkId)];
  }

  static bool allows(AppUser user, String parkId) =>
      permittedParks(user).any((park) => park.id == parkId);
}
