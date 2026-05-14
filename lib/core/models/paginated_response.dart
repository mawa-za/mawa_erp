class PaginatedResponse<T> {
  final int totalPages;
  final int totalElements;
  final bool first;
  final bool last;
  final int size;
  final int number;
  final int numberOfElements;
  final bool empty;
  final List<T> content;

  PaginatedResponse({
    required this.totalPages,
    required this.totalElements,
    required this.first,
    required this.last,
    required this.size,
    required this.number,
    required this.numberOfElements,
    required this.empty,
    required this.content,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    final List<dynamic> contentList = json['content'] is List ? json['content'] : [];
    
    return PaginatedResponse<T>(
      totalPages: json['totalPages'] ?? 0,
      totalElements: json['totalElements'] ?? 0,
      first: json['first'] ?? false,
      last: json['last'] ?? false,
      size: json['size'] ?? 0,
      number: json['number'] ?? 0,
      numberOfElements: json['numberOfElements'] ?? 0,
      empty: json['empty'] ?? contentList.isEmpty,
      content: contentList
          .map((item) => fromJsonT(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}
