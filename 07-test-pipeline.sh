#!/bin/bash
# 07-test-pipeline.sh
# Test the CI/CD pipeline

set -e

echo "=== GCP CI/CD Pipeline Setup - Step 7: Test Pipeline ==="

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

echo -e "${YELLOW}Making a change to trigger the pipeline...${NC}"

# Update the version in main.py
sed -i.bak 's/"version": "1.0.0"/"version": "1.0.1"/' main.py

echo -e "${YELLOW}Committing and pushing changes to GitHub...${NC}"

# Commit and push the change
git add main.py
git commit -m "Update version to 1.0.1 - testing CI/CD pipeline"
git push origin main

echo -e "${GREEN}✓ Changes pushed to GitHub to trigger pipeline${NC}"

echo -e "${YELLOW}Waiting for build to start...${NC}"
sleep 10

echo -e "${YELLOW}Checking recent builds...${NC}"

# List recent builds
gcloud builds list --limit=3

echo -e "${YELLOW}Getting the latest build status...${NC}"

# Get the latest build ID
LATEST_BUILD_ID=$(gcloud builds list --limit=1 --format="value(id)")

if [ -n "$LATEST_BUILD_ID" ]; then
    echo "Latest Build ID: $LATEST_BUILD_ID"
    echo -e "${YELLOW}You can monitor the build with:${NC}"
    echo "gcloud builds log $LATEST_BUILD_ID --stream"
    echo ""
    echo -e "${YELLOW}Or view in Cloud Console:${NC}"
    echo "https://console.cloud.google.com/cloud-build/builds/$LATEST_BUILD_ID?project=$PROJECT_ID"
    
    echo -e "${YELLOW}Waiting for build to complete (this may take several minutes)...${NC}"
    
    # Wait for build to complete (simplified check)
    for i in {1..20}; do
        BUILD_STATUS=$(gcloud builds describe $LATEST_BUILD_ID --format="value(status)" 2>/dev/null || echo "UNKNOWN")
        echo "Build status: $BUILD_STATUS"
        
        if [ "$BUILD_STATUS" = "SUCCESS" ]; then
            echo -e "${GREEN}✓ Build completed successfully!${NC}"
            break
        elif [ "$BUILD_STATUS" = "FAILURE" ] || [ "$BUILD_STATUS" = "CANCELLED" ] || [ "$BUILD_STATUS" = "TIMEOUT" ]; then
            echo -e "${RED}✗ Build failed with status: $BUILD_STATUS${NC}"
            echo "Check build logs with: gcloud builds log $LATEST_BUILD_ID"
            echo "Or view in console: https://console.cloud.google.com/cloud-build/builds/$LATEST_BUILD_ID?project=$PROJECT_ID"
            break
        else
            echo "Build in progress... (attempt $i/20)"
            sleep 30
        fi
    done
else
    echo -e "${RED}No builds found. The trigger may not have activated.${NC}"
    echo "Possible reasons:"
    echo "1. GitHub repository not properly connected to Cloud Build"
    echo "2. Build trigger not created correctly"
    echo "3. Build is still starting (check in a few minutes)"
    echo ""
    echo "You can manually trigger a build with:"
    echo "gcloud builds submit --config cloudbuild.yaml ."
    echo ""
    echo "Or check Cloud Build console:"
    echo "https://console.cloud.google.com/cloud-build/triggers?project=$PROJECT_ID"
fi

echo -e "${YELLOW}Next: Run ./08-test-application.sh${NC}"
