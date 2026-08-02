import 'package:firebase_core/firebase_core.dart';

/// Hand-written instead of FlutterFire-CLI-generated, matching how this
/// project's other third-party keys (Groq, RevenueCat) are wired: values
/// come from a dashboard, not a local CLI tool. Android-only, since the app
/// only targets Play Store right now (see PRIVACY_POLICY.md / earlier
/// planning notes).
///
/// Values match the `com.zeeshanfarooq.resumebuilder` client entry in
/// android/app/google-services.json (project resumebuilderapp-631ed). None
/// of these are secret — they're public client identifiers, safe to commit.
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyACR5T94TFMDD5C4TSxKFauZBe-jDE8zhs',
    appId: '1:492388672260:android:1014a7e0682f56c144e651',
    messagingSenderId: '492388672260',
    projectId: 'resumebuilderapp-631ed',
    storageBucket: 'resumebuilderapp-631ed.firebasestorage.app',
  );

  static FirebaseOptions get currentPlatform => android;
}
