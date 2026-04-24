import 'package:dio/dio.dart';
import 'package:frontend/models/user_book_dto.dart';

class ShelfScanApi {
  ShelfScanApi(this._dio);

  final Dio _dio;

  Future<List<UserBookDto>> getLibrary() async {
    final response = await _dio.get('/api/library');

    final data = response.data;

    if (data is List) {
      return data
          .map((e) => UserBookDto.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    throw Exception('Formato risposta /api/library non valido');
  }
}