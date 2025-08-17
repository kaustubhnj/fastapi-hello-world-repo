#!/bin/bash
# 09-cleanup.sh
# Clean up all resources (optional)

echo "=== GCP CI/CD Pipeline Setup - Step 9: Cleanup Resources ==="

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

echo -e "${RED}WARNING: This will delete all GCP resources created by this setup!${NC}"
echo "Resources to be deleted:"
echo "  - Cloud Run service: $SERVICE_NAME"
echo "  - Cloud Build triggers: fastapi-main-trigger, fastapi-pr-trigger"
echo "  - Artifact Registry repository: $REPOSITORY_NAME"
echo ""
echo -e "${YELLOW}Note: This will NOT delete your GitHub repository.${NC}"
echo "If you want to delete the GitHub repository, do it manually at:"
echo "https://github.com/settings/repositories"
echo ""
read -p "Are you sure you want to proceed? (yes/no): " confirmation

if [ "$confirmation" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo -e "${YELLOW}Starting cleanup process...${NC}"

# Delete Cloud Run service
echo -e "${YELLOW}Deleting Cloud Run service...${NC}"
gcloud run services delete $SERVICE_NAME --region=$LOCATION --quiet || echo "Service deletion failed or service doesn't exist"

# Delete Cloud Build triggers
echo -e "${YELLOW}Deleting Cloud Build triggers...${NC}"
gcloud builds triggers delete fastapi-main-trigger --quiet || echo "Main trigger deletion failed or trigger doesn't exist"
gcloud builds triggers delete fastapi-pr-trigger --quiet || echo "PR trigger deletion failed or trigger doesn't exist"

# Delete Artifact Registry repository
echo -e "${YELLOW}Deleting Artifact Registry repository...${NC}"
gcloud artifacts repositories delete $REPOSITORY_NAME --location=$LOCATION --quiet || echo "Repository deletion failed or repository doesn't exist"

echo -e "${GREEN}✓ GCP resources cleanup completed!${NC}"
echo -e "${YELLOW}Note: Local files and GitHub repository are preserved.${NC}"
echo ""
echo "If you want to delete the GitHub repository manually:"
if [ -n "$GITHUB_URL" ]; then
    GITHUB_OWNER=$(echo $GITHUB_URL | sed 's/.*github\.com[\/:]//; s/\/.*//; s/\.git$//')
    GITHUB_REPO=$(echo $GITHUB_URL | sed 's/.*\///; s/\.git$//')
    echo "  Repository: https://github.com/$GITHUB_OWNER/$GITHUB_REPO"
    echo "  Settings: https://github.com/$GITHUB_OWNER/$GITHUB_REPO/settings"
fi
