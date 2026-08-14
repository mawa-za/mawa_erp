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
