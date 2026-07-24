import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PREMIUM SERVICE — Stub / Preparation
// When ready to monetize: integrate RevenueCat (pub.dev/packages/purchases_flutter)
// Set _devUnlockAll = false and implement purchaseAnnual() / purchaseLifetime().
//
// RevenueCat handles:
//   - App Store Connect + Google Play billing
//   - Purchase verification (no backend needed for basic use)
//   - Subscription status sync across devices
// ─────────────────────────────────────────────────────────────────────────────

/// Named feature gates. Check these with PremiumService.instance.isAvailable(feature).
class PremiumFeature {
  static const String cloudSync = 'cloud_sync';
  static const String advancedExport = 'advanced_export'; // PDF + image export
  static const String versionHistory = 'version_history'; // beyond 5 versions
  static const String fontChoice = 'font_choice'; // premium fonts
  static const String allAtmospheres = 'all_atmospheres'; // custom themes
  static const String unlimitedEntries = 'unlimited_entries'; // >50 entries
  static const String search = 'search'; // always free
}

class PremiumService extends ChangeNotifier {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  // ── During development, unlock everything ─────────────────────────────────
  // Set to false when you're ready to ship the paywall.
  static const bool _devUnlockAll = true;

  bool _isPremium = false;
  bool get isPremium => _devUnlockAll || _isPremium;

  // Features that are always free regardless of subscription
  static const Set<String> _alwaysFree = {
    PremiumFeature.search,
  };

  bool isAvailable(String feature) {
    if (_alwaysFree.contains(feature)) return true;
    return isPremium;
  }

  // ── Pricing (USD) ─────────────────────────────────────────────────────────
  // These are the product IDs you'll register in App Store Connect / Google Play.
  // Annual: $6.99/year  ← sweet spot for a thoughtful niche app
  // Lifetime: $17.99    ← 2.5x annual feels fair (not predatory)
  static const String productAnnual = 'flow_premium_annual';
  static const String productLifetime = 'flow_premium_lifetime';

  // ── RevenueCat integration placeholder ────────────────────────────────────
  // When ready:
  //   1. flutter pub add purchases_flutter
  //   2. Call Purchases.configure(PurchasesConfiguration('YOUR_API_KEY'))
  //   3. Replace stub methods below with real RevenueCat calls

  Future<bool> purchaseAnnual() async {
    // TODO: Purchases.purchasePackage(annualPackage)
    debugPrint('[Premium] purchaseAnnual called (stub)');
    return false;
  }

  Future<bool> purchaseLifetime() async {
    // TODO: Purchases.purchasePackage(lifetimePackage)
    debugPrint('[Premium] purchaseLifetime called (stub)');
    return false;
  }

  Future<void> restorePurchases() async {
    // TODO: Purchases.restorePurchases()
    debugPrint('[Premium] restorePurchases called (stub)');
  }

  Future<void> checkStatus() async {
    // TODO: final info = await Purchases.getCustomerInfo();
    // _isPremium = info.entitlements.active.containsKey('premium');
    // notifyListeners();
    debugPrint('[Premium] checkStatus called (stub)');
  }
}
