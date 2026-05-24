import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class RefreshableScrollView extends StatelessWidget {
  final EdgeInsetsGeometry? padding;
  final Widget child;

  const RefreshableScrollView({
    super.key,
    this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<AppState>().refreshCoins(),
      child: SingleChildScrollView(
        key: key,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        child: child,
      ),
    );
  }
}

class RefreshableListView extends StatelessWidget {
  final EdgeInsetsGeometry? padding;
  final List<Widget> children;

  const RefreshableListView({
    super.key,
    this.padding,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<AppState>().refreshCoins(),
      child: ListView(
        key: key,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: padding,
        children: children,
      ),
    );
  }
}
