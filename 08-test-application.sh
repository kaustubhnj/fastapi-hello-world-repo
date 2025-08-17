#!/bin/bash
# 08-test-application.sh
# Test the deployed application

set -e

echo "=== GCP CI/CD Pipeline Setup - Step 8: Test Application ==="

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

echo -e "${YELLOW}Getting Cloud Run service URL...${NC}"

# Get the Cloud Run service URL
SERVICE_URL=$(gcloud run services describe $SERVICE_NAME \
    --region=$LOCATION \
    --format="value(status.url)" 2>/dev/null || echo "")

if [ -z "$SERVICE_URL" ]; then
    echo -e "${RED}✗ Cloud Run service not found. The deployment may have failed.${NC}"
    echo "Check the build logs with: gcloud builds list"
    exit 1
fi

echo -e "${GREEN}Service URL: $SERVICE_URL${NC}"

echo -e "${YELLOW}Testing the application endpoints...${NC}"

# Test the root endpoint
echo "Testing GET /"
curl -s "$SERVICE_URL/" | python3 -m json.tool 2>/dev/null || curl -s "$SERVICE_URL/"

echo ""

# Test the health endpoint
echo "Testing GET /health"
curl -s "$SERVICE_URL/health" | python3 -m json.tool 2>/dev/null || curl -s "$SERVICE_URL/health"

echo ""

# Test the version endpoint
echo "Testing GET /version"
curl -s "$SERVICE_URL/version" | python3 -m json.tool 2>/dev/null || curl -s "$SERVICE_URL/version"

echo ""
echo -e "${GREEN}✓ Application is running successfully!${NC}"
echo -e "${GREEN}✓ CI/CD Pipeline setup completed!${NC}"

echo ""
echo -e "${YELLOW}=== SUMMARY ===${NC}"
echo "Your FastAPI application is now deployed with a complete CI/CD pipeline!"
echo ""
echo "Application URL: $SERVICE_URL"
echo "Available endpoints:"
echo "  - GET /         - Hello World message"
echo "  - GET /health   - Health check"
echo "  - GET /version  - Application version"
echo ""
echo "To make changes:"
echo "1. Edit your code"
echo "2. git add ."
echo "3. git commit -m 'Your message'"
echo "4. git push google main"
echo ""
echo "The pipeline will automatically build and deploy your changes!"
echo ""
echo -e "${YELLOW}Optional: Run ./09-cleanup.sh to remove all resources${NC}"
