import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../settings_store.dart';

/// Thrown when a pack cannot be made available.
class ContentPackException implements Exception {
  const ContentPackException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Word meanings and example translations, per language.
///
/// English is the source language and needs no pack. The other ten packs are
/// 0.8-1.2 MB each, so they live in Firebase Storage and are downloaded once
/// per language and cached on disk — that keeps the install small and lets a
/// translation fix ship without an app release.
///
/// A missing key always falls back to English, so partial coverage is safe by
/// design rather than an error (Turkish covers ~9,200 of ~12,360 keys).
class ContentPackRepository {
  ContentPackRepository({
    FirebaseStorage? storage,
    required SettingsStore settings,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _settings = settings;

  final FirebaseStorage _storage;
  final SettingsStore _settings;

  /// Storage path prefix. Upload packs as `i18n/<lang>.json`.
  static const String storagePrefix = 'i18n';

  final Map<String, Map<String, String>> _memory = <String, Map<String, String>>{};

  /// The active pack, or null for English.
  Map<String, String>? _active;

  /// Translates a content string (a word meaning or an example's English side).
  String translate(String? s) {
    if (s == null || s.isEmpty) return s ?? '';
    return _active?[s] ?? s;
  }

  bool get isEnglish => _active == null;

  /// Loads [lang] into memory, downloading it if necessary.
  ///
  /// Order: in-memory -> on-disk cache -> Firebase Storage. Throws
  /// [ContentPackException] when the pack is neither cached nor reachable, so
  /// the caller can keep the previous language instead of silently degrading.
  Future<void> activate(String lang) async {
    if (lang == 'en') {
      _active = null;
      return;
    }
    final Map<String, String>? mem = _memory[lang];
    if (mem != null) {
      _active = mem;
      return;
    }

    final File file = await _cacheFile(lang);
    if (file.existsSync()) {
      try {
        final Map<String, String> parsed =
            await compute(_parsePack, await file.readAsString());
        _memory[lang] = parsed;
        _active = parsed;
        return;
      } catch (_) {
        // Corrupt cache: delete and fall through to a fresh download.
        try {
          file.deleteSync();
        } catch (_) {}
      }
    }

    final Map<String, String> downloaded = await _download(lang, file);
    _memory[lang] = downloaded;
    _active = downloaded;
  }

  /// True when the pack for [lang] is already usable offline.
  Future<bool> isCached(String lang) async {
    if (lang == 'en') return true;
    if (_memory.containsKey(lang)) return true;
    return (await _cacheFile(lang)).existsSync();
  }

  Future<Map<String, String>> _download(String lang, File target) async {
    try {
      final Reference ref = _storage.ref('$storagePrefix/$lang.json');
      // Packs are ~1.2 MB at most; 8 MB is generous headroom.
      final Uint8List? bytes = await ref.getData(8 * 1024 * 1024);
      if (bytes == null) {
        throw const ContentPackException('Language pack was empty.');
      }
      final String raw = utf8.decode(bytes);
      final Map<String, String> parsed = await compute(_parsePack, raw);

      await target.parent.create(recursive: true);
      await target.writeAsString(raw, flush: true);
      final FullMetadata meta = await ref.getMetadata();
      await _settings.setPackVersion(
        lang,
        meta.updated?.toIso8601String() ?? '${meta.size ?? 0}',
      );
      return parsed;
    } on FirebaseException catch (e) {
      throw ContentPackException(
        e.code == 'object-not-found'
            ? 'That language is not available yet.'
            : 'Could not download this language — check your connection and try again.',
      );
    } on ContentPackException {
      rethrow;
    } catch (_) {
      throw const ContentPackException(
        'Could not download this language — check your connection and try again.',
      );
    }
  }

  Future<File> _cacheFile(String lang) async {
    final Directory dir = await getApplicationSupportDirectory();
    return File(p.join(dir.path, 'i18n', '$lang.json'));
  }

  /// Deletes every cached pack. Offered in settings so a user can reclaim disk.
  Future<int> clearCache() async {
    final Directory dir = Directory(
        p.join((await getApplicationSupportDirectory()).path, 'i18n'));
    if (!dir.existsSync()) return 0;
    int n = 0;
    for (final FileSystemEntity f in dir.listSync()) {
      if (f is File) {
        f.deleteSync();
        n++;
      }
    }
    _memory.clear();
    _active = null;
    return n;
  }
}

Map<String, String> _parsePack(String raw) {
  final Map<String, dynamic> j = json.decode(raw) as Map<String, dynamic>;
  return j.map((String k, dynamic v) => MapEntry<String, String>(k, v as String));
}
