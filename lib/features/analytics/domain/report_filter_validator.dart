import '../../../core/enums/app_enums.dart';
import 'report_messages.dart';

/// Pure validation for the report filter form.
///
/// An invalid result must stop the caller from querying report data.
class ReportFilterValidator {
  const ReportFilterValidator();

  String? validate({
    required String? parkId,
    required DateTime? startDate,
    required DateTime? endDate,
    required List<IncidentCategory> categories,
    required Set<String> authorizedParkIds,
  }) {
    final park = parkId?.trim() ?? '';
    if (park.isEmpty) return ReportMessages.missingPark;
    if (!authorizedParkIds.contains(park)) {
      return ReportMessages.unauthorizedPark;
    }
    if (startDate == null) return ReportMessages.missingStart;
    if (endDate == null) return ReportMessages.missingEnd;
    final start = DateTime.utc(startDate.year, startDate.month, startDate.day);
    final end = DateTime.utc(endDate.year, endDate.month, endDate.day);
    if (start.isAfter(end)) return ReportMessages.invalidRange;
    if (categories.isEmpty) return ReportMessages.missingCategories;
    return null;
  }
}
