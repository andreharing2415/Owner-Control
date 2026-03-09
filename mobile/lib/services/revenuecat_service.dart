import "package:url_launcher/url_launcher.dart";

import "api_client.dart";

/// Stripe Checkout service for managing subscriptions.
///
/// Opens Stripe Checkout in the browser. After payment, webhook updates
/// the user's plan on the backend.
class StripeService {
  /// Creates a Stripe Checkout session and opens it in the browser.
  /// Returns true if the URL was launched successfully.
  static Future<bool> checkout(ApiClient api) async {
    try {
      final result = await api.createCheckoutSession();
      final url = result["checkout_url"] as String?;
      if (url == null || url.isEmpty) return false;

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
