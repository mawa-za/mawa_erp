# MAWA ERP build fix

Corrected Cloud Build compilation errors introduced by feature-group routing:

- Replaced missing `AppRoutes.inventory` with `/feature-groups/inventory`.
- Replaced missing `AppRoutes.appointments` with `/feature-groups/scheduling`.
- Verified all remaining `AppRoutes.*` references in `lib/` resolve to constants defined in `app_routes.dart`.

Recommended commit message:

`fix(routing): correct inventory and scheduling group routes`
