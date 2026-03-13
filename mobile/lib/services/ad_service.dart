import "package:flutter/foundation.dart";
import "package:google_mobile_ads/google_mobile_ads.dart";

/// Ad Unit IDs — test IDs by default, override via --dart-define
const _bannerAdUnitId = String.fromEnvironment(
  "ADMOB_BANNER_ID",
  defaultValue: "ca-app-pub-3940256099942544/6300978111", // Google test banner
);

const _rewardedAdUnitId = String.fromEnvironment(
  "ADMOB_REWARDED_ID",
  defaultValue: "ca-app-pub-3940256099942544/5224354917", // Google test rewarded
);

class AdService {
  AdService._();
  static final instance = AdService._();

  bool _initialized = false;
  RewardedAd? _rewardedAd;
  bool _isLoadingRewarded = false;

  /// Initialize the Mobile Ads SDK. Call once at app startup.
  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    _preloadRewardedAd();
  }

  /// Creates an adaptive banner ad for the given width.
  Future<BannerAd?> createBannerAd({required double width}) async {
    if (!_initialized) return null;

    final adSize = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width.truncate(),
    );
    if (adSize == null) return null;

    final banner = BannerAd(
      adUnitId: _bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          debugPrint("Banner ad failed to load: $error");
          ad.dispose();
        },
      ),
    );

    await banner.load();
    return banner;
  }

  /// Pre-load a rewarded ad so it's ready when needed.
  void _preloadRewardedAd() {
    if (_isLoadingRewarded || _rewardedAd != null) return;
    _isLoadingRewarded = true;

    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoadingRewarded = false;
        },
        onAdFailedToLoad: (error) {
          debugPrint("Rewarded ad failed to load: $error");
          _isLoadingRewarded = false;
        },
      ),
    );
  }

  /// Whether a rewarded ad is ready to show.
  bool get isRewardedAdReady => _rewardedAd != null;

  /// Shows a rewarded ad. Calls [onReward] when the user earns the reward.
  /// Returns false if no ad is available.
  Future<bool> showRewardedAd({required VoidCallback onReward}) async {
    final ad = _rewardedAd;
    if (ad == null) return false;

    _rewardedAd = null; // consumed

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _preloadRewardedAd(); // preload next one
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint("Rewarded ad failed to show: $error");
        ad.dispose();
        _preloadRewardedAd();
      },
    );

    ad.show(onUserEarnedReward: (_, __) => onReward());
    return true;
  }
}
