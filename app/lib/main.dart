import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/deck_repository.dart';
import 'data/i18n/content_pack_repository.dart';
import 'data/i18n/ui_strings.dart';
import 'data/local_db.dart';
import 'data/settings_store.dart';
import 'firebase_options.dart';
import 'models/deck_entry.dart';
import 'models/enums.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';
import 'state/providers.dart';
import 'state/settings_controller.dart';
import 'state/study_controller.dart';
import 'ui/shell.dart';
import 'ui/theme/app_theme.dart';
import 'ui/theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      <DeviceOrientation>[DeviceOrientation.portraitUp]);

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Resolve the async singletons before the first frame so the app opens
  // straight onto a card rather than a spinner.
  final SettingsStore settings = await SettingsStore.create();
  final LocalDb db = await LocalDb.open();
  final UiStrings ui = await UiStrings.load();
  final Deck deck = await DeckRepository().load();
  final ContentPackRepository packs = ContentPackRepository(settings: settings);

  ui.language = settings.language;
  if (settings.language != 'en') {
    // Best effort: a cached pack loads instantly, and a failure just leaves
    // meanings in English rather than blocking startup.
    try {
      await packs.activate(settings.language);
    } catch (_) {}
  }

  runApp(
    ProviderScope(
      overrides: <Override>[
        settingsStoreProvider.overrideWithValue(settings),
        localDbProvider.overrideWithValue(db),
        uiStringsProvider.overrideWithValue(ui),
        deckProvider.overrideWithValue(deck),
        contentPackProvider.overrideWithValue(packs),
      ],
      child: const DutchToGoApp(),
    ),
  );
}

class DutchToGoApp extends ConsumerStatefulWidget {
  const DutchToGoApp({super.key});

  @override
  ConsumerState<DutchToGoApp> createState() => _DutchToGoAppState();
}

class _DutchToGoAppState extends ConsumerState<DutchToGoApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final StudyController study = ref.read(studyProvider.notifier);
    await study.load();

    await ref.read(notificationsProvider).init();
    NotificationService.onTap = (String? _) {
      // Tapping the reminder should land on the study card.
    };
    await ref.read(settingsProvider.notifier).rescheduleReminder();

    // Purchases and sync both depend on who is signed in.
    ref.listenManual<AsyncValue<User?>>(authStateProvider,
        (AsyncValue<User?>? _, AsyncValue<User?> next) async {
      final String? uid = next.value?.uid;
      ref.read(iapProvider).updateUid(uid);
      if (uid != null) await study.pullAndMerge();
    }, fireImmediately: true);

    await ref.read(iapProvider).init(uid: ref.read(authStateProvider).value?.uid);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Flush anything the debounce timer has not pushed yet.
      ref.read(studyProvider.notifier).pushSync();
    }
    if (state == AppLifecycleState.resumed) {
      ref.read(settingsProvider.notifier).rescheduleReminder();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeId themeId = ref.watch(
        settingsProvider.select((SettingsState s) => s.theme));
    final AppTokens tokens = AppTheme.tokensFor(themeId);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.overlayStyle(tokens),
      child: MaterialApp(
        title: 'Dutch To Go',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.materialTheme(tokens),
        home: const AppShell(),
      ),
    );
  }
}
