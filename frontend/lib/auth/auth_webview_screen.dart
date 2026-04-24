import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/auth/auth_controller.dart';
import 'package:frontend/auth/auth_repository.dart';

class AuthWebViewScreen extends ConsumerStatefulWidget {
  const AuthWebViewScreen({super.key});

  @override
  ConsumerState<AuthWebViewScreen> createState() => _AuthWebViewScreenState();
}

class _AuthWebViewScreenState extends ConsumerState<AuthWebViewScreen> {
  bool _completed = false;

  static const String _loginUrl =
      '${AuthRepository.baseUrl}/.auth/login/aad?post_login_redirect_uri=/';

  Future<void> _tryCompleteLogin() async {
    if (_completed) return;

    final cookies = await CookieManager.instance().getCookies(
      url: WebUri(AuthRepository.baseUrl),
    );

    final sessionCookie = cookies
        .where((cookie) => cookie.name == 'AppServiceAuthSession')
        .firstOrNull;

    if (sessionCookie == null || sessionCookie.value.isEmpty) return;

    _completed = true;

    await ref
        .read(authRepositoryProvider)
        .saveSessionCookie(sessionCookie.value);

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accesso Microsoft'),
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri(_loginUrl),
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          thirdPartyCookiesEnabled: true,
          sharedCookiesEnabled: true,
        ),
        onLoadStop: (_, __) async {
          await _tryCompleteLogin();
        },
        onUpdateVisitedHistory: (_, __, ___) async {
          await _tryCompleteLogin();
        },
      ),
    );
  }
}