# PROD v2 manual release deployment

`cloudbuild.prod-v2.yaml` builds and deploys this component only from a manually selected GitHub tag matching `v2*release`.
The build validates that the tag commit is contained in `master`, pushes release and commit image tags, resolves the immutable digest, creates the runtime service account and missing Secret Manager resources, grants per-secret access, and deploys the Cloud Run resource.

Required secrets are declared in `deploy/prod-v2/secrets.env`. A missing secret resource is created automatically, but sensitive values are never generated or replaced. Deployment stops when a required secret has no enabled version.

Create the Cloud Build manual trigger from the release coordinator bundle, or run the build configuration directly with a tag-aware trigger. Configure `_CLOUD_SQL_INSTANCE`, `_STORAGE_BUCKET`, `_BILLING_BASE_URL`, and `_VPC_CONNECTOR` where applicable.
