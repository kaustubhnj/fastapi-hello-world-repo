#!/bin/bash
# 01-setup-environment.sh
# Initial environment setup and API enablement

set -e  # Exit on any error

echo "=== GCP CI/CD Pipeline Setup - Step 1: Environment Setup ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if user is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n 1 > /dev/null; then
    echo -e "${YELLOW}You need to authenticate with gcloud first.${NC}"
    echo "Running: gcloud auth login"
    gcloud auth login
fi

# Get or set project ID
export PROJECT_ID=$(gcloud config get-value project)
if [ -z "$PROJECT_ID" ]; then
    echo -e "${YELLOW}No project set. Please enter your GCP Project ID:${NC}"
    read -p "Project ID: " PROJECT_ID
    gcloud config set project $PROJECT_ID
fi

# Set environment variables
export REPOSITORY_NAME="fastapi-repo"
export LOCATION="us-central1"
export REPO_NAME="fastapi-hello-world-repo"
export SERVICE_NAME="fastapi-hello-world"

# Save environment variables to file for other scripts
cat > .env << EOF
export PROJECT_ID="$PROJECT_ID"
export REPOSITORY_NAME="$REPOSITORY_NAME"
export LOCATION="$LOCATION"
export REPO_NAME="$REPO_NAME"
export SERVICE_NAME="$SERVICE_NAME"
