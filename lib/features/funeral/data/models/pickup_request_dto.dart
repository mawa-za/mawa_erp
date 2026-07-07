import 'funeral_enums.dart';

class PickupRequestDto {
  final String? id;
  final String deceasedName;
  final String pickupLocation;
  final String contactPerson;
  final String contactNumber;
  final PickupStatus status;
  final String? staffId;
  final DateTime? createdAt;
  final DateTime? completionTime;

  PickupRequestDto({
    this.id,
    required this.deceasedName,
    required this.pickupLocation,
    required this.contactPerson,
    required this.contactNumber,
    this.status = PickupStatus.PENDING,
    this.staffId,
    this.createdAt,
    this.completionTime,
  });

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'deceasedName': deceasedName,
      'pickupLocation': pickupLocation,
      'contactPerson': contactPerson,
      'contactNumber': contactNumber,
      'status': status.name,
      if (staffId != null) 'staffId': staffId,
      if (staffId != null) 'assignedStaffId': staffId,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
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
      status: PickupStatus.parse(json['status']),
      staffId: (json['assignedStaffId'] ?? json['staffId'])?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null,
      completionTime: json['completionTime'] != null ? DateTime.tryParse(json['completionTime'].toString()) : null,
    );
  }
}
