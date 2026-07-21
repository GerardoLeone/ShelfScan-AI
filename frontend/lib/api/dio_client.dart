import 'package:dio/dio.dart';
import 'package:frontend/auth/auth_repository.dart';

/*
      Interceptor aggiunge il cookie
      Easy Auth verifica il cookie e aggiunge gli header con l'identità
      Spring Boot legge quegli header
 */

// Crea un client Dio configurato per il backend ShelfScan.
class DioClient {
  DioClient(this._authRepository); //recupera il cookie di autenticazione salvato nel secure storage

  final AuthRepository _authRepository;

  Dio create() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AuthRepository.baseUrl,
        connectTimeout: const Duration(seconds: 30), //massimo 30 secondi per stabilire la connessione
        receiveTimeout: const Duration(seconds: 120), //massimo 120 secondi per ricevere la risposta
        sendTimeout: const Duration(seconds: 120), //massimo 120 secondi per inviare i dati
      ),
    );

    // L'interceptor aggiunge il cookie Easy Auth a ogni richiesta.
    /*
     * ShelfScanApi esegue una richiesta
     * -> interceptor recupera il cookie di autenticazione
     * -> aggiunge l'header Cookie
     * -> richiesta inviata al backend
     */
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