import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/enums/app_enums.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/role_nav.dart';
import '../../../../shared/models/app_user.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../application/admin_providers.dart';
import '../../data/demo_staff_seed.dart';
import '../../data/user_admin_service.dart';

/// System-admin home: manage staff accounts (create / edit / delete).
///
/// Supporting feature only — not one of the four graded business use cases
/// (AGENTS.md §35).
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('WildGuard · Admin'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Load demo staff',
            icon: const Icon(Icons.group_add_outlined),
            onPressed: () => _seedDemoStaff(context, ref),
          ),
        ],
      ),
      bottomNavigationBar: const WildGuardNavBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.adminUserNew),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add user'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminUsersProvider),
          child: usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => _ErrorState(
              onRetry: () => ref.invalidate(adminUsersProvider),
            ),
            data: (users) => users.isEmpty
                ? _EmptyState(onLoadDemo: () => _seedDemoStaff(context, ref))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: users.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      if (i == 0) return _CountHeader(count: users.length);
                      return _UserTile(
                        user: users[i - 1],
                        onEdit: () => context
                            .push(AppRoutes.adminUserEditFor(users[i - 1].id)),
                        onDelete: () =>
                            _confirmDelete(context, ref, users[i - 1]),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    AppUser user,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text(
          '${user.name} (${user.username}) will lose access to WildGuard. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final service = ref.read(userAdminServiceProvider);
    try {
      await service?.deleteUser(user);
      ref.invalidate(adminUsersProvider);
      messenger.showSnackBar(
        SnackBar(content: Text('${user.name} deleted.')),
      );
    } on UserAdminException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete the user.')),
      );
    }
  }

  /// Creates the canonical demo staff (manager, 2 rangers, CLO, researcher) so
  /// the dashboard has real content to work with. Idempotent — existing
  /// accounts are skipped. Shows a blocking progress dialog while it runs.
  Future<void> _seedDemoStaff(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('Loading demo staff…')),
          ],
        ),
      ),
    );
    try {
      await ensureDemoStaff();
      ref.invalidate(adminUsersProvider);
      if (context.mounted) Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Demo staff loaded.')),
      );
    } catch (_) {
      if (context.mounted) Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not load demo staff.')),
      );
    }
  }
}

class _CountHeader extends StatelessWidget {
  const _CountHeader({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          '$count staff account${count == 1 ? '' : 's'}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      );
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.onEdit,
    required this.onDelete,
  });

  final AppUser user;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: UserAvatar(user: user, radius: 24),
        title: Text(
          user.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(user.username,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            _RoleChip(role: user.role),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: onEdit,
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          role.displayLabel,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onLoadDemo});

  final VoidCallback onLoadDemo;

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          const SizedBox(height: 110),
          const Icon(Icons.group_outlined, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'No staff accounts yet.\nAdd a user, or load the demo staff to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: OutlinedButton.icon(
              onPressed: onLoadDemo,
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Load demo staff'),
            ),
          ),
        ],
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.error_outline, size: 56, color: AppColors.error),
          const SizedBox(height: 12),
          const Center(
            child: Text('Could not load users.',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 12),
          Center(
            child: OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ),
        ],
      );
}
