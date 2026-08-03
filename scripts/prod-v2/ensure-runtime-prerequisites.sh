#!/usr/bin/env bash
set -euo pipefail

: "${PROJECT_ID:?PROJECT_ID is required}"
: "${RUNTIME_SERVICE_ACCOUNT:?RUNTIME_SERVICE_ACCOUNT is required}"
: "${SECRETS_FILE:?SECRETS_FILE is required}"

RUNTIME_SERVICE_ACCOUNT_EMAIL="${RUNTIME_SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com"
OUTPUT_FILE="${SECRETS_OUTPUT_FILE:-/workspace/prod-v2-secrets.txt}"

if ! gcloud iam service-accounts describe "${RUNTIME_SERVICE_ACCOUNT_EMAIL}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
  gcloud iam service-accounts create "${RUNTIME_SERVICE_ACCOUNT}"     --project="${PROJECT_ID}"     --display-name="MAWA PROD v2 runtime: ${RUNTIME_SERVICE_ACCOUNT}"
fi

if [[ -n "${CLOUD_SQL_INSTANCE:-}" ]]; then
  gcloud projects add-iam-policy-binding "${PROJECT_ID}"     --member="serviceAccount:${RUNTIME_SERVICE_ACCOUNT_EMAIL}"     --role="roles/cloudsql.client"     --condition=None --quiet >/dev/null
fi

if [[ -n "${STORAGE_BUCKET:-}" ]]; then
  gcloud storage buckets describe "gs://${STORAGE_BUCKET}" --project="${PROJECT_ID}" >/dev/null
  gcloud storage buckets add-iam-policy-binding "gs://${STORAGE_BUCKET}"     --member="serviceAccount:${RUNTIME_SERVICE_ACCOUNT_EMAIL}"     --role="${STORAGE_ROLE:-roles/storage.objectAdmin}" --quiet >/dev/null
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

  if ! gcloud secrets describe "${secret_name}" --project="${PROJECT_ID}" >/dev/null 2>&1; then
    gcloud secrets create "${secret_name}" --project="${PROJECT_ID}"       --replication-policy=automatic       --labels="environment=prod,managed-by=cloud-build,release-generation=v2"
    echo "Created Secret Manager resource ${secret_name}; no secret value was generated." >&2
  fi

  version="$(gcloud secrets versions list "${secret_name}" --project="${PROJECT_ID}"     --filter='state=ENABLED' --sort-by='~createTime' --limit=1 --format='value(name)')"

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

  gcloud secrets add-iam-policy-binding "${secret_name}" --project="${PROJECT_ID}"     --member="serviceAccount:${RUNTIME_SERVICE_ACCOUNT_EMAIL}"     --role="roles/secretmanager.secretAccessor" --quiet >/dev/null
  bindings+=("${env_name}=${secret_name}:${version}")
done < "${SECRETS_FILE}"

(IFS=,; echo "${bindings[*]}") > "${OUTPUT_FILE}"
echo "Prepared ${#bindings[@]} version-pinned secret binding(s) for ${RUNTIME_SERVICE_ACCOUNT_EMAIL}."
