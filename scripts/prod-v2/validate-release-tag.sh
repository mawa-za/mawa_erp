#!/usr/bin/env bash
set -euo pipefail

: "${TAG_NAME:?TAG_NAME is required}"
: "${COMMIT_SHA:?COMMIT_SHA is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GITHUB_TOKEN:?GITHUB_TOKEN is required}"

if [[ ! "${TAG_NAME}" =~ ^v2.*release$ ]]; then
  echo "Release tag '${TAG_NAME}' is invalid. Expected a tag matching ^v2.*release$." >&2
  exit 2
fi

api="https://api.github.com/repos/${GITHUB_REPOSITORY}"
auth_header="Authorization: Bearer ${GITHUB_TOKEN}"
accept_header="Accept: application/vnd.github+json"

TAG_NAME="${TAG_NAME}" COMMIT_SHA="${COMMIT_SHA}" API="${api}" AUTH_HEADER="${auth_header}" ACCEPT_HEADER="${accept_header}" python3 - <<'PYVALIDATE'
import json, os, subprocess, sys, urllib.parse

tag = os.environ['TAG_NAME']
expected = os.environ['COMMIT_SHA'].lower()
api = os.environ['API']
headers = ["-H", os.environ['AUTH_HEADER'], "-H", os.environ['ACCEPT_HEADER'], "-H", "X-GitHub-Api-Version: 2022-11-28"]

def get(path):
    result = subprocess.run(["curl", "-fsS", *headers, f"{api}{path}"], capture_output=True, text=True)
    if result.returncode != 0:
        sys.stderr.write(result.stderr)
        raise SystemExit(f"GitHub API request failed for {path}")
    return json.loads(result.stdout)

commit = get('/commits/' + urllib.parse.quote(tag, safe=''))
actual = str(commit.get('sha', '')).lower()
if actual != expected:
    raise SystemExit(f"Trigger commit {expected} does not match GitHub tag {tag} commit {actual}")

comparison = get('/compare/' + urllib.parse.quote(tag, safe='') + '...master')
status = comparison.get('status')
if status not in {'ahead', 'identical'}:
    raise SystemExit(f"Tag {tag} is not reachable from master (GitHub comparison status: {status})")
print(f"Validated {tag} at {actual}: tag commit is contained in master.")
PYVALIDATE
