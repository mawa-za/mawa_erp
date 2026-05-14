class Attachment {
  final String id;
  final String description;
  final String extension;
  final String uploadDate;
  final String uploadedBy;

  Attachment({
    required this.id,
    required this.description,
    required this.extension,
    required this.uploadDate,
    required this.uploadedBy,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    // Safely handle Map vs List for nested objects
    Map<String, dynamic>? docType;
    if (json['documentType'] is Map) {
      docType = Map<String, dynamic>.from(json['documentType']);
    }

    Map<String, dynamic>? uploadBy;
    if (json['uploadBy'] is Map) {
      uploadBy = Map<String, dynamic>.from(json['uploadBy']);
    }
    
    return Attachment(
      id: (json['id'] ?? '').toString(),
      description: docType?['description']?.toString() ?? 'Document',
      extension: (json['extension'] ?? '').toString(),
      uploadDate: (json['uploadDate'] ?? '').toString(),
      uploadedBy: '${uploadBy?['name2'] ?? ''} ${uploadBy?['name1'] ?? ''}'.trim(),
    );
  }
}
