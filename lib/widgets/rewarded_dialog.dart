import 'package:flutter/material.dart';

import '../api/api.dart';
import '../services/ad_service.dart';

/// Dialog que oferece ao usuário assistir a um rewarded ad em troca de
/// créditos extras (ex.: +1 upload de documento, +1 análise IA).
///
/// Uso:
/// ```dart
/// final assistiu = await RewardedDialog.show(context, feature: 'doc_upload');
/// ```
class RewardedDialog extends StatefulWidget {
  const RewardedDialog({super.key, required this.feature});

  final String feature;

  /// Exibe o dialog e retorna `true` se o usuário assistiu e recebeu o bônus.
  static Future<bool> show(BuildContext context, {required String feature}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => RewardedDialog(feature: feature),
    );
    return result ?? false;
  }

  @override
  State<RewardedDialog> createState() => _RewardedDialogState();
}

class _RewardedDialogState extends State<RewardedDialog> {
  bool _loading = false;

  Future<void> _assistir() async {
    setState(() => _loading = true);
    final exibiu = await AdService.instance.showRewardedAd(
      onReward: (amount) async {
        try {
          await ApiClient().rewardUsage(widget.feature);
        } catch (_) {}
      },
    );
    if (!mounted) return;
    if (exibiu) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anúncio não disponível. Tente novamente.')),
      );
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.card_giftcard_rounded, size: 40, color: scheme.primary),
      title: const Text('Ganhe crédito extra!'),
      content: const Text(
        'Assista a um vídeo curto e ganhe 1 uso extra desta funcionalidade.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Agora não'),
        ),
        FilledButton.icon(
          onPressed: _loading ? null : _assistir,
          icon: _loading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.play_circle_outline),
          label: const Text('Assistir'),
        ),
      ],
    );
  }
}
