# Reporting implementation — 18 July 2026

## Added

- Reports workcentre route and dashboard.
- Dedicated reporting API client and environment host mapping.
- Membership totals and status cards.
- Memberships-per-plan table.
- Paid, unpaid, partially-paid and outstanding premium reporting.
- Dynamic claim-type monthly breakdown.
- Period selector for 6, 12, 18 or 24 periods.
- Model and reporting-host tests.

The ERP sends the existing bearer token and selected role to `mawa-reporting-bes`. It does not send or choose the reporting tenant; the service derives the tenant from the signed JWT claim.
