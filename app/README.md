# Dutch To Go — Flutter app (iOS + Android)

A native port of the Dutch To Go vocabulary trainer, built from
[`../BUILD-SPEC.md`](../BUILD-SPEC.md). Firebase provides auth, sync, storage and
entitlement verification.

---

## 1. What is here

| Path | Contents |
|---|---|
| `lib/domain/` | Pure, framework-free algorithms: SM-2-lite scheduling, queue building, answer grading, search relevance, free-plan entitlement, goal and streak maths. **Fully unit tested against BUILD-SPEC §11.** |
| `lib/models/` | `DeckEntry`, `SrsRecord`, `StreakData`, `StudyPlan`, `UserProfile` |
| `lib/data/` | Deck asset loader, SQLite store, settings store, Firebase repositories, i18n |
| `lib/state/` | Riverpod providers and the settings / study controllers |
| `lib/ui/` | Three themes, shared widgets, and the five screens |
| `assets/data/deck.json` | The built 6,752-word deck (1.8 MB) |
| `assets/data/ui_strings.json` | 214 UI keys × 10 languages |
| `../firebase/` | Firestore + Storage rules, and the receipt-verification functions |
| `../tools/upload_i18n_packs.sh` | Uploads the ten content packs to Storage |

Architecture in one line: **local-first**. SQLite is the source of truth while
studying, so grading never waits on the network; a debounced job mirrors state
to Firestore as eight chunked documents.

---

## 2. Prerequisites

- Flutter **3.35** or newer (`flutter --version`)
- For Android: JDK 17, Android SDK 35
- For iOS: macOS with Xcode 15+, CocoaPods
- Node 20 for the Cloud Functions
- `npm i -g firebase-tools` and `dart pub global activate flutterfire_cli`

---

## 3. Firebase setup

Three files are **gitignored on purpose** because they are per-project
configuration, not source. Generate them:

```bash
cd app
flutterfire configure --project=<your-firebase-project-id>
```

That writes:

- `lib/firebase_options.dart` — overwrites the placeholder that currently throws
  a helpful error. The template is kept at `lib/firebase_options.template.dart`.
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

Then, in the Firebase console:

1. **Authentication → Sign-in method**: enable **Google**, **Apple** and
   **Email/Password**.
2. **Firestore Database**: create it in your preferred region.
3. **Storage**: create the default bucket.
4. Deploy the rules and functions:

```bash
cd ../firebase
firebase use <your-firebase-project-id>
firebase deploy --only firestore:rules,storage:rules
cd functions && npm install && npm run build
cd .. && firebase deploy --only functions
```

5. Upload the content packs:

```bash
cd ..
./tools/upload_i18n_packs.sh <your-firebase-project-id>
```

### 3.1 iOS: Google Sign-In URL scheme

Open `ios/Runner/GoogleService-Info.plist`, copy the value of
`REVERSED_CLIENT_ID`, and paste it over `REPLACE_WITH_REVERSED_CLIENT_ID` in
`ios/Runner/Info.plist`.

### 3.2 iOS: Sign in with Apple

In Xcode, select the Runner target → **Signing & Capabilities** → **+
Capability** → **Sign in with Apple**. Then enable the same capability for your
App ID in the Apple Developer portal, and add the Service ID to Firebase
Authentication → Apple.

> This is not optional. App Store Review Guideline 4.8 requires Sign in with
> Apple wherever another third-party sign-in is offered, and this app offers
> Google.

---

## 4. In-app purchase

Pro is a **one-time non-consumable** with product id `dutch_to_go_pro`
(`kProProductId` in `lib/core/constants.dart`). It must match exactly in both
stores.

### 4.1 App Store Connect

1. Create the non-consumable `dutch_to_go_pro`, price it, and submit it for
   review alongside the first build.
2. **App Store Connect → App Information → App-Specific Shared Secret** →
   generate one, then store it as a Firebase secret:

```bash
cd firebase
firebase functions:secrets:set APPLE_SHARED_SECRET
```

### 4.2 Google Play Console

1. Create the in-app product `dutch_to_go_pro` and activate it.
2. **Setup → API access**: link the Google Cloud project, find the Cloud
   Functions default service account
   (`<project>@appspot.gserviceaccount.com`), and grant it **View financial
   data, orders, and cancellation survey responses**. Without this the Play
   Developer API returns 401 and every purchase is rejected.
3. Confirm `ANDROID_PACKAGE` in `firebase/functions/src/index.ts` matches your
   `applicationId`.

### 4.3 How verification works

The client never sets the entitlement:

```
app → users/{uid}/receipts/{id}  (status: pending)
        ↓ onDocumentCreated
   verifyReceipt  → Apple verifyReceipt / Play androidpublisher
        ↓ only if the store confirms
   users/{uid}.isPro = true
```

`firestore.rules` reject any client write that touches `isPro`, so a tampered
client cannot unlock Pro. The app reads `isPro` from the profile stream and
gates on that alone.

---

## 5. Running

```bash
cd app
flutter pub get
flutter run                 # debug, on a connected device or simulator
flutter test                # 89 unit tests
flutter analyze             # must be clean
```

### 5.1 Release builds

```bash
flutter build appbundle --release   # Android, for Play
flutter build ipa --release         # iOS, for App Store Connect
```

Android release signing reads `android/key.properties`. Copy
`android/key.properties.template`, fill it in, and keep both the file and the
keystore out of version control. Without it the release build falls back to
debug keys so a fresh clone still runs.

---

## 6. Assets still needed before submission

These do not exist yet and cannot be generated from what is in the repository
(see BUILD-SPEC §4.6 and §12.2.2 — only rasterised web icons were committed, and
the source artwork lives outside the repo).

| Asset | Where |
|---|---|
| iOS `AppIcon.appiconset`, including the 1024×1024 marketing icon | `ios/Runner/Assets.xcassets/` |
| Android adaptive icon (108×108 dp foreground + background layers) | `android/app/src/main/res/mipmap-*/` |
| Launch screen / splash | `ios/Runner/Assets.xcassets/LaunchImage.imageset/`, `android/app/src/main/res/drawable/launch_background.xml` |
| Store screenshots and the 1024×500 Play feature graphic | Store consoles |

The Android **notification** icon is already in place at
`android/app/src/main/res/drawable/ic_notification.xml` — a white silhouette, as
Android requires; the colour badge cannot be used there.

`assets/fonts/` is currently empty: the app falls back to the platform sans and
serif. To match the web build exactly, add Archivo (400/600/700/800/900) and
Inter (400/500/600) and declare them in `pubspec.yaml`. Both are SIL OFL.

---

## 7. What changed from the web build, and why

| Web behaviour | Native | Reason |
|---|---|---|
| Pro was a local boolean with no payment | Real IAP verified server-side | App Store 3.1.1 and Play Payments policy both reject the old model |
| "Continue with Google" collected an email and created a fake local account | Real Firebase OAuth | Reviewers test sign-in; the demo flow would be rejected |
| No account deletion | `Delete my account` on the Profile page, with a server-side data purge | App Store 5.1.1(v) |
| Progress lived only in `localStorage` | SQLite + chunked Firestore sync | Progress now survives reinstall and reaches a second device |
| Reminders fired only while a tab was open | Real scheduled local notifications | A static PWA has no push; a native app does not need one for this |
| No haptics on iOS at all | `HapticFeedback` on both platforms | The web `navigator.vibrate` silently no-ops on iOS |
| TTS silently used the wrong accent when no Dutch voice existed | Reports the failure so the UI can say so | The voice is a downloadable component on both platforms |
| Content packs fetched from the same origin | Firebase Storage, cached on disk | Keeps the install small; packs update without a release |
| `computeFree()` had no `perfectie` bucket | Bucket map seeded from `kFreeLimits` | Fixes BUILD-SPEC §12.3.9; behaviour is identical while the cap is 0 |

Two web quirks were **preserved deliberately**, because changing them would
alter user-visible counts:

- `hasMeaning` is stored explicitly rather than derived from `meaning != null`.
  The 115 curated seed entries carry a meaning without the flag, and that is
  what excluded them from the 1,484-word Essential core.
- Source labels keep both typographies: en dash (`A0–A2`) in legends and badges,
  arrow (`A0 → A2`) in the filter dropdown.

---

## 8. Testing

```bash
flutter test
```

89 tests, organised by the BUILD-SPEC acceptance criteria they cover:

| File | Covers |
|---|---|
| `test/srs_test.dart` | AC-14 … AC-20 — scheduling, ease-factor arithmetic, due dates |
| `test/queue_test.dart` | AC-13, AC-21 … AC-28, AC-34, AC-35 — queue partitions, filters, shuffle |
| `test/deck_data_test.dart` | AC-1 … AC-12 — data integrity against the real bundled deck |
| `test/answer_check_test.dart` | AC-29 … AC-32 — normalisation and cloze extraction |
| `test/search_test.dart` | AC-55 — relevance tiers |
| `test/goal_streak_test.dart` | AC-41 … AC-49 — goal maths, streak rules, breakdowns |
| `test/sync_test.dart` | Chunk distribution and the offline-merge rules |

Widget and integration tests are not written yet — that is the main gap in
coverage.
