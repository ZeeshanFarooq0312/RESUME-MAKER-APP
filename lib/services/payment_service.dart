enum PaymentResult { success, cancelled, failed }

/// Handles the $3 "2 downloads" purchase.
///
/// This is a mock implementation — it lets the paywall/credit-gating flow
/// be built and tested without a Google Play Console account. When Play
/// Billing is set up, replace the body of [purchaseDownloadPack] with a
/// real purchase flow using `package:in_app_purchase`
/// (buyConsumable/buyNonConsumable against a configured product id) and
/// resolve to [PaymentResult.success] only after the purchase is verified.
/// No other call site needs to change.
class PaymentService {
  static const downloadPackPriceUsd = 3.0;
  static const downloadsPerPack = 2;

  Future<PaymentResult> purchaseDownloadPack() async {
    // TODO(billing): swap for real Google Play Billing purchase + receipt
    // verification once a Play Console product ("download_pack_2") exists.
    await Future.delayed(const Duration(milliseconds: 900));
    return PaymentResult.success;
  }
}
