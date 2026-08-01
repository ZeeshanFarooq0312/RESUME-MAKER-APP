import 'package:shared_preferences/shared_preferences.dart';
import '../models/resume_data.dart';

/// Local, singleton storage for the user's "Profile" — reuses [ResumeData]'s
/// shape as-is (personal info + experience + education + skills already
/// match "profile" exactly) so the AI resume-tailoring feature has one
/// reusable source of truth, editable the same way a resume is. Unlike
/// [DocumentsRepository] there's only ever one profile, so this is a single
/// SharedPreferences key rather than a list.
class ProfileRepository {
  static const _key = 'profile_v1';

  static Future<ResumeData?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    return ResumeData.decode(raw);
  }

  static Future<void> save(ResumeData data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, data.encode());
  }

  static Future<bool> exists() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_key);
  }
}
