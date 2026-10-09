import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_map.dart';
import '../../../../shared/providers/providers.dart';
import '../../domain/field_incident_draft.dart';
import '../providers/incident_providers.dart';
import '../widgets/cached_park_map.dart';
import '../widgets/uc02_widgets.dart';

/// UC02-S01 – Screen 3: Location & Description.
///
/// Normal path records the current GPS position (locationSource = gps). If GPS
/// is unavailable the ranger can retry or set the location manually on the
/// cached map view (locationSource = manual). Coordinates are never fabricated.
class IncidentLocationScreen extends ConsumerStatefulWidget {
  const IncidentLocationScreen({super.key});

  @override
  ConsumerState<IncidentLocationScreen> createState() =>
      _IncidentLocationScreenState();
}

class _IncidentLocationScreenState
    extends ConsumerState<IncidentLocationScreen> {
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _descriptionController = TextEditingController();
  late DateTime _observedAt;

  @override
  void initState() {
    super.initState();
    final form = ref.read(incidentFormControllerProvider);
    _observedAt = form.observedAt ?? DateTime.now();
    if (form.hasLocation) {
      _latController.text = form.latitude!.toStringAsFixed(6);
      _lngController.text = form.longitude!.toStringAsFixed(6);
    }
    _descriptionController.text = form.description;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = ref.read(incidentFormControllerProvider);
      if (!current.hasLocation && !current.isLocating) {
        ref.read(incidentFormControllerProvider.notifier).captureGpsLocation();
      }
    });
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(incidentFormControllerProvider);
    final controller = ref.read(incidentFormControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
          title: const Text('Incident Details'),
          leading: const BackButton()),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionLabel('Incident location'),
          if (form.hasLocation)
            Card(
              child: ListTile(
                leading: Icon(
                  form.locationSource == LocationSource.gps
                      ? Icons.gps_fixed
                      : Icons.edit_location_alt,
                  color: form.locationSource == LocationSource.gps
                      ? AppColors.success
                      : AppColors.warning,
                ),
                title: Text(
                  form.locationSource == LocationSource.gps
                      ? 'GPS location'
                      : 'Manual location',
                ),
                subtitle: Text(
                  '${form.latitude!.toStringAsFixed(5)}, '
                  '${form.longitude!.toStringAsFixed(5)}',
                ),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.location_off, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('No location set yet.')),
                    TextButton(
                      onPressed:
                          form.isLocating ? null : controller.captureGpsLocation,
                      child: const Text('Use GPS'),
                    ),
                  ],
                ),
              ),
            ),
          if (form.isLocating)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Capturing GPS...'),
            ),
          if (form.gpsCapturedAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Captured ${DateFormat('dd MMM yyyy, HH:mm').format(form.gpsCapturedAt!)}',
                key: const Key('gps-capture-time'),
              ),
            ),
          if (form.gpsError != null) ...[
            const SizedBox(height: 8),
            _GpsErrorCard(
              message: form.gpsError!,
              onRetry: controller.captureGpsLocation,
              onManual: _openManualLocation,
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: form.isLocating ? null : controller.captureGpsLocation,
            icon: const Icon(Icons.my_location),
            label: const Text('Use current GPS location'),
          ),
          OutlinedButton.icon(
            onPressed: _openManualLocation,
            icon: const Icon(Icons.map),
            label: const Text('Set location manually'),
          ),
          const SizedBox(height: 16),
          const SectionLabel('Observation time'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(DateFormat('dd MMM yyyy, HH:mm').format(_observedAt)),
              trailing: const Icon(Icons.edit_calendar, size: 20),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _observedAt,
                  firstDate: DateTime.now().subtract(const Duration(days: 7)),
                  lastDate: DateTime.now(),
                );
                if (date == null || !context.mounted) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_observedAt),
                );
                if (time == null) return;
                final next =
                    DateTime(date.year, date.month, date.day, time.hour, time.minute);
                setState(() => _observedAt = next);
                controller.setObservationTime(next);
              },
            ),
          ),
          const SizedBox(height: 16),
          const SectionLabel('Description'),
          TextField(
            key: const Key('description-field'),
            controller: _descriptionController,
            decoration: const InputDecoration(
              hintText: 'Wire snare found beside animal trail.',
              helperText: 'Required. 160 characters at most.',
              labelText: 'Short description',
            ),
            maxLength: FieldIncidentDraft.descriptionMaxLength,
            minLines: 3,
            maxLines: 6,
            textInputAction: TextInputAction.done,
            onChanged: controller.setDescription,
          ),
          if (form.evidence.hasPhoto)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo, color: AppColors.primary),
              title: const Text('Photograph attached'),
              subtitle: Text(form.evidence.evidence?.filename ?? 'Photo ready'),
            ),
          const SizedBox(height: 8),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: PrimaryActionButton(
            label: 'Continue',
            onPressed: !(form.hasLocation && form.hasDescription)
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          !form.hasLocation
                              ? 'Record a GPS or manual location to continue.'
                              : 'A description is required to continue.',
                        ),
                      ),
                    );
                  }
                : () => context.push(AppRoutes.incidentReview),
          ),
        ),
      ),
    );
  }

  void _openManualLocation() {
    final controller = ref.read(incidentFormControllerProvider.notifier);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ManualLocationSheet(
        initialLat: _latController.text,
        initialLng: _lngController.text,
        onConfirm: (lat, lng) {
          controller.setManualLocation(lat, lng);
          setState(() {
            _latController.text = lat.toStringAsFixed(6);
            _lngController.text = lng.toStringAsFixed(6);
          });
        },
      ),
    );
  }
}

/// GPS unavailable card: retry or fall back to the manual cached map view.
class _GpsErrorCard extends StatelessWidget {
  const _GpsErrorCard({
    required this.message,
    required this.onRetry,
    required this.onManual,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.gps_off, color: AppColors.warning, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                    'GPS unavailable. You can retry, or set the location manually.',
                    style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry GPS'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onManual,
                  icon: const Icon(Icons.map, size: 18),
                  label: const Text('Set manually'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Manual location fallback. Uses the park-centred cached map view with a
/// draggable pin; the confirmed point is stored with locationSource = manual.
class _ManualLocationSheet extends ConsumerStatefulWidget {
  const _ManualLocationSheet({
    required this.initialLat,
    required this.initialLng,
    required this.onConfirm,
  });

  final String initialLat;
  final String initialLng;
  final void Function(double lat, double lng) onConfirm;

  @override
  ConsumerState<_ManualLocationSheet> createState() =>
      _ManualLocationSheetState();
}

class _ManualLocationSheetState extends ConsumerState<_ManualLocationSheet> {
  late final TextEditingController _lat;
  late final TextEditingController _lng;

  @override
  void initState() {
    super.initState();
    _lat = TextEditingController(text: widget.initialLat);
    _lng = TextEditingController(text: widget.initialLng);
  }

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.map, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Set location on cached map',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Text(
            'Tap or drag the pin to where you found the incident.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final lat = double.tryParse(_lat.text.trim());
            final lng = double.tryParse(_lng.text.trim());
            void onPoint(({double latitude, double longitude}) point) {
              setState(() {
                _lat.text = point.latitude.toStringAsFixed(6);
                _lng.text = point.longitude.toStringAsFixed(6);
              });
            }

            return ref.watch(mapsEnabledProvider)
                ? GoogleLocationPicker(
                    latitude: lat, longitude: lng, onChanged: onPoint)
                : CachedParkMap(
                    latitude: lat, longitude: lng, onChanged: onPoint);
          }),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _lat,
                  decoration: const InputDecoration(labelText: 'Latitude'),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _lng,
                  decoration: const InputDecoration(labelText: 'Longitude'),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              final lat = double.tryParse(_lat.text.trim());
              final lng = double.tryParse(_lng.text.trim());
              if (lat == null ||
                  lng == null ||
                  !Validators.validCoordinates(lat, lng)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Enter valid latitude and longitude.')),
                );
                return;
              }
              Navigator.of(context).pop();
              widget.onConfirm(lat, lng);
            },
            icon: const Icon(Icons.check),
            label: const Text('Confirm location'),
          ),
        ],
      ),
    );
  }
}
