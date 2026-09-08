/**
 * Dutch To Go — server-side entitlement.
 *
 * The client can never grant itself Pro: firestore.rules reject any write that
 * touches `isPro`, and this function is the only writer. The client's job is to
 * drop the store receipt into `users/{uid}/receipts/{id}`; this verifies it
 * with Apple or Google and, only if the store confirms it, sets the flag.
 */
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as functionsV1 from 'firebase-functions/v1';
import { defineSecret } from 'firebase-functions/params';
import { google } from 'googleapis';
import fetch from 'node-fetch';

initializeApp();
const db = getFirestore();

/** Shared secret from App Store Connect, used for the verifyReceipt endpoint. */
const APPLE_SHARED_SECRET = defineSecret('APPLE_SHARED_SECRET');

/** The Android package name, needed by the Play Developer API. */
const ANDROID_PACKAGE = 'com.dutchtogo.dutch_to_go';

/** Must match kProProductId in the Flutter app. */
const PRO_PRODUCT_ID = 'dutch_to_go_pro';

const APPLE_PROD = 'https://buy.itunes.apple.com/verifyReceipt';
const APPLE_SANDBOX = 'https://sandbox.itunes.apple.com/verifyReceipt';

interface AppleResponse {
  status: number;
  receipt?: { in_app?: Array<{ product_id: string }> };
  latest_receipt_info?: Array<{ product_id: string }>;
}

/**
 * Verifies an App Store receipt.
 *
 * Apple's documented flow is to try production first and retry against the
 * sandbox on status 21007, so that TestFlight builds work without a separate
 * code path.
 */
async function verifyApple(receipt: string, secret: string): Promise<boolean> {
  const call = async (url: string): Promise<AppleResponse> => {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        'receipt-data': receipt,
        password: secret,
        'exclude-old-transactions': false,
      }),
    });
    return (await res.json()) as AppleResponse;
  };

  let body = await call(APPLE_PROD);
  if (body.status === 21007) body = await call(APPLE_SANDBOX);
  if (body.status !== 0) return false;

  const purchases = [
    ...(body.receipt?.in_app ?? []),
    ...(body.latest_receipt_info ?? []),
  ];
  return purchases.some((p) => p.product_id === PRO_PRODUCT_ID);
}

/**
 * Verifies a Google Play purchase token.
 *
 * Uses the function's own service account, which must be granted the
 * "View financial data" permission in the Play Console (see README).
 */
async function verifyGoogle(purchaseToken: string, productId: string): Promise<boolean> {
  const auth = new google.auth.GoogleAuth({
    scopes: ['https://www.googleapis.com/auth/androidpublisher'],
  });
  const publisher = google.androidpublisher({ version: 'v3', auth });

  const res = await publisher.purchases.products.get({
    packageName: ANDROID_PACKAGE,
    productId,
    token: purchaseToken,
  });

  // purchaseState 0 = purchased. acknowledgementState 0 means we still owe an
  // acknowledgement, or Play will refund the user automatically after 3 days.
  const purchased = res.data.purchaseState === 0;
  if (purchased && res.data.acknowledgementState === 0) {
    await publisher.purchases.products.acknowledge({
      packageName: ANDROID_PACKAGE,
      productId,
      token: purchaseToken,
    });
  }
  return purchased;
}

/**
 * Fires when the app writes a receipt. Verifies it and, on success, grants the
 * entitlement. The receipt document records the outcome either way so support
 * can see what happened.
 */
export const verifyReceipt = onDocumentCreated(
  {
    document: 'users/{uid}/receipts/{receiptId}',
    secrets: [APPLE_SHARED_SECRET],
    region: 'europe-west1',
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const { uid } = event.params;
    const data = snap.data();
    const productId: string = data.productId ?? PRO_PRODUCT_ID;
    const source: string = data.source ?? '';
    const token: string = data.serverVerificationData ?? '';

    if (productId !== PRO_PRODUCT_ID) {
      await snap.ref.update({ status: 'rejected', reason: 'unknown_product' });
      return;
    }

    let valid = false;
    let failure: string | null = null;

    try {
      if (source === 'app_store') {
        valid = await verifyApple(token, APPLE_SHARED_SECRET.value());
      } else if (source === 'google_play') {
        valid = await verifyGoogle(token, productId);
      } else {
        failure = 'unknown_source';
      }
    } catch (err) {
      failure = err instanceof Error ? err.message : 'verification_error';
    }

    if (!valid) {
      await snap.ref.update({
        status: 'rejected',
        reason: failure ?? 'store_rejected',
        verifiedAt: FieldValue.serverTimestamp(),
      });
      return;
    }

    // Grant. This is the only place isPro is ever written.
    await db.doc(`users/${uid}`).set(
      {
        isPro: true,
        proSource: source,
        proGrantedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    await snap.ref.update({
      status: 'verified',
      verifiedAt: FieldValue.serverTimestamp(),
    });
  },
);

/**
 * Re-checks a user's entitlement on demand — the "Restore purchases" path when
 * a receipt document already exists but the grant did not stick.
 */
export const refreshEntitlement = onCall(
  { secrets: [APPLE_SHARED_SECRET], region: 'europe-west1' },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'Sign in first.');

    const receipts = await db
      .collection(`users/${uid}/receipts`)
      .orderBy('createdAt', 'desc')
      .limit(10)
      .get();

    for (const doc of receipts.docs) {
      const d = doc.data();
      const token: string = d.serverVerificationData ?? '';
      const source: string = d.source ?? '';
      let ok = false;
      try {
        if (source === 'app_store') {
          ok = await verifyApple(token, APPLE_SHARED_SECRET.value());
        } else if (source === 'google_play') {
          ok = await verifyGoogle(token, d.productId ?? PRO_PRODUCT_ID);
        }
      } catch {
        ok = false;
      }
      if (ok) {
        await db.doc(`users/${uid}`).set(
          { isPro: true, proSource: source, proGrantedAt: FieldValue.serverTimestamp() },
          { merge: true },
        );
        return { isPro: true };
      }
    }
    return { isPro: false };
  },
);

/**
 * Account deletion, required by App Store Review Guideline 5.1.1(v).
 *
 * Deleting the auth user from the app triggers this, which removes the profile,
 * every progress chunk, the study metadata and all receipts.
 */
export const onUserDeleted = functionsV1
  .region('europe-west1')
  .auth.user()
  .onDelete(async (user) => {
    const root = db.doc(`users/${user.uid}`);
    for (const sub of ['progressChunks', 'study', 'receipts']) {
      const docs = await root.collection(sub).listDocuments();
      // Firestore caps a batch at 500 writes; chunk counts here are far lower,
      // but the loop keeps it correct if that ever changes.
      for (let i = 0; i < docs.length; i += 400) {
        const batch = db.batch();
        docs.slice(i, i + 400).forEach((d) => batch.delete(d));
        await batch.commit();
      }
    }
    await root.delete();
  });
