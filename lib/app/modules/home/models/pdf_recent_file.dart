class PdfRecentFile {
  const PdfRecentFile({
    required this.path,
    required this.name,
    required this.lastOpenedAt,
    this.lastPage = 1,
    this.description,
    this.coverPath,
  });

  final String path;
  final String name;
  final DateTime lastOpenedAt;
  final int lastPage;
  final String? description;
  final String? coverPath;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'path': path,
      'name': name,
      'lastOpenedAt': lastOpenedAt.toIso8601String(),
      'lastPage': lastPage,
      if (description != null) 'description': description,
      if (coverPath != null) 'coverPath': coverPath,
    };
  }

  factory PdfRecentFile.fromJson(Map<String, dynamic> json) {
    return PdfRecentFile(
      path: json['path'] as String? ?? '',
      name: json['name'] as String? ?? '',
      lastOpenedAt: DateTime.tryParse(json['lastOpenedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastPage: json['lastPage'] as int? ?? 1,
      description: json['description'] as String?,
      coverPath: json['coverPath'] as String?,
    );
  }

  PdfRecentFile copyWith({
    String? path,
    String? name,
    DateTime? lastOpenedAt,
    int? lastPage,
    Object? description = _sentinel,
    Object? coverPath = _sentinel,
  }) {
    return PdfRecentFile(
      path: path ?? this.path,
      name: name ?? this.name,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      lastPage: lastPage ?? this.lastPage,
      description: identical(description, _sentinel)
          ? this.description
          : description as String?,
      coverPath: identical(coverPath, _sentinel)
          ? this.coverPath
          : coverPath as String?,
    );
  }
}

const Object _sentinel = Object();
