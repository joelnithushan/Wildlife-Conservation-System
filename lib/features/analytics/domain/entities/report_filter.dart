import 'package:equatable/equatable.dart';

import '../../../../shared/models/enums.dart';

class ReportFilter extends Equatable {
  const ReportFilter({
    required this.startDate,
    required this.endDate,
    this.parkId,
    this.categories = const [],
  });

  final String? parkId;
  final DateTime startDate;
  final DateTime endDate;
  final List<IncidentCategory> categories;

  @override
  List<Object?> get props => [parkId, startDate, endDate, categories];
}
