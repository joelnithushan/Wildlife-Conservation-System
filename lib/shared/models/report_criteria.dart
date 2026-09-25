import 'package:equatable/equatable.dart';

import '../../core/enums/app_enums.dart';
import '../../core/utils/serialization.dart';
import '../../core/utils/validators.dart';

/// Filter criteria for generating a conservation report (UC04).
class ReportCriteria extends Equatable {
  const ReportCriteria({
    required this.parkId,
    required this.startDate,
    required this.endDate,
    this.categories = const [],
  });

  final String parkId;
  final DateTime startDate;
  final DateTime endDate;

  /// Incident categories to include. At least one category is required; the
  /// validator and repository reject an empty selection (see
  /// [ReportFilterValidator] and the report repository).
  final List<IncidentCategory> categories;

  bool get isValid => Validators.validDateRange(startDate, endDate);

  Map<String, dynamic> toMap() => {
        'parkId': parkId,
        'startDate': dateToWire(startDate),
        'endDate': dateToWire(endDate),
        'categories': categories.map((c) => c.wire).toList(),
      };

  factory ReportCriteria.fromMap(Map<String, dynamic> map) => ReportCriteria(
        parkId: map['parkId'] as String,
        startDate: dateFromWire(map['startDate'])!,
        endDate: dateFromWire(map['endDate'])!,
        categories: (map['categories'] as List?)
                ?.map((c) => parseEnumOrNull(IncidentCategory.values, c))
                .whereType<IncidentCategory>()
                .toList() ??
            const [],
      );

  @override
  List<Object?> get props => [parkId, startDate, endDate, categories];
}
