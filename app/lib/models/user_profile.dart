/// The Firestore-backed user profile.
///
/// Unlike the web placeholder, [isPro] here is written **only** by the
/// receipt-verification Cloud Function; the client can read it but never set it
/// (enforced by firestore.rules).
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    this.displayName,
    this.provider = 'password',
    this.createdAt,
    this.isPro = false,
    this.proSource,
    this.proExpiresAt,
  });

  final String uid;
  final String? email;
  final String? displayName;

  /// `google.com`, `apple.com` or `password`.
  final String provider;
  final DateTime? createdAt;

  /// Server-verified Pro entitlement.
  final bool isPro;

  /// `app_store` or `play_store`, set by the verification function.
  final String? proSource;
  final DateTime? proExpiresAt;

  String get shortName {
    final String n = (displayName?.trim().isNotEmpty ?? false)
        ? displayName!.trim()
        : (email ?? '?').split('@').first;
    return n;
  }

  /// Up to two uppercase initials for the avatar.
  String get initials {
    final List<String> parts =
        shortName.split(RegExp(r'\s+')).where((String p) => p.isNotEmpty).take(2).toList();
    if (parts.isEmpty) return '?';
    return parts.map((String p) => p.substring(0, 1)).join().toUpperCase();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'email': email,
        'displayName': displayName,
        'provider': provider,
        'isPro': isPro,
        'proSource': proSource,
      };

  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> j) => UserProfile(
        uid: uid,
        email: j['email'] as String?,
        displayName: j['displayName'] as String?,
        provider: j['provider'] as String? ?? 'password',
        createdAt: _ts(j['createdAt']),
        isPro: j['isPro'] == true,
        proSource: j['proSource'] as String?,
        proExpiresAt: _ts(j['proExpiresAt']),
      );

  static DateTime? _ts(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    // Firestore Timestamp exposes toDate(); avoid importing the SDK here.
    try {
      return (v as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }
}
