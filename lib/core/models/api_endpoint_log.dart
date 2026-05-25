class ApiEndpointLog {
  final String id;
  final String? requestId;
  final String? userId;
  final String? username;
  final String method;
  final String endpoint;
  final String? queryString;
  final int statusCode;
  final String? requestIp;
  final String? userAgent;
  final int durationMs;
  final bool success;
  final String? errorMessage;
  final String createdAt;

  ApiEndpointLog({
    required this.id,
    this.requestId,
    this.userId,
    this.username,
    required this.method,
    required this.endpoint,
    this.queryString,
    required this.statusCode,
    this.requestIp,
    this.userAgent,
    required this.durationMs,
    required this.success,
    this.errorMessage,
    required this.createdAt,
  });

  factory ApiEndpointLog.fromJson(Map<String, dynamic> json) {
    return ApiEndpointLog(
      id: (json['id'] ?? '').toString(),
      requestId: json['requestId']?.toString(),
      userId: json['userId']?.toString(),
      username: json['username']?.toString(),
      method: (json['method'] ?? '').toString(),
      endpoint: (json['endpoint'] ?? '').toString(),
      queryString: json['queryString']?.toString(),
      statusCode: json['statusCode'] is int ? json['statusCode'] : int.tryParse(json['statusCode']?.toString() ?? '0') ?? 0,
      requestIp: json['requestIp']?.toString(),
      userAgent: json['userAgent']?.toString(),
      durationMs: json['durationMs'] is int ? json['durationMs'] : int.tryParse(json['durationMs']?.toString() ?? '0') ?? 0,
      success: json['success'] == true,
      errorMessage: json['errorMessage']?.toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'requestId': requestId,
      'userId': userId,
      'username': username,
      'method': method,
      'endpoint': endpoint,
      'queryString': queryString,
      'statusCode': statusCode,
      'requestIp': requestIp,
      'userAgent': userAgent,
      'durationMs': durationMs,
      'success': success,
      'errorMessage': errorMessage,
      'createdAt': createdAt,
    };
  }
}
