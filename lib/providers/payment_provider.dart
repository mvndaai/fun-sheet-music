import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'instrument_provider.dart';

class PaymentProvider extends ChangeNotifier {
  final InstrumentProvider instrumentProvider;
  final InAppPurchase _iap = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  static const String adFreeYearId = 'ad_free_yearly';
  static const String adFreeForeverId = 'ad_free_forever';

  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _loading = true;

  List<ProductDetails> get products => _products;
  bool get isAvailable => _isAvailable;
  bool get loading => _loading;

  PaymentProvider({required this.instrumentProvider}) {
    final purchaseUpdated = _iap.purchaseStream;
    _subscription = purchaseUpdated.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription.cancel(),
      onError: (error) {
        debugPrint('Purchase Stream Error: $error');
      },
    );
    _initialize();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    _isAvailable = await _iap.isAvailable();
    if (_isAvailable) {
      await loadProducts();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> loadProducts() async {
    const Set<String> ids = {adFreeYearId, adFreeForeverId};
    final ProductDetailsResponse response = await _iap.queryProductDetails(ids);
    if (response.error == null) {
      _products = response.productDetails;
    }
    notifyListeners();
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _verifyPurchase(purchase);
      }
      if (purchase.pendingCompletePurchase) {
        _iap.completePurchase(purchase);
      }
    }
  }

  void _verifyPurchase(PurchaseDetails purchase) {
    // In a real app, verify with your server here.
    if (purchase.productID == adFreeYearId || purchase.productID == adFreeForeverId) {
      instrumentProvider.setAdFree(true);
    }
    notifyListeners();
  }

  Future<void> buyAdFreeYear() async {
    final product = _products.firstWhere((p) => p.id == adFreeYearId, orElse: () => _mockProduct(adFreeYearId, '\$1/year'));
    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> buyAdFreeForever() async {
    final product = _products.firstWhere((p) => p.id == adFreeForeverId, orElse: () => _mockProduct(adFreeForeverId, '\$5 forever'));
    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  // Helper for testing when store is not set up
  ProductDetails _mockProduct(String id, String price) {
    return ProductDetails(
      id: id,
      title: 'Remove Ads',
      description: 'Remove ads and support the app!',
      price: price,
      rawPrice: 0,
      currencyCode: 'USD',
    );
  }

  // Simulation for the user to test UI without real store setup
  Future<void> simulatePurchase(String id) async {
    await Future.delayed(const Duration(seconds: 1));
    instrumentProvider.setAdFree(true);
    notifyListeners();
  }
}
