class CaseNote {
  final String id;
  final String caseId;
  final String noteType;
  final String title;
  final String note;
  final bool privateNote;
  final DateTime? createdAt;
  final String? createdBy;

  CaseNote({
    required this.id,
    required this.caseId,
    required this.noteType,
    required this.title,
    required this.note,
    this.privateNote = false,
    this.createdAt,
    this.createdBy,
  });

  factory CaseNote.fromJson(Map<String, dynamic> json) {
    return CaseNote(
      id: (json['id'] ?? '').toString(),
      caseId: (json['caseId'] ?? '').toString(),
      noteType: (json['noteType'] ?? 'GENERAL').toString(),
      title: (json['title'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
      privateNote: json['privateNote'] ?? false,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      createdBy: json['createdBy']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'caseId': caseId,
      'noteType': noteType,
      'title': title,
      'note': note,
      'privateNote': privateNote,
    };
  }
}

class CreateCaseNoteRequest {
  final String noteType;
  final String title;
  final String note;
  final bool privateNote;

  CreateCaseNoteRequest({
    required this.noteType,
    required this.title,
    required this.note,
    this.privateNote = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'noteType': noteType,
      'title': title,
      'note': note,
      'privateNote': privateNote,
    };
  }
}
