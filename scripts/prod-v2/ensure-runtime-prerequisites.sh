#!/usr/bin/env bash
set -euo pipefail

: "${PROJECT_ID:?PROJECT_ID is required}"
: "${RUNTIME_SERVICE_ACCOUNT:?RUNTIME_SERVICE_ACCOUNT is required}"
: "${SECRETS_FILE:?SECRETS_FILE is required}"

RUNTIME_SERVICE_ACCOUNT_EMAIL="${RUNTIME_SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com"
OUTPUT_FILE="${SECRETS_OUTPUT_FILE:-/workspace/prod-v2-secrets.txt}"

# PROD identities/permissions are normally provisioned already. IAM policy WRITES
# can take seconds each and were repeated on every deployment. Read the current
# policy and update only missing grants; never weaken the existing permissions.
policy_has_binding() {
  local policy_file="$1" role="$2" member="$3"
  python3 - "$policy_file" "$role" "$member" <<'PYPOLICY'
import json, sys
policy_file, role, member = sys.argv[1:]
with open(policy_file) as stream:
    policy = json.load(stream)
for binding in policy.get('bindings', []):
    if binding.get('role') == role and not binding.get('condition') and member in binding.get('members', []):
        raise SystemExit(0)
raise SystemExit(1)
PYPOLICY
}

member="serviceAccount:${RUNTIME_SERVICE_ACCOUNT_EMAIL}"
if ! gcloud iam service-accounts describe "${RUNTIME_SERVICE_ACCOUNT_EMAIL}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud iam service-accounts create "${RUNTIME_SERVICE_ACCOUNT}" \
    --project="${PROJECT_ID}" --display-name="MAWA PROD v2 runtime: ${RUNTIME_SERVICE_ACCOUNT}"
fi

project_policy=""
cleanup() { [[ -z "${project_policy}" ]] || rm -f "${project_policy}"; }
trap cleanup EXIT
# Only obtain the project IAM policy for runtimes requiring project-level roles.
if [[ -n "${CLOUD_SQL_INSTANCE:-}" ]]; then
  project_policy="$(mktemp)"
  gcloud projects get-iam-policy "${PROJECT_ID}" --format=json > "${project_policy}"
fi

if [[ -n "${CLOUD_SQL_INSTANCE:-}" ]] && ! policy_has_binding "${project_policy}" "roles/cloudsql.client" "${member}"; then
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="${member}" --role="roles/cloudsql.client" --condition=None --quiet >/dev/null
fi

if [[ -n "${STORAGE_BUCKET:-}" ]]; then
  bucket_policy="$(mktemp)"
  if ! gcloud storage buckets get-iam-policy "gs://${STORAGE_BUCKET}" --project="${PROJECT_ID}" --format=json > "${bucket_policy}"; then
    rm -f "${bucket_policy}"
    exit 1
  fi
  if ! policy_has_binding "${bucket_policy}" "${STORAGE_ROLE:-roles/storage.objectAdmin}" "${member}"; then
    gcloud storage buckets add-iam-policy-binding "gs://${STORAGE_BUCKET}" \
      --member="${member}" --role="${STORAGE_ROLE:-roles/storage.objectAdmin}" --quiet >/dev/null
  fi
  rm -f "${bucket_policy}"
fi

bindings=()
while IFS='|' read -r env_name secret_name requirement; do
  [[ -z "${env_name// }" || "${env_name}" =~ ^[[:space:]]*# ]] && continue
  env_name="$(echo "${env_name}" | xargs)"
  secret_name="$(echo "${secret_name}" | xargs)"
  requirement="$(echo "${requirement:-required}" | xargs)"

  if [[ -z "${env_name}" || -z "${secret_name}" ]]; then
    echo "Invalid secret declaration in ${SECRETS_FILE}: ${env_name}|${secret_name}|${requirement}" >&2
    exit 3
  fi

  # One version lookup on the ordinary path, not describe + list per secret.
  if ! version="$(gcloud secrets versions list "${secret_name}" --project="${PROJECT_ID}" \
      --filter='state=ENABLED' --sort-by='~createTime' --limit=1 --format='value(name)' 2>/dev/null)"; then
    # Preserve first-time provisioning behaviour without masking permission errors.
    if gcloud secrets describe "${secret_name}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
      echo "Cannot list versions of existing secret ${secret_name}." >&2
      exit 1
    fi
    gcloud secrets create "${secret_name}" --project="${PROJECT_ID}" \
      --replication-policy=automatic --labels="environment=prod,managed-by=cloud-build,release-generation=v2"
    echo "Created Secret Manager resource ${secret_name}; no secret value was generated." >&2
    version="$(gcloud secrets versions list "${secret_name}" --project="${PROJECT_ID}" \
      --filter='state=ENABLED' --sort-by='~createTime' --limit=1 --format='value(name)')"
  fi

  if [[ -z "${version}" ]]; then
    if [[ "${requirement}" == "optional" ]]; then
      echo "Optional secret ${secret_name} has no enabled version; ${env_name} will not be bound." >&2
      continue
    fi
    echo "Required secret ${secret_name} has no enabled version." >&2
    echo "Add the existing PROD value without a trailing newline, then rerun the build:" >&2
    echo "  printf '%s' '<VALUE>' | gcloud secrets versions add ${secret_name} --project=${PROJECT_ID} --data-file=-" >&2
    exit 4
  fi
  version="${version##*/}"

  # Existing secret grants are read-only on normal deployments. New grants
  # are applied only if missing (e.g., new runtime service account or secret).
  secret_policy="$(mktemp)"
  gcloud secrets get-iam-policy "${secret_name}" --project="${PROJECT_ID}" --format=json > "${secret_policy}"
  if ! policy_has_binding "${secret_policy}" "roles/secretmanager.secretAccessor" "${member}"; then
    gcloud secrets add-iam-policy-binding "${secret_name}" --project="${PROJECT_ID}" \
      --member="${member}" --role="roles/secretmanager.secretAccessor" --quiet >/dev/null
  fi
  rm -f "${secret_policy}"
  bindings+=("${env_name}=${secret_name}:${version}")
done < "${SECRETS_FILE}"

(IFS=,; echo "${bindings[*]}") > "${OUTPUT_FILE}"
echo "Prepared ${#bindings[@]} version-pinned secret binding(s) for ${RUNTIME_SERVICE_ACCOUNT_EMAIL}."
