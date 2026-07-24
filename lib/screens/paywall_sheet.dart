import 'package:flutter/material.dart';
import '../services/download_credits_service.dart';
import '../services/payment_service.dart';
import '../theme/app_theme.dart';

/// Shows the "buy downloads" paywall as a bottom sheet. Returns `true` if
/// the purchase succeeded (credits were added), `false`/`null` otherwise.
Future<bool?> showPaywallSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _PaywallSheet(),
  );
}

class _PaywallSheet extends StatefulWidget {
  const _PaywallSheet();

  @override
  State<_PaywallSheet> createState() => _PaywallSheetState();
}

class _PaywallSheetState extends State<_PaywallSheet> {
  final _paymentService = PaymentService();
  bool _processing = false;
  String? _error;

  Future<void> _pay() async {
    setState(() {
      _processing = true;
      _error = null;
    });
    final result = await _paymentService.purchaseDownloadPack();
    if (!mounted) return;
    if (result == PaymentResult.success) {
      await DownloadCreditsService.addCredits(PaymentService.downloadsPerPack);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _processing = false;
        _error = 'Payment failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.goldLight.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline, color: AppColors.slate900, size: 26),
            ),
            const SizedBox(height: 16),
            Text('Unlock downloads', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            const Text(
              'Preview is always free. Pay \$3 to download this resume as a PDF — that unlocks 2 downloads.',
              style: TextStyle(color: AppColors.slate600, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('2 downloads',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  Text('\$${PaymentService.downloadPackPriceUsd.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12.5)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _processing ? null : _pay,
                child: _processing
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Pay \$3 to unlock'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _processing ? null : () => Navigator.of(context).pop(false),
                child: const Text('Not now', style: TextStyle(color: AppColors.slate600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
