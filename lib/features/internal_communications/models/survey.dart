enum SurveyType { pulse, feedback, engagement }
enum SurveyStatus { draft, active, closed }
enum QuestionType { singleChoice, multipleChoice, text, rating }

class Survey {
  final String id;
  final String title;
  final String description;
  final SurveyType type;
  final SurveyStatus status;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<SurveyQuestion> questions;
  final int participantCount;
  final String? createdBy;
  final DateTime? createdAt;

  Survey({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    this.startDate,
    this.endDate,
    this.questions = const [],
    this.participantCount = 0,
    this.createdBy,
    this.createdAt,
  });

  factory Survey.fromJson(Map<String, dynamic> json) {
    return Survey(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: SurveyType.values.firstWhere(
        (e) => e.name == (json['type']?.toString().toLowerCase()),
        orElse: () => SurveyType.feedback,
      ),
      status: SurveyStatus.values.firstWhere(
        (e) => e.name == (json['status']?.toString().toLowerCase()),
        orElse: () => SurveyStatus.draft,
      ),
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate']) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate']) : null,
      questions: (json['questions'] as List? ?? [])
          .map((q) => SurveyQuestion.fromJson(Map<String, dynamic>.from(q)))
          .toList(),
      participantCount: json['participantCount'] ?? 0,
      createdBy: json['createdBy']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name.toUpperCase(),
      'status': status.name.toUpperCase(),
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }
}

class SurveyQuestion {
  final String id;
  final String text;
  final QuestionType type;
  final List<String> options;
  final bool isRequired;

  SurveyQuestion({
    required this.id,
    required this.text,
    required this.type,
    this.options = const [],
    this.isRequired = true,
  });

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) {
    return SurveyQuestion(
      id: json['id']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      type: QuestionType.values.firstWhere(
        (e) => e.name == (json['type']?.toString()),
        orElse: () => QuestionType.text,
      ),
      options: List<String>.from(json['options'] ?? []),
      isRequired: json['isRequired'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'type': type.name,
      'options': options,
      'isRequired': isRequired,
    };
  }
}
