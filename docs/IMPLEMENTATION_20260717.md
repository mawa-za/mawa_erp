# MAWA funeral, payments and underwriting implementation

Implemented on 2026-07-17 from the supplied project archives.

## Main changes
- Funeral packages are product-based, quantity-aware and calculate package value from item snapshots.
- Funeral invoice settlement schema stores membership-holder and deceased identity snapshots.
- Payment account configuration supports debtor accounts by request type and separate petty-cash/cash-claim creditor accounts.
- Payment creation derives EFT vs MANUAL from active bank integration; FNB remains the current gateway extension.
- Manual payment completion requires a proof attachment belonging to the payment request.
- Supplier invoice payment rules use supplier partner banking; petty cash uses configured creditor banking or MANUAL fallback.
- Approval USER/ROLE/GROUP/MANAGER rules are database-backed and one user can action a step once.
- Third-party funeral underwriters, policies, beneficiaries and underwriting decisions use dedicated tables and v2 APIs.
- Password reset returns to /login.
- Existing tombstone frontend routes/screens are retained and available through the workcenter route registry.

## New APIs
- GET/POST/DELETE `/v2/payment-account-configurations`
- GET/POST `/v2/funeral-underwriting/underwriters`
- GET/POST `/v2/funeral-underwriting/covers`
- GET `/v2/funeral-underwriting/covers/{id}`
- POST `/v2/funeral-underwriting/covers/{id}/decision`

## Migration
`V202607170001__funeral_payment_underwriting_and_manual_receipts.sql`
