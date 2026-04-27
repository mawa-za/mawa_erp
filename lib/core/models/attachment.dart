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
    final docType = json['documentType'] as Map<String, dynamic>?;
    final uploadBy = json['uploadBy'] as Map<String, dynamic>?;
    
    return Attachment(
      id: json['id'] ?? '',
      description: docType?['description'] ?? 'Document',
      extension: json['extension'] ?? '',
      uploadDate: json['uploadDate'] ?? '',
      uploadedBy: '${uploadBy?['name2'] ?? ''} ${uploadBy?['name1'] ?? ''}'.trim(),
    );
  }
}
