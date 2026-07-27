import 'dart:convert';

/// An application exception whose [toString] value is safe to display to users.
///
/// The original value is retained for diagnostics, while raw JSON, SQL details,
/// stack traces, HTTP implementation messages and framework exception prefixes
/// are removed from the user-facing message.
class AppException implements Exception {
  AppException(
    Object? source, {
    String? fallback,
    int? statusCode,
  })  : technicalMessage = source?.toString(),
        message = friendlyErrorMessage(
          source,
          fallback: fallback ?? 'Something went wrong. Please try again.',
          statusCode: statusCode,
        );

  AppException.fromHttp({
    required int statusCode,
    String? responseBody,
    String? fallback,
  })  : technicalMessage = responseBody,
        message = friendlyErrorMessage(
          responseBody,
          fallback: fallback ?? 'Something went wrong. Please try again.',
          statusCode: statusCode,
        );

  final String message;
  final String? technicalMessage;

  @override
  String toString() => message;
}

/// Converts any caught value into a short, actionable message suitable for a
/// snackbar, dialog or inline error state.
String friendlyErrorMessage(
  Object? error, {
  String fallback = 'Something went wrong. Please try again.',
  int? statusCode,
}) {
  if (error is AppException) return error.message;

  var raw = (error?.toString() ?? '').trim();
  if (raw.isEmpty) return fallback;

  raw = _stripExceptionPrefixes(raw);
  final envelope = _readErrorEnvelope(raw);
  final resolvedStatus = statusCode ?? envelope.statusCode ?? _statusFromText(raw);
  final candidate = _cleanMessage(envelope.message ?? raw);
  final embeddedFriendlyMessage = _embeddedFriendlyMessage(raw);
  if (embeddedFriendlyMessage != null) return embeddedFriendlyMessage;
  final lower = '$raw $candidate'.toLowerCase();

  if (_containsAny(lower, const [
    'socketexception',
    'failed host lookup',
    'network is unreachable',
    'connection refused',
    'connection reset',
    'connection closed',
    'clientexception',
    'xmlhttprequest error',
    'networkerror',
    'network error',
    'dns error',
    'no route to host',
  ])) {
    return 'We could not connect to MAWA. Check your internet connection and try again.';
  }

  if (_containsAny(lower, const [
    'timeoutexception',
    'timed out',
    'timeout',
  ])) {
    return 'The request took too long. Check your connection and try again.';
  }

  if (_containsAny(lower, const [
    'bad credentials',
    'invalid credentials',
    'invalid username or password',
    'incorrect username or password',
    'authentication failed',
  ])) {
    return 'The username or password is incorrect.';
  }

  if (resolvedStatus == 401 ||
      _containsAny(lower, const [
        'jwt expired',
        'token expired',
        'session expired',
        'unauthorized',
        'unauthorised',
      ])) {
    return 'Your session has expired. Please sign in again.';
  }

  if (resolvedStatus == 403 ||
      _containsAny(lower, const [
        'access denied',
        'forbidden',
        'not authorised',
        'not authorized',
        'insufficient permission',
      ])) {
    return 'You do not have permission to perform this action.';
  }

  if (_isDuplicateIdentity(lower)) {
    return 'A partner with this ID type and ID number already exists. Search for the existing partner instead of creating a new one.';
  }

  if (_containsAny(lower, const [
    'duplicate entry',
    'duplicate key',
    'already exists',
    'already been used',
    'unique constraint',
  ]) ||
      resolvedStatus == 409) {
    if (_isSafeBusinessMessage(candidate)) return _withPunctuation(candidate);
    return 'This record already exists. Review the information and try again.';
  }

  if (resolvedStatus == 404) {
    if (_isSafeBusinessMessage(candidate) && !_isGenericHttpMessage(candidate)) {
      return _withPunctuation(candidate);
    }
    return 'The requested information could not be found. It may have been removed or changed.';
  }

  if (resolvedStatus == 413 || lower.contains('maximum upload size')) {
    return 'The selected file is too large. Choose a smaller file and try again.';
  }

  if (resolvedStatus == 429) {
    return 'Too many requests were sent. Please wait a moment and try again.';
  }

  if (resolvedStatus != null && resolvedStatus >= 500) {
    return 'MAWA could not complete the request right now. Please try again shortly.';
  }

  if (_looksTechnical(lower, candidate)) {
    return _operationMessage(raw) ?? fallback;
  }

  final operationMessage = _operationMessage(raw);
  if (operationMessage != null) return operationMessage;

  if (_isSafeBusinessMessage(candidate)) {
    return _withPunctuation(candidate);
  }

  return fallback;
}

class _ErrorEnvelope {
  const _ErrorEnvelope({this.message, this.statusCode});

  final String? message;
  final int? statusCode;
}

_ErrorEnvelope _readErrorEnvelope(String raw) {
  final candidates = <String>[raw];
  final firstBrace = raw.indexOf('{');
  final lastBrace = raw.lastIndexOf('}');
  if (firstBrace >= 0 && lastBrace > firstBrace) {
    candidates.add(raw.substring(firstBrace, lastBrace + 1));
  }
  final firstBracket = raw.indexOf('[');
  final lastBracket = raw.lastIndexOf(']');
  if (firstBracket >= 0 && lastBracket > firstBracket) {
    candidates.add(raw.substring(firstBracket, lastBracket + 1));
  }

  for (final value in candidates) {
    try {
      final decoded = jsonDecode(value);
      final message = _messageFromJson(decoded);
      final status = _statusFromJson(decoded);
      if (message != null || status != null) {
        return _ErrorEnvelope(message: message, statusCode: status);
      }
    } catch (_) {
      // Not a JSON error envelope.
    }
  }
  return const _ErrorEnvelope();
}

String? _messageFromJson(Object? value) {
  if (value is String) return value.trim().isEmpty ? null : value.trim();
  if (value is List) {
    final messages = value
        .map(_messageFromJson)
        .whereType<String>()
        .where((item) => item.trim().isNotEmpty)
        .toList();
    return messages.isEmpty ? null : messages.take(3).join(' ');
  }
  if (value is! Map) return null;

  for (final key in const [
    'userMessage',
    'message',
    'detail',
    'error_description',
    'description',
    'reason',
  ]) {
    final message = _messageFromJson(value[key]);
    if (message != null && message.isNotEmpty) return message;
  }

  final errors = value['errors'] ?? value['fieldErrors'] ?? value['violations'];
  if (errors is Map) {
    final messages = <String>[];
    errors.forEach((key, item) {
      final message = _messageFromJson(item);
      if (message != null && message.isNotEmpty) {
        messages.add('${_humaniseField(key.toString())}: $message');
      }
    });
    if (messages.isNotEmpty) return messages.take(3).join(' ');
  }
  final nestedErrors = _messageFromJson(errors);
  if (nestedErrors != null) return nestedErrors;

  final error = value['error'];
  if (error is Map || error is List) return _messageFromJson(error);
  if (error is String && !_isGenericHttpMessage(error)) return error;

  final title = _messageFromJson(value['title']);
  if (title != null && !_isGenericHttpMessage(title)) return title;
  return null;
}

int? _statusFromJson(Object? value) {
  if (value is Map) {
    for (final key in const ['status', 'statusCode', 'httpStatus']) {
      final status = int.tryParse('${value[key] ?? ''}');
      if (status != null && status >= 100 && status <= 599) return status;
    }
    for (final item in value.values) {
      final status = _statusFromJson(item);
      if (status != null) return status;
    }
  }
  return null;
}

int? _statusFromText(String value) {
  final patterns = [
    RegExp(r'\bHTTP\s*(\d{3})\b', caseSensitive: false),
    RegExp(r'\bstatus(?:Code)?\s*[:=]?\s*(\d{3})\b', caseSensitive: false),
    RegExp(r'\((\d{3})\)\s*$'),
  ];
  for (final pattern in patterns) {
    final match = pattern.firstMatch(value);
    final status = int.tryParse(match?.group(1) ?? '');
    if (status != null && status >= 100 && status <= 599) return status;
  }
  return null;
}

String? _embeddedFriendlyMessage(String value) {
  final match = RegExp(
    r"(?:^|:\s*)((?:We (?:couldn't|could not)|The request|The selected file|The username|Your session|You do not|A partner|This record|The requested information|Too many requests|MAWA could not).+)$",
    caseSensitive: false,
  ).firstMatch(value.trim());
  final message = match?.group(1)?.trim();
  if (message == null || message.isEmpty || message.length > 320) return null;
  return _withPunctuation(message);
}

String _stripExceptionPrefixes(String value) {
  var result = value.trim();
  final prefix = RegExp(
    r'^(?:Exception|AppException|HttpException|ClientException|FormatException|StateError|Bad state)\s*:\s*',
    caseSensitive: false,
  );
  while (prefix.hasMatch(result)) {
    result = result.replaceFirst(prefix, '').trim();
  }
  return result;
}

String _cleanMessage(String value) {
  var result = _stripExceptionPrefixes(value)
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  result = result
      .replaceFirst(RegExp(r'^(?:error|failure)\s*:\s*', caseSensitive: false), '')
      .trim();

  if (result.length > 320) result = result.substring(0, 320).trim();
  return result;
}

bool _looksTechnical(String lower, String candidate) {
  return _containsAny(lower, const [
        'java.lang.',
        'org.springframework',
        'hibernate',
        'jdbc',
        'sqlstate',
        'sql syntax',
        'constraintviolationexception',
        'nullpointerexception',
        'stack trace',
        'at za.co.',
        'at java.',
        '<!doctype html',
        '<html',
        'internal server error',
        'unexpected character',
        'typeerror:',
        'nosuchmethoderror',
        'is not a subtype of type',
        'failed assertion',
      ]) ||
      candidate.contains(RegExp(r'[/\\][\w.-]+\.(?:java|dart):\d+'));
}

bool _isDuplicateIdentity(String lower) {
  final identity = lower.contains('identity') ||
      lower.contains('id type') ||
      lower.contains('identity type');
  final duplicate = lower.contains('already exists') ||
      lower.contains('duplicate') ||
      lower.contains('already been used');
  return identity && duplicate;
}

bool _isSafeBusinessMessage(String value) {
  final cleaned = value.trim();
  if (cleaned.isEmpty || cleaned.length > 260) return false;
  if (_isGenericHttpMessage(cleaned)) return false;
  final lower = cleaned.toLowerCase();
  if (_looksTechnical(lower, cleaned)) return false;
  if (RegExp(r'^\d{3}$').hasMatch(cleaned)) return false;
  if (RegExp(r'^[\[{].*[\]}]$').hasMatch(cleaned)) return false;
  if (cleaned.contains('://')) return false;
  return RegExp(r'[A-Za-z]').hasMatch(cleaned);
}

bool _isGenericHttpMessage(String value) {
  final lower = value.trim().toLowerCase();
  return const {
    'bad request',
    'unauthorized',
    'unauthorised',
    'forbidden',
    'not found',
    'conflict',
    'internal server error',
    'service unavailable',
    'gateway timeout',
    'unknown error',
    'request failed',
  }.contains(lower);
}

String? _operationMessage(String raw) {
  final cleaned = _cleanMessage(raw);
  var match = RegExp(
    r'^(?:failed|unable) to\s+(load|fetch|save|create|update|delete|remove|submit|upload|download|open|send|process|complete|generate|refresh|connect|run)\s+(.+?)(?::|\(|$)',
    caseSensitive: false,
  ).firstMatch(cleaned);
  match ??= RegExp(
    r'^error\s+(loading|fetching|saving|creating|updating|deleting|removing|submitting|uploading|downloading|opening|sending|processing|generating|refreshing|connecting|running)\s+(.+?)(?::|\(|$)',
    caseSensitive: false,
  ).firstMatch(cleaned);
  if (match == null) return null;

  var action = match.group(1)!.toLowerCase();
  const gerundToAction = {
    'loading': 'load',
    'fetching': 'fetch',
    'saving': 'save',
    'creating': 'create',
    'updating': 'update',
    'deleting': 'delete',
    'removing': 'remove',
    'submitting': 'submit',
    'uploading': 'upload',
    'downloading': 'download',
    'opening': 'open',
    'sending': 'send',
    'processing': 'process',
    'generating': 'generate',
    'refreshing': 'refresh',
    'connecting': 'connect',
    'running': 'run',
  };
  action = gerundToAction[action] ?? action;
  var subject = match.group(2)!.trim();
  subject = subject.replaceAll(RegExp(r'\s+'), ' ');
  if (subject.length > 80) subject = subject.substring(0, 80).trim();

  switch (action) {
    case 'load':
    case 'fetch':
    case 'refresh':
      return "We couldn't load $subject. Please try again.";
    case 'save':
    case 'create':
    case 'update':
    case 'submit':
    case 'process':
    case 'complete':
    case 'generate':
      return "We couldn't $action $subject. Check the information and try again.";
    case 'delete':
    case 'remove':
      return "We couldn't remove $subject. Please try again.";
    case 'upload':
      return "We couldn't upload $subject. Check the file and try again.";
    case 'download':
      return "We couldn't download $subject. Please try again.";
    case 'send':
      return "We couldn't send $subject. Please try again.";
    case 'open':
      return "We couldn't open $subject. Please try again.";
    case 'connect':
      return 'We could not connect to MAWA. Check your internet connection and try again.';
    case 'run':
      return "We couldn't run $subject. Please try again.";
  }
  return null;
}

String _humaniseField(String value) {
  return value
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (match) => '${match[1]} ${match[2]}')
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .trim();
}

String _withPunctuation(String value) {
  final cleaned = value.trim();
  if (cleaned.isEmpty) return cleaned;
  return RegExp(r'[.!?]$').hasMatch(cleaned) ? cleaned : '$cleaned.';
}

bool _containsAny(String value, List<String> patterns) {
  for (final pattern in patterns) {
    if (value.contains(pattern)) return true;
  }
  return false;
}
