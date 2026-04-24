import 'package:dio/dio.dart';
import 'package:frontend/auth/auth_repository.dart';

class DioClient {
  DioClient(this._authRepository);

  final AuthRepository _authRepository;

  Dio create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AuthRepository.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final cookie = await _authRepository.getCookieHeader();

          if (cookie != null && cookie.isNotEmpty) {
            options.headers['Cookie'] = cookie;
          }

          return handler.next(options);
        },
      ),
    );

    return dio;
  }
}