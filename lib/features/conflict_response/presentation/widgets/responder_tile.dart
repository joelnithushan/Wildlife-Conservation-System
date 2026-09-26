import 'package:flutter/material.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/app_user.dart';

/// A selectable responder row on the Assign Responder screen. Unavailable
/// responders are shown disabled (never selectable).
class ResponderTile extends StatelessWidget {
  const ResponderTile({
    super.key,
    required this.responder,
    required this.selected,
    this.onTap,
  });

  final AppUser responder;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final available = responder.isAvailable;
    final roleLabel = responder.role == UserRole.ranger
        ? 'Ranger'
        : 'Community Liaison Officer';
    return Card(
      color: selected ? AppColors.primary.withValues(alpha: 0.08) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        enabled: available,
        onTap: available ? onTap : null,
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: Icon(
            responder.role == UserRole.ranger
                ? Icons.shield_outlined
                : Icons.groups_outlined,
            color: AppColors.primary,
          ),
        ),
        title: Text(responder.name),
        subtitle: Text(roleLabel),
        trailing: available
            ? (selected
                ? const Icon(Icons.check_circle, color: AppColors.primary)
                : const Icon(Icons.radio_button_unchecked))
            : const Text(
                'Unavailable',
                style: TextStyle(color: AppColors.error, fontSize: 12),
              ),
      ),
    );
  }
}
