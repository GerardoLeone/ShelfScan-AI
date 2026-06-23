import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/home/home_shell.dart';
import '../features/home/home_screen.dart';
import '../features/scan/scan_screen.dart';
import '../features/auth/profile_screen.dart';
import '../features/book/book_detail_screen.dart';
import '../models/user_book_dto.dart';

final router = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) => HomeShell(child: child),
      routes: [
        GoRoute(
          path: '/books/:bookId',
          pageBuilder: (context, state) {
            final bookId = int.parse(state.pathParameters['bookId']!);
            final initialBook = state.extra is UserBookDto
                ? state.extra as UserBookDto
                : null;

            return _buildTransitionPage(
              key: state.pageKey,
              child: BookDetailScreen(
                bookId: bookId,
                initialBook: initialBook,
              ),
            );
          },
        ),
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => _buildTransitionPage(
            key: state.pageKey,
            child: const HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/scan',
          pageBuilder: (context, state) => _buildTransitionPage(
            key: state.pageKey,
            child: const ScanScreen(),
          ),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => _buildTransitionPage(
            key: state.pageKey,
            child: const ProfileScreen(),
          ),
        ),
      ],
    ),
  ],
);

CustomTransitionPage<void> _buildTransitionPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slideAnimation = Tween<Offset>(
        begin: const Offset(0.08, 0),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
      );

      return SlideTransition(
        position: slideAnimation,
        child: child,
      );
    },
  );
}