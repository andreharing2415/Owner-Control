class NativePurchasePayload {
  NativePurchasePayload({
    required this.plan,
    required this.platform,
    required this.productId,
    required this.purchaseId,
    this.purchaseToken,
  });

  final String plan;
  final String platform;
  final String productId;
  final String purchaseId;
  final String? purchaseToken;

  Map<String, dynamic> toJson() {
    return {
      "plan": plan,
      "platform": platform,
      "product_id": productId,
      "purchase_id": purchaseId,
      "purchase_token": purchaseToken,
    };
  }
}
