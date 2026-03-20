import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';

import '../providers/subscription_provider.dart';
import '../services/ad_service.dart';

/// Banner adaptativo que só aparece para planos com `showAds == true`.
/// Para planos premium retorna um widget vazio (SizedBox.shrink).
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final showAds = context.watch<SubscriptionProvider>().showAds;
    if (showAds && _bannerAd == null) {
      _loadAd();
    } else if (!showAds && _bannerAd != null) {
      _bannerAd?.dispose();
      _bannerAd = null;
      _isLoaded = false;
    }
  }

  Future<void> _loadAd() async {
    final width = (MediaQuery.of(context).size.width).truncate();
    final ad = await AdService.instance.createBannerAd(width: width);
    if (!mounted) { ad.dispose(); return; }
    _bannerAd = ad;
    await ad.load();
    if (mounted) setState(() => _isLoaded = true);
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showAds = context.watch<SubscriptionProvider>().showAds;
    if (!showAds || !_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }
    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
