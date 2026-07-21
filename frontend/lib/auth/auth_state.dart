//STATO LOGICO dell'autenticazione
class AuthState {
  final bool isAuthenticated;
  final String? userName;

  const AuthState({
    required this.isAuthenticated,
    this.userName,
  });

  const AuthState.unauthenticated()
      : isAuthenticated = false,
        userName = null;

  const AuthState.authenticated({String? userName})
      : isAuthenticated = true,
        userName = userName;
}