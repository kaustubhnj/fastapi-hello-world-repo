#!/bin/bash
# 04-setup-permissions.sh
# Configure IAM permissions

set -e

echo "=== GCP CI/CD Pipeline Setup - Step 4: Setup Permissions ==="

# Load environment variables or create them if .env doesn't exist
if [ -f ".env" ]; then
    . ./.env
else
    echo "Error: .env file not found. Please run ./01-setup-environment.sh first."
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Configuring IAM permissions for Cloud Build...${NC}"

# Get project number
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
CLOUD_BUILD_SA="$PROJECT_NUMBER@cloudbuild.gserviceaccount.com"

echo "Cloud Build Service Account: $CLOUD_BUILD_SA"

# Grant Cloud Run Admin role
echo -e "${YELLOW}Granting Cloud Run Admin role...${NC}"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$CLOUD_BUILD_SA" \
    --role="roles/run.admin"

# Grant Service Account User role
echo -e "${YELLOW}Granting Service Account User role...${NC}"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$CLOUD_BUILD_SA" \
    --role="roles/iam.serviceAccountUser"

# Grant Artifact Registry Writer role
echo -e "${YELLOW}Granting Artifact Registry Writer role...${NC}"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$CLOUD_BUILD_SA" \
    --role="roles/artifactregistry.writer"

# Grant Source Repository Reader role
echo -e "${YELLOW}Granting Source Repository Reader role...${NC}"
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$CLOUD_BUILD_SA" \
    --role="roles/source.reader"

echo -e "${GREEN}✓ IAM permissions configured successfully${NC}"
echo -e "${YELLOW}Next: Run ./05-setup-source-repo.sh${NC}"
