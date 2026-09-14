import '../../../core/utils/app_date_utils.dart';

class PosPrinter {
  final String id;
  final String agentId;
  final String windowsQueueName;
  final String displayName;
  final String printerRole;
  final String status;
  final bool defaultPrinter;
  final bool supportsCut;
  final int paperWidthChars;

  const PosPrinter({
    required this.id,
    required this.agentId,
    required this.windowsQueueName,
    required this.displayName,
    required this.printerRole,
    required this.status,
    required this.defaultPrinter,
    required this.supportsCut,
    required this.paperWidthChars,
  });

  bool get online => status.toUpperCase() == 'ONLINE';

  factory PosPrinter.fromJson(Map<String, dynamic> json) => PosPrinter(
        id: (json['id'] ?? '').toString(),
        agentId: (json['agentId'] ?? '').toString(),
        windowsQueueName: (json['windowsQueueName'] ?? '').toString(),
        displayName: (json['displayName'] ?? json['windowsQueueName'] ?? '').toString(),
        printerRole: (json['printerRole'] ?? 'RECEIPT').toString(),
        status: (json['status'] ?? 'OFFLINE').toString(),
        defaultPrinter: json['defaultPrinter'] == true,
        supportsCut: json['supportsCut'] == true,
        paperWidthChars: (json['paperWidthChars'] as num?)?.toInt() ?? 42,
      );
}

class PosPrintAgent {
  final String id;
  final String name;
  final String machineName;
  final String location;
  final String status;
  final bool online;
  final String agentVersion;
  final String? lastHeartbeatAt;
  final List<PosPrinter> printers;

  const PosPrintAgent({
    required this.id,
    required this.name,
    required this.machineName,
    required this.location,
    required this.status,
    required this.online,
    required this.agentVersion,
    required this.lastHeartbeatAt,
    required this.printers,
  });

  bool get active => status.toUpperCase() == 'ACTIVE';

  factory PosPrintAgent.fromJson(Map<String, dynamic> json) => PosPrintAgent(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        machineName: (json['machineName'] ?? '').toString(),
        location: (json['location'] ?? '').toString(),
        status: (json['status'] ?? '').toString(),
        online: json['online'] == true,
        agentVersion: (json['agentVersion'] ?? '').toString(),
        lastHeartbeatAt: json['lastHeartbeatAt'] == null ? null : AppDateUtils.normalizeDateTime(json['lastHeartbeatAt']),
        printers: ((json['printers'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => PosPrinter.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class PosTerminal {
  final String id;
  final String terminalKey;
  final String displayName;
  final String location;
  final String? agentId;
  final String? defaultReceiptPrinterId;
  final String? defaultDocumentPrinterId;
  final bool enabled;

  const PosTerminal({
    required this.id,
    required this.terminalKey,
    required this.displayName,
    required this.location,
    required this.agentId,
    required this.defaultReceiptPrinterId,
    required this.defaultDocumentPrinterId,
    required this.enabled,
  });

  bool get configured =>
      enabled &&
      agentId != null &&
      agentId!.isNotEmpty &&
      defaultReceiptPrinterId != null &&
      defaultReceiptPrinterId!.isNotEmpty;

  factory PosTerminal.fromJson(Map<String, dynamic> json) => PosTerminal(
        id: (json['id'] ?? '').toString(),
        terminalKey: (json['terminalKey'] ?? '').toString(),
        displayName: (json['displayName'] ?? '').toString(),
        location: (json['location'] ?? '').toString(),
        agentId: json['agentId']?.toString(),
        defaultReceiptPrinterId: json['defaultReceiptPrinterId']?.toString(),
        defaultDocumentPrinterId: json['defaultDocumentPrinterId']?.toString(),
        enabled: json['enabled'] != false,
      );
}

class PosEnrollmentCode {
  final String code;
  final String expiresAt;
  final String agentName;
  final String location;

  const PosEnrollmentCode({required this.code, required this.expiresAt, required this.agentName, required this.location});

  factory PosEnrollmentCode.fromJson(Map<String, dynamic> json) => PosEnrollmentCode(
        code: (json['code'] ?? '').toString(),
        expiresAt: AppDateUtils.normalizeDateTime(json['expiresAt']),
        agentName: (json['agentName'] ?? '').toString(),
        location: (json['location'] ?? '').toString(),
      );
}

class PosPrintJob {
  final String id;
  final String sourceType;
  final String sourceId;
  final String? receiptId;
  final String terminalId;
  final String agentId;
  final String printerId;
  final String printerQueueName;
  final String status;
  final int attemptCount;
  final int maxAttempts;
  final String? createdAt;
  final String? updatedAt;
  final String? spooledAt;
  final String? lastError;

  const PosPrintJob({required this.id, required this.sourceType, required this.sourceId,
    required this.receiptId, required this.terminalId, required this.agentId,
    required this.printerId, required this.printerQueueName, required this.status,
    required this.attemptCount, required this.maxAttempts, required this.createdAt,
    required this.updatedAt, required this.spooledAt, required this.lastError});

  bool get terminal => status == 'SPOOLED' || status == 'FAILED';
  bool get failed => status == 'FAILED';
  bool get aged {
    final value = createdAt == null ? null : DateTime.tryParse(createdAt!);
    return value != null && status != 'SPOOLED' && DateTime.now().difference(value.toLocal()).inMinutes >= 2;
  }

  factory PosPrintJob.fromJson(Map<String, dynamic> json) => PosPrintJob(
    id: (json['id'] ?? '').toString(), sourceType: (json['sourceType'] ?? '').toString(),
    sourceId: (json['sourceId'] ?? '').toString(), receiptId: json['receiptId']?.toString(),
    terminalId: (json['terminalId'] ?? '').toString(), agentId: (json['agentId'] ?? '').toString(),
    printerId: (json['printerId'] ?? '').toString(), printerQueueName: (json['printerQueueName'] ?? '').toString(),
    status: (json['status'] ?? 'QUEUED').toString().toUpperCase(),
    attemptCount: (json['attemptCount'] as num?)?.toInt() ?? 0,
    maxAttempts: (json['maxAttempts'] as num?)?.toInt() ?? 5,
    createdAt: json['createdAt'] == null ? null : AppDateUtils.normalizeDateTime(json['createdAt']),
    updatedAt: json['updatedAt'] == null ? null : AppDateUtils.normalizeDateTime(json['updatedAt']),
    spooledAt: json['spooledAt'] == null ? null : AppDateUtils.normalizeDateTime(json['spooledAt']),
    lastError: json['lastError']?.toString(),
  );
}
