import 'package:dio/dio.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthRepository {
  static const String baseUrl =
      'https://shelfscanai-dev-hqdnaphzd7emfff8.francecentral-01.azurewebsites.net';
  static const String _cookieKey = 'app_service_auth_cookie';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> getCookieHeader() async {
    return _storage.read(key: _cookieKey);
  }

  Future<void> saveSessionCookie(String value) async {
    await _storage.write(
      key: _cookieKey,
      value: 'AppServiceAuthSession=$value',
    );
  }

  Future<bool> isAuthenticated() async {
    final cookie = await getCookieHeader();
    if (cookie == null || cookie.isEmpty) return false;

    try {
      final dio = Dio();
      final response = await dio.get(
        '$baseUrl/.auth/me',
        options: Options(
          headers: {
            'Cookie': cookie,
          },
          validateStatus: (_) => true,
        ),
      );

      return response.statusCode == 200 &&
          response.data is List &&
          (response.data as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<String?> getUserName() async {
    final cookie = await getCookieHeader();
    if (cookie == null) return null;

    try {
      final dio = Dio();
      final response = await dio.get(
        '$baseUrl/.auth/me',
        options: Options(
          headers: {
            'Cookie': cookie,
          },
          validateStatus: (_) => true,
        ),
      );

      if (response.statusCode != 200 || response.data is! List) return null;

      final list = response.data as List;
      if (list.isEmpty) return null;

      final user = list.first;
      return user['user_id']?.toString() ??
          user['user_claims']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    final cookie = await getCookieHeader();

    if (cookie != null) {
      final dio = Dio();

      await dio.get(
        '$baseUrl/.auth/logout',
        options: Options(
          headers: {
            'Cookie': cookie,
          },
          validateStatus: (_) => true,
        ),
      );
    }

    await _storage.delete(key: _cookieKey);
    await CookieManager.instance().deleteAllCookies();
  }

  Future<bool> refreshSession() async {
    final cookie = await getCookieHeader();
    if (cookie == null || cookie.isEmpty) return false;

    try {
      final dio = Dio();

      final response = await dio.get(
        '$baseUrl/.auth/refresh',
        options: Options(
          headers: {
            'Cookie': cookie,
          },
          validateStatus: (_) => true,
        ),
      );

      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }
}