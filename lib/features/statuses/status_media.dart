enum StatusMediaType { image, video }

class StatusMedia {
  final String path;
  final StatusMediaType type;
  final DateTime createdAt;

  const StatusMedia({
    required this.path,
    required this.type,
    required this.createdAt,
  });

  bool get isVideo => type == StatusMediaType.video;
}
