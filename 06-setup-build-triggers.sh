#!/bin/bash
# 06-setup-build-triggers.sh
# Create Cloud Build triggers for GitHub

set -e

echo "=== GCP CI/CD Pipeline Setup - Step 6: Setup Build Triggers ==="

# Load environment variables or create them if .env doesn't exist
if [ -f ".env" ]; then
    source .env
else
    echo "Error: .env file not found. Please run ./01-setup-environment.sh first."
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Extract GitHub repository info
if [ -z "$GITHUB_URL" ]; then
    echo -e "${RED}Error: GITHUB_URL not found in .env file.${NC}"
    echo "Please run ./05-setup-source-repo.sh first."
    exit 1
fi

# Extract owner and repo name from GitHub URL
GITHUB_OWNER=$(echo $GITHUB_URL | sed 's/.*github\.com[\/:]//; s/\/.*//; s/\.git$//')
GITHUB_REPO=$(echo $GITHUB_URL | sed 's/.*\///; s/\.git$//')

echo "GitHub Owner: $GITHUB_OWNER"
echo "GitHub Repository: $GITHUB_REPO"

echo -e "${YELLOW}Setting up GitHub connection in Cloud Build...${NC}"
echo -e "${YELLOW}Note: You may need to connect your GitHub account to Cloud Build manually.${NC}"
echo ""
echo "To connect GitHub to Cloud Build:"
echo "1. Go to: https://console.cloud.google.com/cloud-build/triggers"
echo "2. Click 'Connect Repository'"
echo "3. Select 'GitHub (Cloud Build GitHub App)'"
echo "4. Follow the authentication flow"
echo "5. Select your repository: $GITHUB_OWNER/$GITHUB_REPO"
echo ""
read -p "Have you connected your GitHub repository to Cloud Build? (yes/no): " github_connected

if [ "$github_connected" != "yes" ]; then
    echo -e "${YELLOW}Please connect your GitHub repository first, then run this script again.${NC}"
    exit 1
fi

echo -e "${YELLOW}Creating Cloud Build trigger for main branch...${NC}"

# Create trigger for main branch pushes
gcloud builds triggers create github \
    --repo-name="$GITHUB_REPO" \
    --repo-owner="$GITHUB_OWNER" \
    --branch-pattern="^main$" \
    --build-config="cloudbuild.yaml" \
    --name="fastapi-main-trigger" \
    --description="Trigger for main branch deployments" \
    --substitutions="_LOCATION=$LOCATION,_REPOSITORY=$REPOSITORY_NAME,_SERVICE_NAME=$SERVICE_NAME"

echo -e "${GREEN}✓ Main branch trigger created${NC}"

echo -e "${YELLOW}Creating Cloud Build trigger for pull requests...${NC}"

# Create trigger for pull requests
gcloud builds triggers create github \
    --repo-name="$GITHUB_REPO" \
    --repo-owner="$GITHUB_OWNER" \
    --pull-request-pattern="^main$" \
    --build-config="cloudbuild.yaml" \
    --name="fastapi-pr-trigger" \
    --description="Trigger for pull request validation" \
    --comment-control="COMMENTS_ENABLED" \
    --substitutions="_LOCATION=$LOCATION,_REPOSITORY=$REPOSITORY_NAME,_SERVICE_NAME=$SERVICE_NAME" || echo -e "${YELLOW}PR trigger creation failed (this is optional)${NC}"

echo -e "${GREEN}✓ Build triggers created successfully${NC}"

echo -e "${YELLOW}Triggers created:${NC}"
echo "  - fastapi-main-trigger: Deploys when code is pushed to main branch"
echo "  - fastapi-pr-trigger: Tests pull requests to main branch"
echo ""
echo "You can view your triggers at:"
echo "https://console.cloud.google.com/cloud-build/triggers?project=$PROJECT_ID"

echo -e "${YELLOW}Next: Run ./07-test-pipeline.sh${NC}"
