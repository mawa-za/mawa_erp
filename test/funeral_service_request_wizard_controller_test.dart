import 'package:flutter_test/flutter_test.dart';
import 'package:mawa_erp/features/funeral/data/models/funeral_enums.dart';
import 'package:mawa_erp/features/funeral/data/models/funeral_membership_cover_dto.dart';
import 'package:mawa_erp/features/funeral/data/models/funeral_package_dto.dart';
import 'package:mawa_erp/features/funeral/presentation/controllers/funeral_service_request_wizard_controller.dart';

void main() {
  group('Funeral arrangement calculations', () {
    late FuneralServiceRequestWizardController controller;

    setUp(() {
      controller = FuneralServiceRequestWizardController();
      controller.packages = [
        FuneralPackageDto(
          id: 'package-1',
          name: 'Pothole Funeral Package',
          basePriceCents: 4500000,
          inclusions: const [],
        ),
      ];
    });

    tearDown(() {
      controller.dispose();
    });

    test('uses the only available package in the total calculation', () {
      expect(controller.effectiveSelectedPackage?.id, 'package-1');
      expect(controller.packageAmountCents, 4500000);
      expect(controller.arrangementTotalCents, 4500000);
    });

    test('uses funeral benefit when one cover is selected', () {
      controller.selectedCovers = [
        _cover(
          id: 'cover-1',
          funeralAmountCents: 2000000,
          combinationAmountCents: 1000000,
        ),
      ];

      expect(controller.selectedCoverTotalCents, 2000000);
      expect(controller.shortfallCents, 2500000);
    });

    test('uses combination benefits only when multiple covers are selected', () {
      controller.selectedCovers = [
        _cover(
          id: 'cover-1',
          funeralAmountCents: 2000000,
          combinationAmountCents: 1000000,
        ),
        _cover(
          id: 'cover-2',
          funeralAmountCents: 1500000,
          combinationAmountCents: 500000,
        ),
      ];

      expect(controller.selectedCoverTotalCents, 1500000);
      expect(controller.shortfallCents, 3000000);
    });

    test('falls back to normal funeral amount when combination is not configured', () {
      controller.selectedCovers = [
        _cover(
          id: 'cover-1',
          funeralAmountCents: 2000000,
          combinationAmountCents: 1000000,
        ),
        _cover(
          id: 'cover-2',
          funeralAmountCents: 1500000,
          combinationAmountCents: 0,
        ),
      ];

      expect(controller.selectedCoverTotalCents, 2500000);
      expect(controller.shortfallCents, 2000000);
    });
  });
}

FuneralMembershipCoverDto _cover({
  required String id,
  required int funeralAmountCents,
  required int combinationAmountCents,
}) {
  return FuneralMembershipCoverDto(
    membershipId: id,
    burialSocietyName: 'Test Society',
    coverAmountCents: funeralAmountCents,
    funeralAmountCents: funeralAmountCents,
    combinationAmountCents: combinationAmountCents,
    membershipNumber: id,
    coverSource: CoverSource.LOCAL_TENANT,
  );
}
