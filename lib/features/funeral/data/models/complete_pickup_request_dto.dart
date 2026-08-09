class CompletePickupRequestDto {
  final DateTime completionTime;
  final String warehouseId;
  final String storageLocationId;
  final String storageBinId;

  CompletePickupRequestDto({
    required this.completionTime,
    required this.warehouseId,
    required this.storageLocationId,
    required this.storageBinId,
  });

  Map<String, dynamic> toJson() => {
        'completionTime': completionTime.toIso8601String(),
        'warehouseId': warehouseId,
        'storageLocationId': storageLocationId,
        'storageBinId': storageBinId,
      };
}
