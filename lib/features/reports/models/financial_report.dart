class FinancialReport {
  final DateTime generatedAt;
  final String currency;
  final Map<String, int> summary;
  final List<Map<String, dynamic>> rows;
  const FinancialReport({required this.generatedAt,required this.currency,required this.summary,required this.rows});
  factory FinancialReport.fromJson(Map<String,dynamic> json)=>FinancialReport(
    generatedAt: DateTime.parse('${json['generatedAt']}'), currency:'${json['currency'] ?? 'ZAR'}',
    summary: Map<String,dynamic>.from(json['summary'] as Map? ?? const {}).map((k,v)=>MapEntry(k,(v as num?)?.toInt() ?? 0)),
    rows:(json['rows'] as List? ?? const []).whereType<Map>().map((e)=>Map<String,dynamic>.from(e)).toList());
}
