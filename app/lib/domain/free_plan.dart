import '../core/constants.dart';
import '../models/deck_entry.dart';

/// Free-plan entitlement (BUILD-SPEC 7.4).
class FreePlan {
  const FreePlan._();

  /// The set of entry ids unlocked for Free users.
  ///
  /// Each source has a cap; the lowest-rank N words of that source stay free.
  /// A word is free if it falls under the cap of **any** of its sources, so a
  /// word shared between A0–A2 (cap 200) and A2–B1 (cap 0) is still reachable.
  ///
  /// Note the bucket map is seeded from [kFreeLimits], which fixes the web
  /// app's quirk where `perfectie` had no bucket at all (BUILD-SPEC 12.3.9).
  /// Behaviour is identical while its cap stays 0.
  static Set<String> computeFreeIds(List<DeckEntry> entries) {
    final Map<String, List<DeckEntry>> buckets = <String, List<DeckEntry>>{
      for (final String src in kFreeLimits.keys) src: <DeckEntry>[],
    };

    for (final DeckEntry e in entries) {
      for (final String tag in e.srcTags) {
        buckets[tag]?.add(e);
      }
    }

    final Set<String> free = <String>{};
    buckets.forEach((String src, List<DeckEntry> list) {
      final int cap = kFreeLimits[src] ?? 0;
      if (cap <= 0) return;
      final List<DeckEntry> sorted = List<DeckEntry>.of(list)
        ..sort((DeckEntry a, DeckEntry b) => a.sortRank.compareTo(b.sortRank));
      for (final DeckEntry e in sorted.take(cap)) {
        free.add(e.id);
      }
    });
    return free;
  }

  /// Pulls every unlocked word to the front of a list of deck indices, then all
  /// locked words after, preserving relative order inside each partition
  /// (BUILD-SPEC 7.5). No-op for Pro, and no-op when one partition is empty.
  static List<int> freeFirst(
    List<int> order, {
    required bool isPro,
    required Set<String> freeIds,
    required List<DeckEntry> entries,
  }) {
    if (isPro || order.length < 2) return order;
    final List<int> free = <int>[];
    final List<int> locked = <int>[];
    for (final int i in order) {
      if (freeIds.contains(entries[i].id)) {
        free.add(i);
      } else {
        locked.add(i);
      }
    }
    if (free.isEmpty || locked.isEmpty) return order;
    return <int>[...free, ...locked];
  }
}
