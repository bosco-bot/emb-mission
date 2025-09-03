class SearchResult {
  final String id;
  final String title;
  final String type; // 'video', 'audio', 'article', etc.
  final String? thumbnailUrl;
  final String? description;
  final DateTime publishedDate;
  final int views;

  SearchResult({
    required this.id,
    required this.title,
    required this.type,
    this.thumbnailUrl,
    this.description,
    required this.publishedDate,
    required this.views,
  });
}
