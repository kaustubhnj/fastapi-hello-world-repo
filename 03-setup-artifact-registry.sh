#!/bin/bash
# 03-setup-artifact-registry.sh
# Set up Artifact Registry

set -e

echo "=== GCP CI/CD Pipeline Setup - Step 3: Setup Artifact Registry ==="

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
