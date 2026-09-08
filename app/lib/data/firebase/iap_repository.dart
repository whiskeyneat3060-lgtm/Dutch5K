import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../core/constants.dart';

/// What the Pro purchase flow is currently doing, for the UI to render.
///
/// Named to avoid colliding with the plugin's own `PurchaseStatus` enum, which
/// this file also uses.
enum PurchaseState { idle, loading, pending, verifying, success, failed, unavailable }

class ProPurchaseStatus {
  const ProPurchaseStatus(this.state, {this.message});
  final PurchaseState state;
  final String? message;

  bool get isBusy =>
      state == PurchaseState.loading ||
      state == PurchaseState.pending ||
      state == PurchaseState.verifying;
}

/// In-app purchase for the Pro entitlement.
///
/// The client never grants Pro. It hands the store receipt to Firestore, a
/// Cloud Function verifies it with Apple or Google and writes `isPro` on the
/// user document, and the app simply observes that document. This is what makes
/// the entitlement forgery-resistant and what App Store Guideline 3.1.1 and
/// Play's Payments policy require.
class IapRepository {
  IapRepository({
    InAppPurchase? iap,
    FirebaseFirestore? firestore,
  })  : _iap = iap ?? InAppPurchase.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final InAppPurchase _iap;
  final FirebaseFirestore _db;

  StreamSubscription<List<PurchaseDetails>>? _sub;
  final ValueNotifier<ProPurchaseStatus> status =
      ValueNotifier<ProPurchaseStatus>(const ProPurchaseStatus(PurchaseState.idle));

  ProductDetails? _product;
  ProductDetails? get product => _product;

  /// Localised price string, e.g. "€4,99". Null until the store responds.
  String? get priceLabel => _product?.price;

  String? _uid;

  /// Starts listening for purchase updates. Call once after sign-in state is
  /// known; [uid] is needed so a receipt can be attributed to an account.
  Future<void> init({String? uid}) async {
    _uid = uid;
    final bool available = await _iap.isAvailable();
    if (!available) {
      status.value = const ProPurchaseStatus(
        PurchaseState.unavailable,
        message: 'In-app purchases are not available on this device.',
      );
      return;
    }

    _sub ??= _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e) => status.value =
          ProPurchaseStatus(PurchaseState.failed, message: 'Purchase failed: $e'),
    );

    final ProductDetailsResponse resp =
        await _iap.queryProductDetails(<String>{kProProductId});
    if (resp.productDetails.isNotEmpty) {
      _product = resp.productDetails.first;
      status.value = const ProPurchaseStatus(PurchaseState.idle);
    } else {
      status.value = const ProPurchaseStatus(
        PurchaseState.unavailable,
        message: 'Pro is not available right now. Please try again later.',
      );
    }
  }

  void updateUid(String? uid) => _uid = uid;

  /// Launches the store purchase sheet. Pro is a one-time non-consumable.
  Future<void> buy() async {
    final ProductDetails? p = _product;
    if (p == null) {
      status.value = const ProPurchaseStatus(
        PurchaseState.unavailable,
        message: 'Pro is not available right now. Please try again later.',
      );
      return;
    }
    if (_uid == null) {
      status.value = const ProPurchaseStatus(
        PurchaseState.failed,
        message: 'Please sign in before buying Pro.',
      );
      return;
    }
    status.value = const ProPurchaseStatus(PurchaseState.loading);
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: p, applicationUserName: _uid),
    );
  }

  /// Re-delivers a previous purchase. Both stores require a restore path.
  Future<void> restore() async {
    status.value = const ProPurchaseStatus(PurchaseState.loading);
    try {
      await _iap.restorePurchases();
    } catch (e) {
      status.value =
          ProPurchaseStatus(PurchaseState.failed, message: 'Could not restore: $e');
    }
  }

  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final PurchaseDetails pd in purchases) {
      switch (pd.status) {
        case PurchaseStatus.pending:
          status.value = const ProPurchaseStatus(PurchaseState.pending);

        case PurchaseStatus.error:
          status.value = ProPurchaseStatus(
            PurchaseState.failed,
            message: pd.error?.message ?? 'The purchase could not be completed.',
          );

        case PurchaseStatus.canceled:
          status.value = const ProPurchaseStatus(PurchaseState.idle);

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          status.value = const ProPurchaseStatus(PurchaseState.verifying);
          await _submitReceipt(pd);
      }

      // Always complete, or the store re-delivers the purchase forever.
      if (pd.pendingCompletePurchase) {
        await _iap.completePurchase(pd);
      }
    }
  }

  /// Writes the receipt for the Cloud Function to verify. The function is the
  /// only writer of `users/{uid}.isPro`; firestore.rules block the client.
  Future<void> _submitReceipt(PurchaseDetails pd) async {
    final String? uid = _uid;
    if (uid == null) {
      status.value = const ProPurchaseStatus(
        PurchaseState.failed,
        message: 'Please sign in so we can attach Pro to your account.',
      );
      return;
    }
    try {
      await _db.collection('users').doc(uid).collection('receipts').add(<String, dynamic>{
        'productId': pd.productID,
        'purchaseId': pd.purchaseID,
        'source': pd.verificationData.source, // 'app_store' | 'google_play'
        'serverVerificationData': pd.verificationData.serverVerificationData,
        'localVerificationData': pd.verificationData.localVerificationData,
        'transactionDate': pd.transactionDate,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      status.value = const ProPurchaseStatus(PurchaseState.success);
    } catch (e) {
      status.value = ProPurchaseStatus(
        PurchaseState.failed,
        message: 'Purchase recorded but verification failed to start: $e',
      );
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    status.dispose();
  }
}
