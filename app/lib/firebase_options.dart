// PLACEHOLDER — this file is committed so a fresh clone compiles.
//
// Replace it by running:
//
//     dart pub global activate flutterfire_cli
//     flutterfire configure --project=<your-firebase-project-id>
//
// That overwrites this file and also writes android/app/google-services.json
// and ios/Runner/GoogleService-Info.plist (both gitignored).
//
// Committing the generated firebase_options.dart afterwards is fine: Firebase
// client config is public by design, and access is controlled by the security
// rules in ../firebase/, not by hiding these values.
//
// Until then this placeholder throws a readable error at startup rather than
// failing somewhere deep inside the Firebase SDK.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform => throw UnsupportedError(
        'Firebase is not configured. Run `flutterfire configure` to generate '
        'lib/firebase_options.dart. See README.md, section "Firebase setup".',
      );
}
