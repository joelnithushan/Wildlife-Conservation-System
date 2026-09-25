import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/app_enums.dart';
import '../../../core/errors/exceptions.dart';
import '../../../shared/models/app_user.dart';
import '../../../shared/models/conservation_report.dart';
import '../../../shared/models/report_criteria.dart';
import '../../../shared/session/current_user.dart';
import '../domain/report_access_policy.dart';
import '../domain/report_filter_validator.dart';
import '../domain/report_messages.dart';
import 'providers/analytics_providers.dart';

enum ReportStep { filters, generating, results, export, unavailable }

enum ReportExportPhase { idle, exporting, success, failure }

class ReportFlowState {
  const ReportFlowState({
    required this.step,
    this.parkId,
    this.startDate,
    this.endDate,
    this.categories = const [],
    this.validationError,
    this.serviceError,
    this.report,
    this.exportPhase = ReportExportPhase.idle,
    this.exportError,
    this.exportPath,
  });

  factory ReportFlowState.initial(AppUser user) {
    final parks = ReportAccessPolicy.permittedParks(user);
    return ReportFlowState(
      step: ReportStep.filters,
      parkId: parks.length == 1 ? parks.single.id : null,
      categories: List<IncidentCategory>.from(IncidentCategory.values),
    );
  }

  final ReportStep step;
  final String? parkId;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<IncidentCategory> categories;
  final String? validationError;
  final String? serviceError;
  final ConservationReport? report;
  final ReportExportPhase exportPhase;
  final String? exportError;
  final String? exportPath;

  ReportFlowState copyWith({
    ReportStep? step,
    String? parkId,
    bool clearPark = false,
    DateTime? startDate,
    bool clearStart = false,
    DateTime? endDate,
    bool clearEnd = false,
    List<IncidentCategory>? categories,
    String? validationError,
    bool clearValidation = false,
    String? serviceError,
    bool clearServiceError = false,
    ConservationReport? report,
    bool clearReport = false,
    ReportExportPhase? exportPhase,
    String? exportError,
    bool clearExportError = false,
    String? exportPath,
    bool clearExportPath = false,
  }) {
    return ReportFlowState(
      step: step ?? this.step,
      parkId: clearPark ? null : parkId ?? this.parkId,
      startDate: clearStart ? null : startDate ?? this.startDate,
      endDate: clearEnd ? null : endDate ?? this.endDate,
      categories: categories ?? this.categories,
      validationError:
          clearValidation ? null : validationError ?? this.validationError,
      serviceError:
          clearServiceError ? null : serviceError ?? this.serviceError,
      report: clearReport ? null : report ?? this.report,
      exportPhase: exportPhase ?? this.exportPhase,
      exportError: clearExportError ? null : exportError ?? this.exportError,
      exportPath: clearExportPath ? null : exportPath ?? this.exportPath,
    );
  }
}

class ReportFlowController extends Notifier<ReportFlowState> {
  static const _validator = ReportFilterValidator();

  @override
  ReportFlowState build() {
    final user = ref.watch(currentUserProvider);
    return ReportFlowState.initial(user);
  }

  void setPark(String? parkId) {
    state = state.copyWith(
      parkId: parkId,
      clearPark: parkId == null,
      clearValidation: true,
      clearServiceError: true,
    );
  }

  void setStartDate(DateTime? value) {
    state = state.copyWith(
      startDate: value,
      clearStart: value == null,
      clearValidation: true,
      clearServiceError: true,
    );
  }

  void setEndDate(DateTime? value) {
    state = state.copyWith(
      endDate: value,
      clearEnd: value == null,
      clearValidation: true,
      clearServiceError: true,
    );
  }

  void toggleCategory(IncidentCategory category) {
    final next = List<IncidentCategory>.from(state.categories);
    if (next.contains(category)) {
      next.remove(category);
    } else {
      next
        ..add(category)
        ..sort((a, b) => a.index.compareTo(b.index));
    }
    state = state.copyWith(categories: next, clearValidation: true);
  }

  void changeFilters() {
    state = state.copyWith(
      step: ReportStep.filters,
      clearValidation: true,
      clearServiceError: true,
      exportPhase: ReportExportPhase.idle,
      clearExportError: true,
      clearExportPath: true,
    );
  }

  void openExport() {
    if (state.report == null) {
      state = state.copyWith(
        exportPhase: ReportExportPhase.failure,
        exportError: ReportMessages.exportBeforeReport,
      );
      return;
    }
    state = state.copyWith(
      step: ReportStep.export,
      exportPhase: ReportExportPhase.idle,
      clearExportError: true,
      clearExportPath: true,
    );
  }

  void closeExport() {
    if (state.report == null) {
      changeFilters();
      return;
    }
    state = state.copyWith(
      step: ReportStep.results,
      exportPhase: ReportExportPhase.idle,
      clearExportError: true,
      clearExportPath: true,
    );
  }

  Future<void> generate() async {
    final user = ref.read(currentUserProvider);
    final authorized =
        ReportAccessPolicy.permittedParks(user).map((park) => park.id).toSet();
    final error = _validator.validate(
      parkId: state.parkId,
      startDate: state.startDate,
      endDate: state.endDate,
      categories: state.categories,
      authorizedParkIds: authorized,
    );
    if (error != null) {
      state = state.copyWith(
        step: ReportStep.filters,
        validationError: error,
        clearServiceError: true,
      );
      return;
    }

    final criteria = ReportCriteria(
      parkId: state.parkId!,
      startDate: state.startDate!,
      endDate: state.endDate!,
      categories: List<IncidentCategory>.from(state.categories),
    );
    final userId = user.id;
    state = state.copyWith(
      step: ReportStep.generating,
      clearValidation: true,
      clearServiceError: true,
      clearReport: true,
      exportPhase: ReportExportPhase.idle,
      clearExportError: true,
      clearExportPath: true,
    );

    try {
      final report =
          await ref.read(reportRepositoryProvider).generateReport(criteria);
      if (!ref.mounted || ref.read(currentUserProvider).id != userId) return;
      state = state.copyWith(step: ReportStep.results, report: report);
    } on ValidationException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        step: ReportStep.filters,
        validationError: error.message,
        clearReport: true,
      );
    } on PermissionException catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        step: ReportStep.filters,
        validationError: error.message,
        clearReport: true,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        step: ReportStep.unavailable,
        serviceError: ReportMessages.serviceUnavailable,
        clearReport: true,
      );
    }
  }

  Future<void> retry() => generate();

  Future<void> exportPdf() => _export(pdf: true);

  Future<void> exportCsv() => _export(pdf: false);

  Future<void> _export({required bool pdf}) async {
    final report = state.report;
    if (report == null) {
      state = state.copyWith(
        exportPhase: ReportExportPhase.failure,
        exportError: ReportMessages.exportBeforeReport,
        clearExportPath: true,
      );
      return;
    }

    state = state.copyWith(
      exportPhase: ReportExportPhase.exporting,
      clearExportError: true,
      clearExportPath: true,
    );
    try {
      final service = ref.read(reportExportServiceProvider);
      final path = pdf
          ? await service.exportPdf(report)
          : await service.exportCsv(report);
      if (!ref.mounted) return;
      if (!identical(state.report, report)) return;
      state = state.copyWith(
        exportPhase: ReportExportPhase.success,
        exportPath: path,
        clearExportError: true,
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = state.copyWith(
        exportPhase: ReportExportPhase.failure,
        exportError: pdf ? ReportMessages.pdfFailed : ReportMessages.csvFailed,
        clearExportPath: true,
      );
    }
  }
}

final reportFlowControllerProvider =
    NotifierProvider<ReportFlowController, ReportFlowState>(
  ReportFlowController.new,
);
