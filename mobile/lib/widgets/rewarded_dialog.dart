import "package:flutter/material.dart";

import "../services/ad_service.dart";
import "../services/api_client.dart";
import "../screens/subscription/paywall_screen.dart";

/// Dialog shown when a free user hits a feature limit.
/// Offers two choices: watch a rewarded video (3 extra uses) or view plans.
class RewardedDialog extends StatefulWidget {
  const RewardedDialog({
    super.key,
    required this.feature,
    required this.featureLabel,
    required this.api,
  });

  /// Feature key sent to the backend (e.g. "ai_visual", "checklist_inteligente").
  final String feature;

  /// Human-readable label for the feature (e.g. "Análise Visual IA").
  final String featureLabel;

  /// API client to call reward-usage endpoint.
  final ApiClient api;

  /// Shows the dialog. Returns true if the user earned extra uses.
  static Future<bool> show(
    BuildContext context, {
    required String feature,
    required String featureLabel,
    required ApiClient api,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => RewardedDialog(
        feature: feature,
        featureLabel: featureLabel,
        api: api,
      ),
    );
    return result ?? false;
  }

  @override
  State<RewardedDialog> createState() => _RewardedDialogState();
}

class _RewardedDialogState extends State<RewardedDialog> {
  bool _loading = false;

  Future<void> _watchAd() async {
    setState(() => _loading = true);

    final shown = await AdService.instance.showRewardedAd(
      onReward: () async {
        try {
          await widget.api.rewardUsage(widget.feature);
        } catch (_) {
          // Best effort — even if backend fails, user saw the ad
        }
      },
    );

    if (!mounted) return;

    if (shown) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("3 usos extras liberados!")),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Anúncio não disponível no momento. Tente novamente.")),
      );
      setState(() => _loading = false);
    }
  }

  void _viewPlans() {
    Navigator.pop(context, false);
    PaywallScreen.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.lock_outline, color: Colors.orange.shade700),
          const SizedBox(width: 8),
          const Expanded(child: Text("Limite atingido")),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Você usou seu limite de ${widget.featureLabel} no plano gratuito.",
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _loading ? null : _watchAd,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.play_circle_outline),
            label: const Text("Assistir vídeo (3 usos extras)"),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _viewPlans,
            icon: const Icon(Icons.star_outline),
            label: const Text("Ver planos — recursos ilimitados"),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }
}
