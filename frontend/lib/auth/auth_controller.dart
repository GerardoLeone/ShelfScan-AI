import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/auth/auth_repository.dart';
import 'package:frontend/auth/auth_state.dart';

//Rende disponibile l'istanza di AuthRepository tramite Riverpod
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

  //Dopo aver completato il login refresh della pagina
  // Easy Auth può impiegare un breve intervallo per rendere disponibile
  // la nuova sessione dopo il login nella WebView, quindi riprova /.auth/me.
  Future<void> refreshAuthState() async {
    state = const AsyncLoading();

    final repo = ref.read(authRepositoryProvider);

    debugPrint('AUTH: check /.auth/me');

    bool authenticated = await repo.isAuthenticated();

    debugPrint('AUTH: isAuthenticated = $authenticated');

    if (!authenticated) {
      debugPrint('AUTH: try /.auth/refresh');

      final refreshed = await repo.refreshSession();

      debugPrint('AUTH: refresh result = $refreshed');

      await Future.delayed(const Duration(milliseconds: 500));
    }

    for (int i = 0; i < 5; i++) {
      debugPrint('AUTH: retry ${i + 1}');

      authenticated = await repo.isAuthenticated();

      debugPrint('AUTH: authenticated = $authenticated');

      if (authenticated) {
        break;
      }

      if (i < 4) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    if (!authenticated) {
      debugPrint('AUTH: FAILED');
      state = const AsyncData(AuthState.unauthenticated());
      return;
    }

    final userName = await repo.getUserName();

    debugPrint('AUTH: SUCCESS user=$userName');

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