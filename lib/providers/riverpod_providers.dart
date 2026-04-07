import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../providers/owner_progress_provider.dart';
import '../providers/subscription_provider.dart';
import '../providers/tab_refresh_notifier.dart';
import '../services/auth_api_service.dart';
import '../services/obra_service.dart';
import '../services/owner_progress_service.dart';

/// Providers Riverpod por domínio com rollout incremental.
final authApiServiceProvider = Provider<AuthApiService>((ref) {
  return ApiAuthService();
});

final obraServiceProvider = Provider<ObraService>((ref) {
  return ApiObraService();
});

final ownerProgressServiceProvider = Provider<OwnerProgressService>((ref) {
  return ApiOwnerProgressService();
});

final authProvider = ChangeNotifierProvider<AuthProvider>((ref) {
  return AuthProvider(authApiService: ref.watch(authApiServiceProvider));
});

final ownerProgressProvider = ChangeNotifierProvider<OwnerProgressProvider>((ref) {
  return OwnerProgressProvider();
});

final subscriptionProvider = ChangeNotifierProvider<SubscriptionProvider>((ref) {
  return SubscriptionProvider();
});

final tabRefreshProvider = ChangeNotifierProvider<TabRefreshNotifier>((ref) {
  return TabRefreshNotifier();
});
