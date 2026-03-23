#!/bin/bash
# gcp-bucket-enum-and-ls.sh
# Enumerates GCP Storage buckets via asset search, then lists contents of each
# Focuses on interesting files (flag, kms, key, json, etc.)

set -euo pipefail

echo "GCP Storage Bucket Enumeration + Content Listing"
echo "Active project: $(gcloud config get-value project 2>/dev/null || echo 'Not set')"
echo "Active account: $(gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null || echo 'Not set')"
echo ""

# Step 1: Enumerate buckets using your working asset search method
echo "[*] Enumerating buckets via asset search..."
echo "----------------------------------------"

PROJECT_ID=$(gcloud config get-value project 2>/dev/null || echo "gcp-labs-6db1oc31")

BUCKETS=$(gcloud asset search-all-resources \
    --scope="projects/$PROJECT_ID" \
    --filter="assetType=storage.googleapis.com/Bucket" \
    --format="value(displayName)" 2>/dev/null | sort -u)

if [[ -z "$BUCKETS" ]]; then
    echo "[-] No buckets found or asset search failed."
    echo "    Try manual: gcloud asset search-all-resources --scope=projects/$PROJECT_ID --filter=\"assetType=storage.googleapis.com/Bucket\""
    exit 1
fi

echo "Found $(echo "$BUCKETS" | wc -l) buckets:"
echo "$BUCKETS" | sed 's/^/  gs:\/\//'
echo ""

# Step 2: List contents of each bucket (simple ls + keyword filter)
echo "[*] Listing contents of each bucket..."
echo "----------------------------------------"

INTERESTING_KEYWORDS="cipher|flag|kms|key|enc|json|txt|md|secret|cred|token|pass|api|db|config|pdf|doc|docx|xls|xlsx|ppt|pptx|csv|log|bak|zip|rar|tar|gz|jpg|jpeg|png|gif|bmp|tiff|mp4|avi|mov|mkv|sql|xml|yaml|yml|env|properties|pem|p12|keystore|backup|archive|dump|export|private|public|cert|certificate|auth|login|user|admin|root|sudo|hash|salt|iv|nonce|exe|dll|sh|py|js|php|asp|jsp|war|ear|jar|class|so|dylib|deb|rpm|iso|img|vmdk|ova|qcow2|vhdx|parquet|delta|avro|orc|netcdf|geotiff|shp|dbf"

for BUCKET in $BUCKETS; do
    echo "=== gs://$BUCKET/ ==="

    # Run ls, limit to first 10 lines, grep for interesting names
    gcloud storage ls "gs://$BUCKET/" --project="$PROJECT_ID" 2>/dev/null | \
        head -n 15 | \
        grep -iE "$INTERESTING_KEYWORDS" || echo "  No interesting files found or access denied"

    echo ""
done

echo "Enumeration complete."
echo ""
echo "Manual next steps:"
echo "  gcloud storage ls gs://BUCKET_NAME -r               # Full recursive list"
echo "  gcloud storage cp gs://BUCKET_NAME/path/file .      # Download file"
echo "  gsutil ls -L gs://BUCKET_NAME                        # Detailed metadata"
echo "  gcloud storage buckets get-iam-policy gs://BUCKET_NAME  # IAM policy"
