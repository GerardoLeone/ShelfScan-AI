class UserBookDto {
  final int id;
  final int bookId;
  final String title;
  final String author;
  final String? coverUrl;
  final String status;
  final List<String> tags;

  const UserBookDto({
    required this.id,
    required this.bookId,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.status,
    required this.tags,
  });

  factory UserBookDto.fromJson(Map<String, dynamic> json) {
    return UserBookDto(
      id: _asInt(json['id']),
      bookId: _asInt(json['bookId'] ?? json['book_id'] ?? json['book']?['id']),
      title: _asString(json['title'] ?? json['book']?['title']),
      author: _asString(json['author'] ?? json['book']?['author']),
      coverUrl: _asNullableString(
        json['coverUrl'] ??
            json['cover_url'] ??
            json['imageUrl'] ??
            json['image_url'] ??
            json['book']?['coverUrl'] ??
            json['book']?['cover_url'],
      ),
      status: _asString(json['status'], fallback: 'TO_READ'),
      tags: _asStringList(json['tags'] ?? json['book']?['tags']),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString();
  }

  static String? _asNullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
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