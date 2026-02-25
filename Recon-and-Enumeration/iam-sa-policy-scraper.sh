#!/bin/bash

# GCP service account list and roles scraper. 
# Lists service accounts availbale in GCP workspace and lists attached roles to service accounts.
# Must have authenticated gcloud cli client for functionality. No other dependencies required.
# Usage: ./gcp_sa-policy.sh [optional_project_id]

set -euo pipefail

# Determine PROJECT_ID
if [ -n "${1:-}" ]; then
  PROJECT_ID="$1"
else
  PROJECT_ID=$(gcloud projects list --format="value(projectId)" | grep -v '^$' | head -n 1)
  if [ -z "$PROJECT_ID" ]; then
    echo "Error: No accessible projects found."
    exit 1
  fi
fi

echo "Hunting service accounts in: $PROJECT_ID"
echo "---------------------------------------"

# List SAs → save raw table output
gcloud iam service-accounts list --project="$PROJECT_ID" > serviceaccounts.txt 2>/dev/null || {
  echo "Failed to list service accounts."
  exit 1
}

# Extract only emails (robust regex for your table format)
grep -oE '[^ ]+@[^ ]+\.gserviceaccount\.com' serviceaccounts.txt | sort -u > sa_emails.txt

if [ ! -s sa_emails.txt ]; then
  echo "No service accounts found."
  rm -f serviceaccounts.txt sa_emails.txt
  exit 0
fi

echo "Found $(wc -l < sa_emails.txt) service accounts"
echo ""

# For each SA: show exact default policy output (matches your example)
while read -r sa_email; do
  echo "=== $sa_email ==="
  gcloud iam service-accounts get-iam-policy "$sa_email" \
    --project="$PROJECT_ID" 2>/dev/null || {
    echo "  Failed to get policy (missing iam.serviceAccounts.getIamPolicy?)"
  }
  echo ""
done < sa_emails.txt

# Cleanup
rm -f serviceaccounts.txt sa_emails.txt

echo "Done."
