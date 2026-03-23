#!/bin/bash
# gcp-kms-keyring-enum.sh
# Enumerates all available KMS locations from 'gcloud kms locations list'
# Then lists keyrings in every location where HSM_AVAILABLE or EKM_AVAILABLE = True
# Output: All keyrings visible to your current authenticated gcloud session

set -euo pipefail

echo "GCP KMS Keyring Enumeration"
echo "Active project: $(gcloud config get-value project 2>/dev/null || echo 'Not set')"
echo "Active account: $(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null || echo 'Not set')"
echo ""
echo "[*] Step 1: Fetching available KMS locations..."
echo "----------------------------------------"

# Capture locations list output
LOCATIONS_OUTPUT=$(gcloud kms locations list 2>&1)

if [[ $? -ne 0 ]]; then
    echo "ERROR: Failed to run 'gcloud kms locations list'"
    echo "Output:"
    echo "$LOCATIONS_OUTPUT"
    exit 1
fi

# Extract location IDs where HSM_AVAILABLE or EKM_AVAILABLE is True
# Skip header line, look for True in columns 2 or 3
AVAILABLE_LOCATIONS=$(echo "$LOCATIONS_OUTPUT" | \
  awk 'NR>1 && ($2 == "True" || $3 == "True") {print $1}' | \
  sort -u)

if [[ -z "$AVAILABLE_LOCATIONS" ]]; then
    echo "No locations with HSM_AVAILABLE=True or EKM_AVAILABLE=True found."
    echo "Either no KMS locations available, or missing kms.locations.list permission."
    echo ""
    echo "Raw output for debug:"
    echo "$LOCATIONS_OUTPUT"
    exit 0
fi

echo "Found $(echo "$AVAILABLE_LOCATIONS" | wc -l) available locations:"
echo "$AVAILABLE_LOCATIONS" | sed 's/^/  - /'
echo ""

echo "[*] Step 2: Enumerating keyrings in each location..."
echo "----------------------------------------"

for LOC in $AVAILABLE_LOCATIONS; do
    echo "[+] Location: $LOC"
    echo "  Keyrings:"

    # Run keyrings list and capture output
    KEYRINGS=$(gcloud kms keyrings list --location="$LOC" --format="table(name,createTime)" 2>&1)

    if echo "$KEYRINGS" | grep -q "Listed 0 items"; then
        echo "    No keyrings found in $LOC"
    elif echo "$KEYRINGS" | grep -q "PERMISSION_DENIED"; then
        echo "    Access denied (missing kms.keyRings.list in $LOC)"
    elif echo "$KEYRINGS" | grep -q "ERROR"; then
        echo "    Command failed:"
        echo "      $KEYRINGS"
    else
        # Print table (skip header line if present)
        echo "$KEYRINGS" | sed 's/^/      /' | tail -n +2
    fi
    echo ""
done

echo "Enumeration complete."
echo ""
echo "Next steps if keyrings found:"
echo "  gcloud kms keys list --location=LOCATION --keyring=KEYRING_NAME"
echo "  gcloud kms keys versions list --location=LOCATION --keyring=KEYRING_NAME --key=KEY_NAME"
