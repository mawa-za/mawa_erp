#!/usr/bin/env bash
set -euo pipefail

: "${PROJECT_ID:?PROJECT_ID is required}"
: "${REGION:?REGION is required}"
: "${SERVICE_NAME:?SERVICE_NAME is required}"
: "${RUNTIME_SERVICE_ACCOUNT:?RUNTIME_SERVICE_ACCOUNT is required}"
: "${IMAGE_REF_FILE:?IMAGE_REF_FILE is required}"
: "${TAG_NAME:?TAG_NAME is required}"

IMAGE_REF="$(cat "${IMAGE_REF_FILE}")"
RUNTIME_SERVICE_ACCOUNT_EMAIL="${RUNTIME_SERVICE_ACCOUNT}@${PROJECT_ID}.iam.gserviceaccount.com"
SECRETS_OUTPUT_FILE="/workspace/${SERVICE_NAME}-secrets.txt"

PROJECT_ID="${PROJECT_ID}" RUNTIME_SERVICE_ACCOUNT="${RUNTIME_SERVICE_ACCOUNT}" SECRETS_FILE="deploy/prod-v2/secrets.env" SECRETS_OUTPUT_FILE="${SECRETS_OUTPUT_FILE}" CLOUD_SQL_INSTANCE="${CLOUD_SQL_INSTANCE:-}" STORAGE_BUCKET="${STORAGE_BUCKET:-}" STORAGE_ROLE="${STORAGE_ROLE:-roles/storage.objectAdmin}"   ./scripts/prod-v2/ensure-runtime-prerequisites.sh

cp deploy/prod-v2/service.env "/workspace/${SERVICE_NAME}.env"
{
  echo "MAWA_RELEASE_TAG=${TAG_NAME}"
  echo "MAWA_RELEASE_COMMIT=${COMMIT_SHA:-unknown}"
  [[ -n "${STORAGE_BUCKET:-}" ]] && echo "MAWA_ATTACHMENT_BUCKET=${STORAGE_BUCKET}"
  [[ -n "${BILLING_BASE_URL:-}" ]] && echo "MAWA_BILLING_BASE_URL=${BILLING_BASE_URL}"
} >> "/workspace/${SERVICE_NAME}.env"

secret_bindings="$(cat "${SECRETS_OUTPUT_FILE}")"
build_suffix="${CLOUD_BUILD_ID:-manual}"
build_suffix="$(echo "${build_suffix}" | tr -cd '[:alnum:]' | tr '[:upper:]' '[:lower:]' | cut -c1-8)"
revision_suffix="$(echo "${TAG_NAME}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//' | cut -c1-38)-${SHORT_SHA:-build}-${build_suffix:-manual}"
revision_suffix="$(echo "${revision_suffix}" | sed -E 's/[^a-z0-9-]+/-/g; s/^-+//; s/-+$//' | cut -c1-63)"

args=(
  run deploy "${SERVICE_NAME}"
  --project="${PROJECT_ID}"
  --region="${REGION}"
  --platform=managed
  --image="${IMAGE_REF}"
  --service-account="${RUNTIME_SERVICE_ACCOUNT_EMAIL}"
  --port=8080
  --cpu="${CPU:-1}"
  --memory="${MEMORY:-1Gi}"
  --min-instances="${MIN_INSTANCES:-0}"
  --max-instances="${MAX_INSTANCES:-10}"
  --concurrency="${CONCURRENCY:-80}"
  --timeout="${REQUEST_TIMEOUT:-300s}"
  --execution-environment=gen2
  --env-vars-file="/workspace/${SERVICE_NAME}.env"
  --revision-suffix="${revision_suffix}"
  --labels="environment=prod,release-generation=v2,component=${COMPONENT_LABEL:-mawa}"
  --quiet
)

if [[ -n "${secret_bindings}" ]]; then args+=(--set-secrets="${secret_bindings}"); fi
if [[ -n "${CLOUD_SQL_INSTANCE:-}" ]]; then args+=(--set-cloudsql-instances="${CLOUD_SQL_INSTANCE}"); fi
if [[ -n "${VPC_CONNECTOR:-}" ]]; then args+=(--vpc-connector="${VPC_CONNECTOR}" --vpc-egress="${VPC_EGRESS:-private-ranges-only}"); fi
if [[ "${ALLOW_UNAUTHENTICATED:-true}" == "true" ]]; then args+=(--allow-unauthenticated); else args+=(--no-allow-unauthenticated); fi

gcloud "${args[@]}"

if [[ -f deploy/prod-v2/invokers.txt ]]; then
  while IFS= read -r invoker; do
    [[ -z "${invoker// }" || "${invoker}" =~ ^[[:space:]]*# ]] && continue
    if [[ "${invoker}" != *@* ]]; then invoker="${invoker}@${PROJECT_ID}.iam.gserviceaccount.com"; fi
    gcloud run services add-iam-policy-binding "${SERVICE_NAME}"       --project="${PROJECT_ID}" --region="${REGION}"       --member="serviceAccount:${invoker}" --role="roles/run.invoker" --quiet >/dev/null
  done < deploy/prod-v2/invokers.txt
fi

if [[ "${ALLOW_UNAUTHENTICATED:-true}" != "true" && -n "${BUILD_SERVICE_ACCOUNT_EMAIL:-}" ]]; then
  gcloud run services add-iam-policy-binding "${SERVICE_NAME}"     --project="${PROJECT_ID}" --region="${REGION}"     --member="serviceAccount:${BUILD_SERVICE_ACCOUNT_EMAIL}" --role="roles/run.invoker" --quiet >/dev/null
fi

service_url="$(gcloud run services describe "${SERVICE_NAME}" --project="${PROJECT_ID}" --region="${REGION}" --format='value(status.url)')"
health_path="${HEALTH_PATH:-/actuator/health/readiness}"
if [[ "${ALLOW_UNAUTHENTICATED:-true}" == "true" ]]; then
  curl -fsS --retry 8 --retry-delay 5 --retry-all-errors "${service_url}${health_path}" >/dev/null
else
  token="$(gcloud auth print-identity-token --audiences="${service_url}")"
  curl -fsS --retry 8 --retry-delay 5 --retry-all-errors -H "Authorization: Bearer ${token}" "${service_url}${health_path}" >/dev/null
fi

echo "Deployed ${SERVICE_NAME} at ${service_url} using ${IMAGE_REF}."
