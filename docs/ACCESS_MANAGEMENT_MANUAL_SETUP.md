# MAWA Access Management — Deployment and Manual Setup

## Scope

This release introduces role-driven access management for both the Admin Console and tenant ERP applications.

Functional access remains controlled by custom role maintenance:

- **Admin Console:** `admin_role` + `admin_role_feature` + `admin_user_role`
- **ERP:** existing `role` + `role_workcenter` + `user_role`

User policy fields do not grant features. They control account classification, environment restrictions, expiry, MFA policy, tenant restrictions and whether external transactions are blocked.

## Automated changes in this release

### Admin Console

- Creates Admin Console Feature and Role Maintenance.
- Creates protected `PLATFORM_OWNER` role with automatic access to all current and future Admin Console features.
- Creates `PLATFORM_QA_TESTER` and `SUPPORT_VERIFICATION` role definitions.
- Converts the existing bootstrap `admin` user to the first protected Platform Owner.
- Prevents protected users and protected/system roles from being deleted.
- Prevents the last active Platform Owner from being locked, deactivated or demoted.
- Adds per-user tenant scope, environment scope, test-user classification, expiry, MFA policy and external-transaction restrictions.
- Requires a reason for production tenant handoff.
- Records access-management and tenant-handoff audit events.

### Tenant ERP

- Extends existing Role Maintenance with protected/system/access-all role attributes.
- Creates protected `SYSTEM` role with all current and future workcentres.
- Creates mapped `PLATFORM_QA_TESTER` and `SUPPORT_VERIFICATION` ERP roles with no workcentres assigned by default.
- Converts the existing tenant `system` user to the protected handoff principal and assigns `SYSTEM`.
- Prevents protected users and protected/system roles from being deleted.
- Prevents removal, locking or deactivation of the final active access-all tenant administrator.
- Adds user account type, test-user policy, environment restriction, expiry, MFA policy and external-transaction blocking.
- Preserves platform/test access claims when access and refresh tokens are rotated.
- Maps Platform Owner handoff to ERP `SYSTEM`.
- Maps non-owner handoff to a matching ERP role ID maintained through ERP Role Maintenance.
- Records platform-principal and tenant-user access audit events.

## Required deployment order

1. Take backups of the Admin Console database and every tenant database/schema.
2. Deploy **mawa-admin-bes** so Admin migration `V4__access_management.sql` is applied.
3. Run/deploy **mawa-flyway-runner** so tenant migration `V202607160003__access_management.sql` is applied to every tenant.
4. Deploy **mawa-bes**.
5. Deploy **mawa_erp**.
6. Deploy **mawa_erp_admin**.
7. Sign out and sign in again so the new access profile and token claims are loaded.

Do not deploy the new frontends before the matching backend and database changes.

## Required environment configuration

Confirm the following are configured for every environment:

### mawa-admin-bes

- `SPRING_PROFILES_ACTIVE` matches the target environment.
- `MAWA_ERP_API_URL` points to the matching mawa-bes endpoint.
- `MAWA_INTERNAL_SERVICE_TOKEN` is populated from Secret Manager.

### mawa-bes

- `SPRING_PROFILES_ACTIVE` matches the target environment.
- `MAWA_INTERNAL_SERVICE_TOKEN` contains exactly the same value as mawa-admin-bes.
- `MAWA_ERP_APP_URL` is the fallback ERP application URL for that environment.
- `MAWA_ADMIN_HANDOFF_USERNAME=system` unless a different protected handoff principal has deliberately been configured.
- `MAWA_ADMIN_HANDOFF_TTL_MS` is normally `300000` (five minutes).

Tenant-specific ERP URLs remain the preferred handoff destination and must be maintained correctly in Admin Console tenant configuration.

## Mandatory manual setup after deployment

### 1. Create named Platform Owners

The migration preserves the bootstrap `admin` user to prevent lockout. It should not remain the only operational owner.

In **Admin Console → Access Management → Users**:

1. Create at least two named personal users.
2. Assign the `PLATFORM_OWNER` role.
3. Require MFA.
4. Confirm that each user can access all Admin Console features and open a tenant ERP.
5. After confirming both named owners, lock the shared/bootstrap `admin` user if it is no longer needed for daily use. It cannot be deleted.

Never share one Platform Owner account between people.

### 2. Create named tenant super administrators

For every tenant, in **ERP → Role Maintenance / User Maintenance**:

1. Create at least two named tenant administrators.
2. Assign the `SYSTEM` role, or another deliberately created role with `Access all workcentres` enabled.
3. Confirm that the users can see all existing workcentres and newly introduced configuration workcentres.
4. After verification, the tenant `system` account may be locked if another active access-all administrator exists. It cannot be deleted because it remains the protected handoff principal unless handoff configuration is changed.

### 3. Configure QA handoff access

`PLATFORM_QA_TESTER` is seeded in Admin Console and ERP. The ERP role intentionally has no workcentres after migration.

For each non-production tenant that QA users may access:

1. Open **ERP → Role Maintenance**.
2. Select `PLATFORM_QA_TESTER`.
3. Assign only the workcentres required for testing.
4. In Admin Console, create named QA users.
5. Assign the Admin Console `PLATFORM_QA_TESTER` role.
6. Set `Account type = QA_TESTER`.
7. Set `Environment scope`, normally `DEV,ALPHA,BETA`.
8. Enable `Block external transactions` unless the environment is connected only to approved sandbox integrations.
9. Assign the permitted tenant scope.

The Admin Console role ID and ERP role ID must match for handoff mapping.

### 4. Configure temporary production verification

`SUPPORT_VERIFICATION` is seeded in Admin Console and ERP. The ERP role intentionally has no workcentres after migration.

1. In each applicable ERP tenant, assign only the approved read/verification workcentres to `SUPPORT_VERIFICATION`.
2. Create a named Admin Console user or temporarily assign the role to an existing named user.
3. Set `Account type = SUPPORT_VERIFICATION`.
4. Set a mandatory expiry date/time.
5. Restrict the user to explicit tenant IDs.
6. Enable `Block external transactions`.
7. Require MFA.
8. Enter an access reason and ticket/reference on every production handoff.
9. Remove the role or lock the user when the verification period ends; expiry is also enforced by the backend.

### 5. Create functional test personas in ERP Role Maintenance

Create roles such as the following only where needed:

- `QA_FINANCE`
- `QA_CLAIMS`
- `QA_MEMBERSHIP`
- `QA_FUNERAL`
- `QA_TOMBSTONE`
- `QA_INVENTORY`
- `QA_READ_ONLY`

These are ordinary custom roles. Assign their workcentres through existing ERP Role Maintenance. Do not mark them access-all unless they are intended to create a protected tenant administrator.

Testing-user account classification must be maintained separately from role assignments.

### 6. Configure integration safety

Before permitting QA or demo testing:

- Point Xero testing to an approved Xero demo organisation.
- Point FNB testing to an approved sandbox/mock implementation.
- Use test email/SMS capture where available.
- Use non-production attachment buckets.
- Keep `Block external transactions` enabled for production verification users.

The backend blocks relevant Xero, FNB/bank, secret, supplier-disbursement and refund-execution mutations for restricted interactive sessions. Integration credentials and environment routing must still be configured correctly.

`Block external transactions` is a safety control, not a substitute for sandbox configuration. Keep non-production integrations pointed at sandbox/demo endpoints even when the user-level block is enabled.

### 7. Configure real MFA enforcement

This release adds and propagates the `mfa_required` policy and displays it in both applications. It does **not** provide a new OTP/authenticator identity provider by itself.

Before treating MFA as fully enforced, connect the login flow to the chosen MFA provider or implement an OTP/authenticator challenge, and ensure successful MFA state is validated during login and sensitive production handoff.

## Role rules

### Admin Console

- `PLATFORM_OWNER` automatically receives every current and future feature.
- `PLATFORM_OWNER` cannot be deleted or weakened.
- Only an active Platform Owner can create, modify, assign or remove a protected/system role, including changing its feature assignments.
- Assigning/removing `PLATFORM_OWNER` is the only way a normal Admin Console user gains/loses protected `PLATFORM_ALL` status.
- The bootstrap system-managed `admin` user cannot have its `PLATFORM_OWNER` role removed; after a second owner is verified it may be locked, but not deleted or demoted.
- Only a Platform Owner may edit, lock, unlock or reset another protected Admin Console identity.
- `PLATFORM_QA_TESTER` and `SUPPORT_VERIFICATION` are protected role definitions, but users assigned to them remain removable unless they also receive `PLATFORM_OWNER`.
- Ordinary custom roles receive only the features selected in Admin Role Maintenance.

### ERP

- `SYSTEM` automatically receives every current and future workcentre.
- Any role with `Access all workcentres` protects users assigned to that role and derives `TENANT_ALL` access.
- Protected/system role definitions cannot be deleted.
- Only an active access-all tenant administrator can create, modify, assign or remove protected/system roles, including changing their workcentre assignments.
- The system-managed tenant `system` user cannot have its `SYSTEM` role removed; after a second access-all administrator is verified it may be locked, but not deleted or demoted.
- Only an active access-all tenant administrator may edit, lock, unlock or reset a protected ERP identity.
- `PLATFORM_QA_TESTER` and `SUPPORT_VERIFICATION` are protected role definitions but do not protect assigned/handoff users because they are not access-all.
- Ordinary users receive only workcentres assigned through existing Role Maintenance.

## Verification checklist

Run these tests in DEV or ALPHA before promoting:

1. Platform Owner sees all Admin Console features.
2. A custom Admin role sees only assigned features.
3. The last active Platform Owner cannot be locked, deleted or demoted.
4. A second Platform Owner can lock the bootstrap admin.
5. ERP `SYSTEM` sees all workcentres, including newly added workcentres.
6. The last active ERP access-all administrator cannot be locked, deleted or stripped of the final access-all role.
7. QA handoff opens ERP with `PLATFORM_QA_TESTER`, not `SYSTEM`.
8. Support handoff opens ERP with `SUPPORT_VERIFICATION`, not `SYSTEM`.
9. A mapped handoff role with no workcentres shows no operational cards until Role Maintenance assigns them.
10. An expired test/support user cannot authenticate or continue using an existing session.
11. A test user outside its allowed environment is denied.
12. A tenant-scoped Admin Console user cannot hand off to an unassigned tenant.
13. Restricted test/support sessions cannot submit Xero/FNB/external payment operations.
14. Refreshing a platform session preserves test, expiry, role, tenant and external-transaction claims.
15. Protected users and protected/system roles have no enabled Delete action and backend deletion returns a conflict response.
16. Admin and ERP audit tables receive user/role/handoff/restriction events.
17. A QA user assigned `PLATFORM_QA_TESTER` cannot modify protected users or protected role definitions.
18. A non-owner Admin user cannot add or remove `PLATFORM_OWNER` from any user.
19. A non-access-all ERP user cannot add/remove `SYSTEM` or change protected role workcentres.
20. Expired user-role assignments no longer grant protected administrator access.
21. QA/ordinary users cannot lock, unlock, edit or reset a protected identity.

## Database verification queries

### Admin Console database

```sql
SELECT id, username, status, is_protected, is_system_managed, platform_scope,
       account_type, is_test_user, environment_scope, expires_at
FROM `user`
ORDER BY username;

SELECT * FROM admin_role ORDER BY id;
SELECT * FROM admin_user_role ORDER BY user_id, role_id;
SELECT * FROM admin_role_feature ORDER BY role_id, feature_code;
SELECT * FROM admin_access_audit ORDER BY created_at DESC LIMIT 50;
```

Confirm that at least one active user is assigned `PLATFORM_OWNER` before locking or demoting any owner.

### Tenant database

```sql
SELECT id, username, status, is_protected, is_system_managed, access_scope,
       account_type, is_test_user, environment_scope, expires_at
FROM `user`
ORDER BY username;

SELECT id, description, is_system_role, is_protected, access_all_workcentres
FROM `role`
ORDER BY id;

SELECT * FROM user_role ORDER BY user, role;
SELECT * FROM platform_principal_audit ORDER BY entered_at DESC LIMIT 50;
SELECT * FROM user_access_audit ORDER BY created_at DESC LIMIT 50;
```

Confirm that `SYSTEM.access_all_workcentres = 1` and that at least one active user has an access-all role before locking an administrator.

## Rollback considerations

- Roll back application revisions together; do not run old frontend code against partially deployed access-management backends.
- The added columns and audit/role tables are backward-compatible and should normally remain in place during an application rollback.
- Do not drop role or audit tables during an incident rollback unless database backups have been verified and a dedicated reverse migration has been approved.
- If handoff fails after deployment, first verify matching internal service tokens, tenant ERP URL configuration and the mapped ERP role IDs/workcentre assignments.
