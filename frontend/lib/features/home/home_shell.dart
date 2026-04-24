import 'package:flutter/material.dart';
import 'package:frontend/features/home/widget/bottom_nav.dart';
import 'package:go_router/go_router.dart';

class HomeShell extends StatelessWidget {
  final Widget child;

  const HomeShell({super.key, required this.child});

  int _locationToIndex(String location) {
    if (location.startsWith('/scan')) return 1;
    if (location.startsWith('/profile')) return 2;
    return 0; // /home
  }

  void _onTap(BuildContext context, int idx) {
    switch (idx) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/scan');
        break;
      case 2:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final idx = _locationToIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNav(index: idx, onTap: (i) => _onTap(context, i)),
    );
  }
}