import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/user_provider.dart';

class RefreshableScrollView extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;
  final Widget child;
  final Future<void> Function()? onRefresh;

  const RefreshableScrollView({
    super.key,
    this.padding,
    required this.child,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: onRefresh ?? () async {
        ref.invalidate(userProfileStreamProvider);
      },
      child: SingleChildScrollView(
        key: key,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        child: child,
      ),
    );
  }
}

class RefreshableListView extends ConsumerWidget {
  final EdgeInsetsGeometry? padding;
  final List<Widget> children;

  const RefreshableListView({
    super.key,
    this.padding,
    required this.children,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(userProfileStreamProvider);
      },
      child: ListView(
        key: key,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: children,
      ),
    );
  }
}
