import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';

final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivityService = ref.watch(connectivityServiceProvider);
  return connectivityService.onConnectivityChanged;
});
