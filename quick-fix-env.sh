#!/bin/bash
# quick-fix-env.sh
# Creates the .env file if it's missing

echo "=== Quick Fix: Creating .env file ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if .env already exists
if [ -f ".env" ]; then
    echo -e "${GREEN}.env file already exists!${NC}"
    cat .env
    exit 0
fi

echo -e "${YELLOW}Creating .env file with default values...${NC}"

# Get or set project ID
export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
    echo -e "${YELLOW}No project set. Please enter your GCP Project ID:${NC}"
    read -p "Project ID: " PROJECT_ID
    gcloud config set project $PROJECT_ID
fi

# Set default environment variables
export REPOSITORY_NAME="fastapi-repo"
export LOCATION="us-central1"
export REPO_NAME="fastapi-hello-world-repo"
export SERVICE_NAME="fastapi-hello-world"

# Save environment variables to file
cat > .env << EOF
export PROJECT_ID="$PROJECT_ID"
export REPOSITORY_NAME="$REPOSITORY_NAME"
export LOCATION="$LOCATION"
export REPO_NAME="$REPO_NAME"
export SERVICE_NAME="$SERVICE_NAME"
EOF

echo -e "${GREEN}✓ .env file created successfully!${NC}"
echo -e "${YELLOW}Contents:${NC}"
cat .env

echo ""
echo -e "${GREEN}You can now run any of the setup scripts.${NC}"
echo -e "${YELLOW}Recommended: Start with ./01-setup-environment.sh${NC}"