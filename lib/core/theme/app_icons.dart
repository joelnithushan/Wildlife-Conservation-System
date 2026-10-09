import 'package:flutter/material.dart';

/// Single source of truth for iconography across WildGuard.
///
/// Use these instead of referencing `Icons.*` directly so the same concept is
/// drawn with the same glyph everywhere (§26/§52 UI consistency). Feature icons
/// come in an outlined (unselected) + filled (selected) pair to match the
/// bottom-navigation convention.
abstract final class AppIcons {
  // --- Primary feature areas (outlined = unselected, filled = selected) -----
  static const IconData home = Icons.dashboard_outlined;
  static const IconData homeFilled = Icons.dashboard;

  static const IconData patrol = Icons.route_outlined;
  static const IconData patrolFilled = Icons.route;

  static const IconData incidents = Icons.report_gmailerrorred_outlined;
  static const IconData incidentsFilled = Icons.report;

  static const IconData response = Icons.crisis_alert_outlined;
  static const IconData responseFilled = Icons.crisis_alert;

  static const IconData reports = Icons.insights_outlined;
  static const IconData reportsFilled = Icons.insights;

  static const IconData profile = Icons.person_outline;
  static const IconData profileFilled = Icons.person;

  static const IconData admin = Icons.group_outlined;
  static const IconData adminFilled = Icons.group;

  // --- Domain objects -------------------------------------------------------
  static const IconData animal = Icons.pets;
  static const IconData park = Icons.park_outlined;
  static const IconData route = Icons.route;
  static const IconData alert = Icons.crisis_alert;
  static const IconData community = Icons.groups_outlined;
  static const IconData person = Icons.person;
  static const IconData staff = Icons.badge_outlined;
  static const IconData reviewQueue = Icons.fact_check;

  // --- Status: review / verification ---------------------------------------
  static const IconData success = Icons.check_circle;
  static const IconData verified = Icons.verified;
  static const IconData rejected = Icons.block;
  static const IconData pendingReview = Icons.hourglass_empty;

  // --- Status: sync / connectivity -----------------------------------------
  static const IconData synced = Icons.cloud_done;
  static const IconData syncing = Icons.sync;
  static const IconData pendingSync = Icons.cloud_off;
  static const IconData online = Icons.wifi;
  static const IconData offline = Icons.wifi_off;

  // --- Status: messaging ----------------------------------------------------
  static const IconData error = Icons.error_outline;
  static const IconData warning = Icons.warning_amber_rounded;
  static const IconData info = Icons.info_outline;
  static const IconData blocked = Icons.block;

  // --- Location / GPS -------------------------------------------------------
  static const IconData gpsFixed = Icons.gps_fixed;
  static const IconData gpsOff = Icons.gps_off;
  static const IconData currentLocation = Icons.my_location;
  static const IconData manualLocation = Icons.edit_location_alt;
  static const IconData location = Icons.location_on;
  static const IconData map = Icons.map;

  // --- Evidence / media -----------------------------------------------------
  static const IconData camera = Icons.photo_camera;
  static const IconData photo = Icons.image_outlined;
  static const IconData noPhoto = Icons.no_photography;

  // --- Common actions -------------------------------------------------------
  static const IconData add = Icons.add;
  static const IconData edit = Icons.edit;
  static const IconData save = Icons.save;
  static const IconData send = Icons.send;
  static const IconData refresh = Icons.refresh;
  static const IconData logout = Icons.logout;
  static const IconData back = Icons.arrow_back;
  static const IconData forward = Icons.arrow_forward;
  static const IconData next = Icons.chevron_right;
  static const IconData close = Icons.close;
  static const IconData start = Icons.play_arrow;
  static const IconData schedule = Icons.schedule;
}
