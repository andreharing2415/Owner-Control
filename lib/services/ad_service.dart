import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Singleton responsável por inicializar o SDK de anúncios,
/// criar banners adaptativos e gerenciar rewarded ads.
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // IDs de teste do Google — substituir por IDs reais antes de publicar.
  // Usar `--dart-define=BANNER_AD_ID=ca-app-pub-xxx` para override.
  static const _bannerAdUnitId = String.fromEnvironment(
    'BANNER_AD_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111', // test
  );

  static const _rewardedAdUnitId = String.fromEnvironment(
    'REWARDED_AD_ID',
    defaultValue: 'ca-app-pub-3940256099942544/5224354917', // test
  );

  bool _initialized = false;
  RewardedAd? _rewardedAd;

  bool get isRewardedAdReady => _rewardedAd != null;

  /// Inicializa o Mobile Ads SDK. Chamar uma única vez no main().
  Future<void> initialize() async {
    if (_initialized) return;
    try {
      await MobileAds.instance.initialize();
      _initialized = true;
      _loadRewardedAd();
      debugPrint('[AdService] SDK inicializado');
    } catch (e) {
      debugPrint('[AdService] falha ao inicializar: $e');
    }
  }

  /// Cria um banner adaptativo para a largura informada.
  Future<BannerAd> createBannerAd({required int width}) async {
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width)
        ?? AdSize.banner;
    return BannerAd(
      adUnitId: _bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdFailedToLoad: (ad, error) {
          debugPrint('[AdService] banner falhou: $error');
          ad.dispose();
        },
      ),
    );
  }

  // ─── Rewarded ───────────────────────────────────────────────────────────────

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          debugPrint('[AdService] rewarded ad carregado');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          debugPrint('[AdService] rewarded ad falhou: $error');
        },
      ),
    );
  }

  /// Exibe o rewarded ad. Chama [onReward] quando o usuário completa.
  /// Retorna `true` se o ad foi exibido, `false` se não estava pronto.
  Future<bool> showRewardedAd({required void Function(int amount) onReward}) async {
    final ad = _rewardedAd;
    if (ad == null) return false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd(); // pré-carrega o próximo
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('[AdService] rewarded show error: $error');
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
      },
    );

    await ad.show(
      onUserEarnedReward: (_, reward) => onReward(reward.amount.toInt()),
    );
    return true;
  }
}
