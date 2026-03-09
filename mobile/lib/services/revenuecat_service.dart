import "dart:io" show Platform;
import "package:flutter/foundation.dart";
import "package:purchases_flutter/purchases_flutter.dart";

/// RevenueCat service for managing in-app subscriptions.
///
/// Entitlement: "premium"
/// Product: "dono_da_obra_monthly" (R$149,90/mês)
class RevenueCatService {
  static const _entitlementId = "premium";

  // TODO: Replace with actual RevenueCat API keys before release
  static const _androidApiKey = "goog_YOUR_REVENUECAT_API_KEY";
  static const _iosApiKey = "appl_YOUR_REVENUECAT_API_KEY";

  static bool _initialized = false;

  /// Initialize RevenueCat SDK. Call once after login.
  static Future<void> init(String userId) async {
    if (_initialized || kIsWeb) return;

    final apiKey = Platform.isIOS ? _iosApiKey : _androidApiKey;

    final configuration = PurchasesConfiguration(apiKey)
      ..appUserID = userId;

    await Purchases.configure(configuration);
    _initialized = true;
  }

  /// Check if user has active premium entitlement.
  static Future<bool> isPremium() async {
    if (kIsWeb || !_initialized) return false;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.all[_entitlementId]?.isActive ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Show available offerings and purchase the default package.
  /// Returns true if purchase succeeded.
  static Future<bool> purchase() async {
    if (kIsWeb || !_initialized) return false;
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null || current.availablePackages.isEmpty) {
        return false;
      }

      final package = current.availablePackages.first;
      final result = await Purchases.purchasePackage(package);
      return result.entitlements.all[_entitlementId]?.isActive ?? false;
    } on PurchasesErrorCode {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Restore previous purchases (e.g. after reinstall).
  /// Returns true if premium entitlement is active after restore.
  static Future<bool> restore() async {
    if (kIsWeb || !_initialized) return false;
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.all[_entitlementId]?.isActive ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Log out from RevenueCat (call on app logout).
  static Future<void> logout() async {
    if (kIsWeb || !_initialized) return;
    try {
      if (await Purchases.isAnonymous == false) {
        await Purchases.logOut();
      }
    } catch (_) {}
    _initialized = false;
  }
}
