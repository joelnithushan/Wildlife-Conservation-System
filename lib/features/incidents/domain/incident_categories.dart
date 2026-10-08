import 'package:flutter/material.dart';

import '../../../core/enums/app_enums.dart';

/// UC02 field-facing incident categories (presentation-level, frozen design).
///
/// These are the categories a Ranger actually picks from in the field. Each one
/// maps onto a shared [IncidentCategory] so persistence, sync payloads, UC02
/// review screens and UC04 analytics all keep using the shared enum — no shared
/// code changes, no raw strings scattered around.
enum IncidentReportCategory {
  snare(IncidentCategory.poaching),
  carcass(IncidentCategory.animalInjury),
  illegalCampsite(IncidentCategory.illegalLogging),
  suspiciousFootprints(IncidentCategory.humanWildlifeConflict),
  other(IncidentCategory.other);

  const IncidentReportCategory(this.shared);

  /// The shared enum value persisted/synced for this category.
  final IncidentCategory shared;

  static IncidentReportCategory fromShared(IncidentCategory shared) =>
      IncidentReportCategory.values.firstWhere(
        (c) => c.shared == shared,
        orElse: () => IncidentReportCategory.other,
      );

  String get label => switch (this) {
        IncidentReportCategory.snare => 'Snare',
        IncidentReportCategory.carcass => 'Carcass',
        IncidentReportCategory.illegalCampsite => 'Illegal Campsite',
        IncidentReportCategory.suspiciousFootprints => 'Footprints',
        IncidentReportCategory.other => 'Other',
      };

  String get hint => switch (this) {
        IncidentReportCategory.snare => 'Wire or rope snare set for animals',
        IncidentReportCategory.carcass => 'Dead animal found on patrol',
        IncidentReportCategory.illegalCampsite => 'Unauthorised camp or structures',
        IncidentReportCategory.suspiciousFootprints => 'Human tracks near protected areas',
        IncidentReportCategory.other => 'Anything else worth reporting',
      };

  IconData get icon => switch (this) {
        IncidentReportCategory.snare => Icons.gavel,
        IncidentReportCategory.carcass => Icons.pets,
        IncidentReportCategory.illegalCampsite => Icons.night_shelter,
        IncidentReportCategory.suspiciousFootprints => Icons.directions_walk,
        IncidentReportCategory.other => Icons.more_horiz,
      };
}
