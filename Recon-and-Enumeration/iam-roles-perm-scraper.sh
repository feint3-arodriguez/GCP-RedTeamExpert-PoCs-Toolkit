#!/bin/bash

# GCP-RolePerm-Enum v1.0
# Automates GCP IAM role enumeration and permission description. Native gcloud cli requirement only not other dependencies.
# Dynamically sets PROJECT_ID from first accessible project via gcloud.
# Must be authenticated to gcloud CLI before executing.
# Usage: ./gcp_role_enum.sh [optional_project_id]  # Overrides auto-detect if provided.

if [ -n "$1" ]; then
  PROJECT_ID="$1"
else
  PROJECT_ID=$(gcloud projects list --format="value(projectId)" | grep -v '^$' | head -n 1)
  if [ -z "$PROJECT_ID" ]; then
    echo "Error: No accessible projects found. Ensure gcloud auth is set."
    exit 1
  fi
fi

echo "Using PROJECT_ID: $PROJECT_ID"

# Step 1: Dump IAM policy roles cleanly (includes all bound roles, custom or predefined)
gcloud projects get-iam-policy "$PROJECT_ID" \
  --flatten="bindings[].role" \
  --format="value(bindings.role)" | sort -u > clean_roles.txt

# Step 2: Also add all custom roles defined in project (even if unbound)
gcloud iam roles list --project="$PROJECT_ID" --format="value(name)" | sort -u >> clean_roles.txt
sort -u clean_roles.txt -o clean_roles.txt  # Dedupe combined list

# Step 3: Describe each role's permissions
while read -r role; do
  if [[ -z "$role" ]]; then continue; fi
  if [[ $role == projects/* ]]; then
    role_id="${role##*/roles/}"
    echo -e "\n=== CUSTOM ROLE: $role_id ==="
    gcloud iam roles describe "$role_id" --project="$PROJECT_ID" --format="yaml(includedPermissions)" 2>/dev/null || echo "Describe failed (perms or role issue)"
  else
    role_id="${role#roles/}"
    echo -e "\n=== PREDEFINED ROLE: $role_id ==="
    gcloud iam roles describe "$role_id" --format="yaml(includedPermissions)" 2>/dev/null || echo "Describe failed"
  fi
done < clean_roles.txt

# Cleanup temp files
rm -f clean_roles.txt
