import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';

// Provides a cached list of offers from the backend (with Redis backing)
final offersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(supabaseRepositoryProvider);
  final resp = await repo.callEdgeFunction('get-offers', body: {'platform': 'android'});
  if (resp['success'] == true && resp['offers'] is List) {
    return List<Map<String, dynamic>>.from(resp['offers'] as List);
  }
  return [];
});

// Provides the user's reward redemption history from the backend
final rewardHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(supabaseRepositoryProvider);
  return repo.getRedeemedRewards(limit: 50);
});

// Provides the leaderboard for a specific game (or 'weekly' if empty)
final leaderboardProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, gameName) async {
  final repo = ref.read(supabaseRepositoryProvider);
  final body = gameName.isNotEmpty ? {'gameName': gameName, 'limit': 50} : {'limit': 50};
  final resp = await repo.callEdgeFunction('get-leaderboard', body: body);
  if (resp['entries'] is List) {
    return List<Map<String, dynamic>>.from(resp['entries'] as List);
  }
  return [];
});

// Provides quiz categories and questions from the backend
final quizzesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.read(supabaseRepositoryProvider);
  return repo.getQuizzes();
});
