import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/supabase_repository.dart';

class ProfileService {
  final SupabaseRepository _remote;

  ProfileService({required SupabaseRepository remote}) : _remote = remote;

  Future<String> uploadProfilePhoto(Uint8List imageBytes, String userId) async {
    final path = '$userId/avatar.jpg';
    await Supabase.instance.client.storage
        .from('profiles')
        .uploadBinary(path, imageBytes,
            fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));
    return Supabase.instance.client.storage.from('profiles').getPublicUrl(path);
  }

  Future<void> updateDisplayName(String name) async {
    final uid = _remote.currentUserId;
    if (uid == null) throw Exception('Not authenticated');
    await Supabase.instance.client
        .from('users')
        .update({'display_name': name})
        .eq('id', uid);
  }

  Future<void> updateProfilePhoto(String? url) async {
    final uid = _remote.currentUserId;
    if (uid == null) throw Exception('Not authenticated');
    await Supabase.instance.client
        .from('users')
        .update({'profile_photo_url': url})
        .eq('id', uid);
  }

  Future<void> incrementOffersCompleted() async {
    final uid = _remote.currentUserId;
    if (uid == null) return;
    try {
      await Supabase.instance.client.rpc(
        'increment_user_stat',
        params: {
          'p_user_id': uid,
          'p_stat': 'offers_completed',
        },
      );
    } catch (_) {}
  }
}
