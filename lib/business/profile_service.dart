import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/supabase_repository.dart';

class ProfileService {
  final SupabaseRepository _remote;

  ProfileService({required SupabaseRepository remote}) : _remote = remote;

  Future<void> updateDisplayName(String name) async {
    await _remote.callEdgeFunction('update-profile', body: {'display_name': name});
  }

  Future<void> updateProfilePhoto(String? url) async {
    await _remote.callEdgeFunction('update-profile', body: {'profile_photo_url': url});
  }

  Future<void> incrementOffersCompleted() async {
    final uid = _remote.currentUserId;
    if (uid == null) return;
    try {
      await _remote.callEdgeFunction(
        'increment-user-stat',
        body: {
          'stat_name': 'offers_completed',
        },
      );
    } catch (_) {}
  }
}
