import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/auth/auth_repository.dart';
import 'package:frontend/auth/auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authControllerProvider =
AsyncNotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final repo = ref.read(authRepositoryProvider);
    final authenticated = await repo.isAuthenticated();

    if (!authenticated) {
      return const AuthState.unauthenticated();
    }

    final userName = await repo.getUserName();

    return AuthState.authenticated(
      userName: userName,
    );
  }

  Future<void> refreshAuthState() async {
    state = const AsyncLoading();

    final repo = ref.read(authRepositoryProvider);
    final authenticated = await repo.isAuthenticated();

    if (!authenticated) {
      state = const AsyncData(AuthState.unauthenticated());
      return;
    }

    final userName = await repo.getUserName();

    state = AsyncData(
      AuthState.authenticated(userName: userName),
    );
  }

  Future<void> logout() async {
    state = const AsyncLoading();

    final repo = ref.read(authRepositoryProvider);
    await repo.logout();

    state = const AsyncData(AuthState.unauthenticated());
  }
}