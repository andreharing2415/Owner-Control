import "package:appsflyer_sdk/appsflyer_sdk.dart";
import "package:flutter/foundation.dart";

const _devKey = String.fromEnvironment(
  "APPSFLYER_DEV_KEY",
  defaultValue: "", // Set via --dart-define in production
);

const _appId = String.fromEnvironment(
  "APPSFLYER_APP_ID",
  defaultValue: "", // iOS App ID (e.g. "123456789")
);

class AppsFlyerService {
  AppsFlyerService._();
  static final instance = AppsFlyerService._();

  AppsflyerSdk? _sdk;
  bool _initialized = false;

  /// Initialize AppsFlyer SDK. Call once at app startup.
  Future<void> initialize() async {
    if (_initialized || _devKey.isEmpty) {
      if (_devKey.isEmpty) {
        debugPrint("AppsFlyer: devKey not set, skipping initialization");
      }
      return;
    }

    final options = AppsFlyerOptions(
      afDevKey: _devKey,
      appId: _appId,
      showDebug: kDebugMode,
      timeToWaitForATTUserAuthorization: 10,
    );

    _sdk = AppsflyerSdk(options);
    await _sdk!.initSdk(
      registerConversionDataCallback: true,
      registerOnAppOpenAttributionCallback: true,
    );
    _initialized = true;
  }

  /// Track user login event.
  void trackLogin({String? method}) {
    _logEvent("af_login", {"method": method ?? "email"});
  }

  /// Track subscription event.
  void trackSubscription({
    required String plan,
    required double revenue,
    String currency = "BRL",
  }) {
    _logEvent("af_subscribe", {
      "af_revenue": revenue,
      "af_currency": currency,
      "af_content_id": plan,
    });
  }

  /// Track ad view (banner shown).
  void trackAdView({String? placement}) {
    _logEvent("af_ad_view", {"placement": placement ?? "inline_banner"});
  }

  /// Track rewarded ad completion.
  void trackRewardedComplete({required String feature}) {
    _logEvent("af_rewarded_complete", {"feature": feature});
  }

  /// Track feature usage (AI visual, checklist, etc).
  void trackFeatureUse({required String feature}) {
    _logEvent("af_feature_use", {"feature": feature});
  }

  void _logEvent(String name, Map<String, dynamic> values) {
    if (!_initialized || _sdk == null) return;
    _sdk!.logEvent(name, values);
  }
}
