import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Dutch pronunciation.
///
/// Mirrors the web build's settings exactly: language `nl-NL`, rate 0.9.
/// Unlike the web build — which silently reads Dutch in whatever accent is
/// available — this reports when no Dutch voice is installed so the UI can say
/// so, because on both platforms the voice is a downloadable component.
class TtsService {
  TtsService({FlutterTts? tts}) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;
  bool _ready = false;
  bool _hasDutchVoice = false;

  /// The id currently speaking, so a button can show an active state.
  final ValueNotifier<String?> speakingId = ValueNotifier<String?>(null);

  bool get hasDutchVoice => _hasDutchVoice;

  Future<void> init() async {
    if (_ready) return;
    try {
      await _tts.setLanguage('nl-NL');
      await _tts.setSpeechRate(_platformRate);
      await _tts.setVolume(1);
      await _tts.setPitch(1);

      if (Platform.isIOS) {
        await _tts.setSharedInstance(true);
        // Duck other audio rather than stopping it, and never steal the session.
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.ambient,
          <IosTextToSpeechAudioCategoryOptions>[
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
        );
      }

      final dynamic langs = await _tts.getLanguages;
      if (langs is List) {
        _hasDutchVoice = langs.any(
            (dynamic l) => l.toString().toLowerCase().replaceAll('_', '-').startsWith('nl'));
      }

      _tts.setCompletionHandler(_clear);
      _tts.setCancelHandler(_clear);
      _tts.setErrorHandler((dynamic _) => _clear());

      _ready = true;
    } catch (_) {
      // Leave _ready false; speak() degrades to a no-op with a reported failure.
    }
  }

  /// iOS interprets rate on a different scale from Android, where 0.9 is close
  /// to the Web Speech default. 0.5 on iOS is the natural-speed equivalent.
  double get _platformRate => Platform.isIOS ? 0.45 : 0.9;

  /// Speaks Dutch [text]. [id] labels the button that triggered it so only that
  /// button shows the speaking state. Returns false when nothing could be said.
  Future<bool> speak(String text, {String? id}) async {
    if (text.trim().isEmpty) return false;
    await init();
    if (!_ready) return false;
    try {
      // Stop anything in flight, mirroring speechSynthesis.cancel().
      await _tts.stop();
      speakingId.value = id;
      await _tts.speak(text);
      return true;
    } catch (_) {
      _clear();
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _clear();
  }

  void _clear() => speakingId.value = null;

  void dispose() {
    speakingId.dispose();
  }
}
