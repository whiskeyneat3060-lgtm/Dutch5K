import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/deck_repository.dart';
import '../data/firebase/auth_repository.dart';
import '../data/firebase/iap_repository.dart';
import '../data/firebase/sync_repository.dart';
import '../data/i18n/content_pack_repository.dart';
import '../data/i18n/ui_strings.dart';
import '../data/local_db.dart';
import '../data/settings_store.dart';
import '../models/deck_entry.dart';
import '../models/user_profile.dart';
import '../services/notification_service.dart';
import '../services/tts_service.dart';

/// Singletons wired at startup by [bootstrapProvider].

final Provider<DeckRepository> deckRepositoryProvider =
    Provider<DeckRepository>((Ref ref) => DeckRepository());

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>((Ref ref) => AuthRepository());

final Provider<SyncRepository> syncRepositoryProvider =
    Provider<SyncRepository>((Ref ref) => SyncRepository());

final Provider<TtsService> ttsProvider = Provider<TtsService>((Ref ref) {
  final TtsService s = TtsService();
  ref.onDispose(s.dispose);
  return s;
});

final Provider<NotificationService> notificationsProvider =
    Provider<NotificationService>((Ref ref) => NotificationService());

final Provider<IapRepository> iapProvider = Provider<IapRepository>((Ref ref) {
  final IapRepository r = IapRepository();
  ref.onDispose(r.dispose);
  return r;
});

/// Overridden in [main] once the async singletons have resolved.
final Provider<SettingsStore> settingsStoreProvider = Provider<SettingsStore>(
  (Ref ref) => throw UnimplementedError('settingsStoreProvider must be overridden'),
);

final Provider<LocalDb> localDbProvider = Provider<LocalDb>(
  (Ref ref) => throw UnimplementedError('localDbProvider must be overridden'),
);

final Provider<Deck> deckProvider = Provider<Deck>(
  (Ref ref) => throw UnimplementedError('deckProvider must be overridden'),
);

final Provider<UiStrings> uiStringsProvider = Provider<UiStrings>(
  (Ref ref) => throw UnimplementedError('uiStringsProvider must be overridden'),
);

final Provider<ContentPackRepository> contentPackProvider =
    Provider<ContentPackRepository>(
  (Ref ref) => throw UnimplementedError('contentPackProvider must be overridden'),
);

/// Firebase auth state.
final StreamProvider<User?> authStateProvider = StreamProvider<User?>(
  (Ref ref) => ref.watch(authRepositoryProvider).authStateChanges,
);

/// The signed-in user's Firestore profile, including the server-owned `isPro`.
final StreamProvider<UserProfile?> userProfileProvider =
    StreamProvider<UserProfile?>((Ref ref) {
  final User? user = ref.watch(authStateProvider).value;
  if (user == null) return Stream<UserProfile?>.value(null);
  return ref.watch(authRepositoryProvider).profileStream(user.uid);
});

/// The single source of truth for entitlement.
///
/// Deliberately derived from the Firestore profile only: there is no local flag
/// a client could set, which is what makes the paywall forgery-resistant.
final Provider<bool> isProProvider = Provider<bool>(
  (Ref ref) => ref.watch(userProfileProvider).value?.isPro ?? false,
);
