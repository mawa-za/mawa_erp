import 'funeral_enums.dart';

class PickupRequestDto {
  final String? id;
  final String deceasedName;
  final String pickupLocation;
  final String contactPerson;
  final String contactNumber;
  final bool corpseInjured;
  final String? injuryDetails;
  final String? pickupLocationCode;
  final PickupStatus status;
  final String? staffId;
  final DateTime? createdAt;
  final DateTime? arrivalTime;
  final DateTime? injuryAssessedAt;
  final DateTime? completionTime;

  PickupRequestDto({
    this.id,
    required this.deceasedName,
    required this.pickupLocation,
    required this.contactPerson,
    required this.contactNumber,
    this.corpseInjured = false,
    this.injuryDetails,
    this.pickupLocationCode,
    this.status = PickupStatus.PENDING,
    this.staffId,
    this.createdAt,
    this.arrivalTime,
    this.injuryAssessedAt,
    this.completionTime,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'deceasedName': deceasedName,
      'pickupLocation': pickupLocation,
      'contactPerson': contactPerson,
      'contactNumber': contactNumber,
      'corpseInjured': corpseInjured,
      if (injuryDetails != null) 'injuryDetails': injuryDetails,
      if (pickupLocationCode != null) 'pickupLocationCode': pickupLocationCode,
      'status': status.name,
      if (staffId != null) 'staffId': staffId,
      if (staffId != null) 'assignedStaffId': staffId,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (arrivalTime != null) 'arrivalTime': arrivalTime!.toIso8601String(),
      if (injuryAssessedAt != null) 'injuryAssessedAt': injuryAssessedAt!.toIso8601String(),
      if (completionTime != null) 'completionTime': completionTime!.toIso8601String(),
    };
  }

  factory PickupRequestDto.fromJson(Map<String, dynamic> json) {
    return PickupRequestDto(
      id: json['id']?.toString(),
      deceasedName: json['deceasedName'] ?? '',
      pickupLocation: json['pickupLocation'] ?? '',
      contactPerson: json['contactPerson'] ?? '',
      contactNumber: json['contactNumber'] ?? '',
      corpseInjured: json['corpseInjured'] == true,
      injuryDetails: json['injuryDetails']?.toString(),
      pickupLocationCode: json['pickupLocationCode']?.toString(),
      status: PickupStatus.parse(json['status']),
      staffId: (json['assignedStaffId'] ?? json['staffId'])?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      arrivalTime: json['arrivalTime'] != null ? DateTime.tryParse(json['arrivalTime'].toString()) : null,
      injuryAssessedAt: json['injuryAssessedAt'] != null ? DateTime.tryParse(json['injuryAssessedAt'].toString()) : null,
      completionTime: json['completionTime'] != null ? DateTime.tryParse(json['completionTime'].toString()) : null,
    );
  }
}
