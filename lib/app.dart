import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/routing/app_router.dart';
import 'core/sync/auto_sync_coordinator.dart';
import 'core/theme/app_theme.dart';

class WildlifeApp extends ConsumerWidget {
  const WildlifeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(autoSyncCoordinatorProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Wildlife Conservation System',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
