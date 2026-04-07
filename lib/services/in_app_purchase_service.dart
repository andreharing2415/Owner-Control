import "dart:async";

import "package:flutter/foundation.dart";
import "package:in_app_purchase/in_app_purchase.dart";

class NativePurchaseResult {
  NativePurchaseResult({
    required this.productId,
    required this.purchaseId,
    required this.purchaseToken,
  });

  final String productId;
  final String purchaseId;
  final String? purchaseToken;
}

class InAppPurchaseService {
  InAppPurchaseService({InAppPurchase? iap}) : _iap = iap ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  static const _productByPlan = {
    "essencial": String.fromEnvironment(
      "IAP_PRODUCT_ESSENCIAL",
      defaultValue: "br.mestredaobra.essencial.mensal",
    ),
    "completo": String.fromEnvironment(
      "IAP_PRODUCT_COMPLETO",
      defaultValue: "br.mestredaobra.completo.mensal",
    ),
  };

  Future<NativePurchaseResult> comprarPlano(String plano) async {
    final productId = _productByPlan[plano];
    if (productId == null || productId.isEmpty) {
      throw Exception("Plano invalido para compra nativa");
    }

    final available = await _iap.isAvailable();
    if (!available) {
      throw Exception("Compras in-app indisponiveis neste dispositivo");
    }

    final detailsResponse = await _iap.queryProductDetails({productId});
    if (detailsResponse.productDetails.isEmpty) {
      throw Exception("Produto in-app nao encontrado");
    }
    final product = detailsResponse.productDetails.first;

    final completer = Completer<NativePurchaseResult>();
    late final StreamSubscription<List<PurchaseDetails>> sub;
    sub = _iap.purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        if (purchase.productID != productId) continue;

        if (purchase.status == PurchaseStatus.error) {
          if (!completer.isCompleted) {
            completer.completeError(
              Exception(purchase.error?.message ?? "Falha na compra in-app"),
            );
          }
        }

        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          if (purchase.pendingCompletePurchase) {
            await _iap.completePurchase(purchase);
          }
          if (!completer.isCompleted) {
            completer.complete(
              NativePurchaseResult(
                productId: productId,
                purchaseId: purchase.purchaseID ?? "",
                purchaseToken: purchase.verificationData.serverVerificationData,
              ),
            );
          }
        }
      }
    });

    try {
      final started = await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
      if (!started) {
        throw Exception("Nao foi possivel iniciar a compra");
      }

      return await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw TimeoutException("Compra nao confirmada em tempo habil"),
      );
    } finally {
      await sub.cancel();
    }
  }

  String platform() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return "play_store";
    }
    return "app_store";
  }
}
