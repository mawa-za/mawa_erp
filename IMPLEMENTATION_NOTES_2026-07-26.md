# ERP Operational Configuration and Forms UI

Implemented on 2026-07-26 against the supplied `mawa_erp(56).zip` source.

## User-facing changes

- Shared dropdowns for bank names, bank account types, provinces, sales areas, and causes of death.
- Exactly 10-digit numeric contact validation on applicable forms.
- Supplier Invoice payment request flow with supplier-only recipients, fixed EFT, and read-only approved supplier banking.
- Pickup questionnaire with injury details and camera/photo-library injury uploads.
- Mandatory warehouse, storage location, and bin selection when completing a pickup.
- Reusable Storage Configuration screen.
- Claim Type Configuration and Membership Policy Configuration screens.
- Burial date and plan-benefit claim amount display/resolution.
- Guided Payment Account Configuration and simplified FNB Integration Administration.
- Removed generic System Setting tile in favour of domain-specific configuration.
- Completed Third Party Funeral Cover Underwriting administration.
- Dedicated Company Forms workcenter for preview/download/print/share.
- Company Forms Configuration for protected system administrators to publish a new version or unpublish a form.

## Mobile permissions/dependencies

- Added `image_picker: ^1.1.2`.
- Added Android camera/media permissions.
- Added iOS camera and photo-library usage descriptions.

Run `flutter pub get` before building so the lockfile can be resolved for the target Flutter SDK.

## Validation performed

- Dart delimiter/source-structure validation.
- Relative import resolution scan.
- Android manifest and iOS plist XML parsing.
- `pubspec.yaml` and Cloud Build YAML parsing.

Flutter analyze/test/build could not be executed because Flutter and Dart SDKs were not installed in the sandbox.
