import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:frontend/models/user_book_dto.dart';

// Usa il client HTTP Dio per chiamare gli endpoint REST
class ShelfScanApi {
  ShelfScanApi(this._dio);

  final Dio _dio;

  Future<void> updateStatus({
    required int bookId,
    required String status,
    int? currentPage,
  }) async {
    await _dio.patch(
      '/api/library/$bookId/status',
      data: {
        'status': status,
        'currentPage': currentPage,
      },
    );
  }

  Future<UserBookDto> getLibraryItem(int bookId) async {
    final response = await _dio.get('/api/library/$bookId');

    final data = response.data;

    if (data is Map<String, dynamic>) {
      return UserBookDto.fromJson(data);
    }

    throw Exception('Formato risposta /api/library/$bookId non valido');
  }

  Future<void> updateLibraryItem({
    required int bookId,
    required String customTitle,
    required List<String> customTags,
  }) async {
    await _dio.patch(
      '/api/library/$bookId/metadata',
      data: {
        'customTitle': customTitle,
        'customTags': customTags,
      },
    );
  }

  Future<void> removeFromLibrary(int bookId) async {
    await _dio.delete('/api/library/$bookId');
  }

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

  // Analizza la copertina e restituisce un'anteprima.
  // Il libro non viene ancora inserito nella libreria.
  Future<ScanPreviewDto> previewScan(File imageFile) async {
    final fileName = imageFile.path.split('/').last;

    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile( //usa multipart perchè la richiesta contiene un file binario
        imageFile.path,
        filename: fileName,
      ),
    });

    final response = await _dio.post(
      '/api/scan/preview',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    final data = response.data;

    if (data is Map<String, dynamic>) {
      return ScanPreviewDto.fromJson(data);
    }

    throw Exception('Formato risposta /api/scan/preview non valido');
  }

  // Conferma l'inserimento dopo la revisione dell'utente.
  Future<UserBookDto> confirmScan({
    required File imageFile,
    required ScanPreviewDto preview,
    required String customTitle,
    required List<String> customTags,
  }) async {
    final fileName = imageFile.path.split('/').last;

    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        imageFile.path,
        filename: fileName,
      ),
      if (preview.matchedBookId != null) 'matchedBookId': preview.matchedBookId,

      //canonical
      'canonicalTitle': preview.title,
      if (preview.author.trim().isNotEmpty) 'canonicalAuthor': preview.author.trim(),
      if (preview.description.trim().isNotEmpty) 'canonicalDescription': preview.description.trim(),
      'canonicalTagsJson': jsonEncode(preview.tags),

      //customs
      if (customTitle.trim().isNotEmpty) 'customTitle': customTitle.trim(),
      'customTagsJson': jsonEncode(customTags),
    });

    final response = await _dio.post(
      '/api/scan/confirm',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    final data = response.data;

    if (data is Map<String, dynamic>) {
      return UserBookDto.fromJson(data);
    }

    throw Exception('Formato risposta /api/scan/confirm non valido');
  }
}

// Rappresenta la risposta della preview
class ScanPreviewDto {
  final int? matchedBookId;
  final String title;
  final String author;
  final String? coverUrl;
  final String description;
  final List<String> tags;
  final double confidence;
  final bool existingBook;

  const ScanPreviewDto({
    required this.matchedBookId,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.description,
    required this.tags,
    required this.confidence,
    required this.existingBook,
  });

  factory ScanPreviewDto.fromJson(Map<String, dynamic> json) {
    return ScanPreviewDto(
      matchedBookId: _asNullableInt(json['matchedBookId']), //Identificativo del libro matched
      title: _asString(json['title']),
      author: _asString(json['author']),
      coverUrl: _asNullableString(json['coverUrl']),
      description: _asString(json['description']),
      tags: _asStringList(json['tags']),
      confidence: _asDouble(json['confidence']),
      existingBook: json['existingBook'] == true, //Se il libro è già presente nel database (utile alla UI)
    );
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String _asString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }

  static String? _asNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static List<String> _asStringList(dynamic value) {
    if (value == null) return const [];

    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (value is String) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return const [];
  }
}