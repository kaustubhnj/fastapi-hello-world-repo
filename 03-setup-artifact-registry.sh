#!/bin/bash
# 03-setup-artifact-registry.sh
# Set up Artifact Registry

set -e

echo "=== GCP CI/CD Pipeline Setup - Step 3: Setup Artifact Registry ==="

# Load environment variables, creating a default .env file if it's missing.
if [ ! -f ".env" ]; then
    echo "Warning: .env file not found. It should be created by 01-setup-environment.sh."
    echo "Creating a default .env file to proceed..."

    # Get or set project ID
    export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    if [ -z "$PROJECT_ID" ]; then
        echo "No project set. Please enter your GCP Project ID:"
        read -p "Project ID: " PROJECT_ID
        gcloud config set project $PROJECT_ID
    fi

    # Set default environment variables
    export REPOSITORY_NAME="fastapi-repo"
    export LOCATION="us-central1"
    export REPO_NAME="fastapi-hello-world-repo"
    export SERVICE_NAME="fastapi-hello-world"

    # Save environment variables to file for other scripts
    cat > .env << EOV
export PROJECT_ID="$PROJECT_ID"
export REPOSITORY_NAME="$REPOSITORY_NAME"
export LOCATION="$LOCATION"
export REPO_NAME="$REPO_NAME"
export SERVICE_NAME="$SERVICE_NAME"
EOV

    echo "Environment variables saved to .env file"
fi

# Source the environment variables to make them available to this script
source .env

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Creating Artifact Registry repository...${NC}"

# Create Artifact Registry repository
gcloud artifacts repositories create $REPOSITORY_NAME \
    --repository-format=docker \
    --location=$LOCATION \
    --description="FastAPI application repository"

echo -e "${GREEN}✓ Artifact Registry repository created${NC}"

echo -e "${YELLOW}Configuring Docker authentication...${NC}"

# Configure Docker authentication
gcloud auth configure-docker $LOCATION-docker.pkg.dev

echo -e "${GREEN}✓ Docker authentication configured${NC}"

# Test authentication (optional)
echo -e "${YELLOW}Testing Docker authentication...${NC}"
if docker pull hello-world > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Docker is working correctly${NC}"
else
    echo -e "${YELLOW}Warning: Docker test failed, but continuing...${NC}"
fi

echo -e "${GREEN}✓ Artifact Registry setup completed${NC}"
echo -e "${YELLOW}Next: Run ./04-setup-permissions.sh${NC}"
