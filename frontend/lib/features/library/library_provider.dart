import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/api/dio_client.dart';
import 'package:frontend/api/shelfscan_api.dart';
import 'package:frontend/auth/auth_controller.dart';
import 'package:frontend/models/user_book_dto.dart';

final dioProvider = Provider((ref) {
  final authRepository = ref.read(authRepositoryProvider);
  return DioClient(authRepository).create();
});

final shelfScanApiProvider = Provider((ref) {
  final dio = ref.read(dioProvider);
  return ShelfScanApi(dio);
});

/*
 * Essendo un FutureProvider, Riverpod gestisce automaticamente 3 strati:
 * loading
 * data
 * error
 */
final libraryProvider = FutureProvider<List<UserBookDto>>((ref) async {
  final api = ref.read(shelfScanApiProvider);
  return api.getLibrary(); //get di tutti i libri
});