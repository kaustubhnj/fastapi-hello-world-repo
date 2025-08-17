#!/bin/bash
# make-scripts.sh
# This script creates all individual setup scripts

echo "Creating individual setup scripts..."

# Create 01-setup-environment.sh
cat > 01-setup-environment.sh << 'EOF'
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
EOF

echo -e "${GREEN}Environment variables saved to .env file${NC}"

# Enable required APIs
echo -e "${YELLOW}Enabling required GCP APIs...${NC}"
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com
# gcloud services enable sourcerepo.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable artifactregistry.googleapis.com

echo -e "${GREEN}✓ APIs enabled successfully${NC}"

# Verify billing is enabled
echo -e "${YELLOW}Checking if billing is enabled...${NC}"
BILLING_ENABLED=$(gcloud beta billing projects describe $PROJECT_ID --format="value(billingEnabled)" 2>/dev/null || echo "false")
if [ "$BILLING_ENABLED" != "True" ]; then
    echo -e "${RED}Warning: Billing is not enabled for this project. Some services may not work.${NC}"
    echo "Please enable billing in the GCP Console before proceeding."
    read -p "Press Enter to continue anyway, or Ctrl+C to exit..."
fi

echo -e "${GREEN}✓ Step 1 completed successfully!${NC}"
echo -e "${YELLOW}Next: Run ./02-create-application.sh${NC}"
EOF

# Create 02-create-application.sh
cat > 02-create-application.sh << 'EOF'
#!/bin/bash
# 02-create-application.sh
# Create the FastAPI application files

set -e

echo "=== GCP CI/CD Pipeline Setup - Step 2: Create Application ==="

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

# Create project directory
echo -e "${YELLOW}Creating FastAPI application files...${NC}"

# Create main.py
cat > main.py << 'EOL'
from fastapi import FastAPI
import os

app = FastAPI(title="Hello World API", version="1.0.0")

@app.get("/")
async def root():
    return {"message": "Hello World!"}

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

@app.get("/version")
async def version():
    return {"version": "1.0.0"}

if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
EOL

# Create requirements.txt
cat > requirements.txt << 'EOL'
fastapi==0.104.1
uvicorn[standard]==0.24.0
EOL

# Create Dockerfile
cat > Dockerfile << 'EOL'
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

EXPOSE 8000

CMD ["python", "main.py"]
EOL

# Create cloudbuild.yaml
cat > cloudbuild.yaml << EOL
steps:
  # Build the Docker image
  - name: 'gcr.io/cloud-builders/docker'
    args: [
      'build', 
      '-t', '\${_LOCATION}-docker.pkg.dev/\${PROJECT_ID}/\${_REPOSITORY}/fastapi-app:\${BUILD_ID}',
      '-t', '\${_LOCATION}-docker.pkg.dev/\${PROJECT_ID}/\${_REPOSITORY}/fastapi-app:latest',
      '.'
    ]

  # Push the Docker image to Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args: [
      'push', 
      '\${_LOCATION}-docker.pkg.dev/\${PROJECT_ID}/\${_REPOSITORY}/fastapi-app:\${BUILD_ID}'
    ]

  - name: 'gcr.io/cloud-builders/docker'
    args: [
      'push', 
      '\${_LOCATION}-docker.pkg.dev/\${PROJECT_ID}/\${_REPOSITORY}/fastapi-app:latest'
    ]

  # Deploy to Cloud Run
  - name: 'gcr.io/cloud-builders/gcloud'
    args: [
      'run', 'deploy', '\${_SERVICE_NAME}',
      '--image', '\${_LOCATION}-docker.pkg.dev/\${PROJECT_ID}/\${_REPOSITORY}/fastapi-app:\${BUILD_ID}',
      '--platform', 'managed',
      '--region', '\${_LOCATION}',
      '--allow-unauthenticated',
      '--port', '8000'
    ]

# Substitutions for build variables
substitutions:
  _LOCATION: '$LOCATION'
  _REPOSITORY: '$REPOSITORY_NAME'
  _SERVICE_NAME: '$SERVICE_NAME'

options:
  logging: CLOUD_LOGGING_ONLY
EOL

# Create .gitignore
cat > .gitignore << 'EOL'
__pycache__/
*.pyc
*.pyo
*.pyd
.Python
env/
venv/
.env
.venv
pip-log.txt
pip-delete-this-directory.txt
.tox
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
*.log
.git
.mypy_cache
.pytest_cache
.hypothesis
.DS_Store
EOL

echo -e "${GREEN}✓ Application files created successfully${NC}"
echo -e "${GREEN}Files created:${NC}"
echo "  - main.py (FastAPI application)"
echo "  - requirements.txt (Python dependencies)"
echo "  - Dockerfile (Container configuration)"
echo "  - cloudbuild.yaml (Build configuration)"
echo "  - .gitignore (Git ignore rules)"

echo -e "${YELLOW}Next: Run ./03-setup-artifact-registry.sh${NC}"
EOF

# Create 03-setup-artifact-registry.sh
cat > 03-setup-artifact-registry.sh << 'EOF'
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
EOF

# Create 04-setup-permissions.sh
cat > 04-setup-permissions.sh << 'EOF'
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
EOF

# Create 05-setup-source-repo.sh
cat > 05-setup-source-repo.sh << 'EOF'
#!/bin/bash
# 05-setup-source-repo.sh
# Set up GitHub repository and push code

set -e

echo "=== GCP CI/CD Pipeline Setup - Step 5: Setup GitHub Repository ==="

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

echo -e "${YELLOW}Setting up GitHub repository...${NC}"

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo -e "${RED}GitHub CLI (gh) is not installed.${NC}"
    echo "Please install it from: https://cli.github.com/"
    echo ""
    echo "Alternative: Create a GitHub repository manually and provide the URL."
    read -p "Do you want to proceed manually? (yes/no): " manual_setup
    
    if [ "$manual_setup" = "yes" ]; then
        echo -e "${YELLOW}Manual setup:${NC}"
        echo "1. Go to https://github.com and create a new repository"
        echo "2. Name it: $REPO_NAME"
        echo "3. Make it public or private (your choice)"
        echo "4. Don't initialize with README, .gitignore, or license"
        echo ""
        read -p "Enter your GitHub repository URL (e.g., https://github.com/username/repo.git): " GITHUB_URL
    else
        echo "Please install GitHub CLI and run this script again."
        exit 1
    fi
else
    # Check if user is authenticated with GitHub
    if ! gh auth status > /dev/null 2>&1; then
        echo -e "${YELLOW}You need to authenticate with GitHub first.${NC}"
        echo "Running: gh auth login"
        gh auth login
    fi
    
    # Create GitHub repository
    echo -e "${YELLOW}Creating GitHub repository: $REPO_NAME${NC}"
    
    # Check if repository already exists
    if gh repo view $REPO_NAME > /dev/null 2>&1; then
        echo -e "${YELLOW}Repository $REPO_NAME already exists.${NC}"
        GITHUB_URL=$(gh repo view $REPO_NAME --json url --jq .url).git
    else
        # Create new repository
        gh repo create $REPO_NAME --public --description "FastAPI Hello World with GCP CI/CD"
        GITHUB_URL=$(gh repo view $REPO_NAME --json url --jq .url).git
    fi
fi

echo -e "${GREEN}✓ GitHub repository ready${NC}"
echo "Repository URL: $GITHUB_URL"

# Update .env file with GitHub URL
echo "export GITHUB_URL=\"$GITHUB_URL\"" >> .env

echo -e "${YELLOW}Initializing Git repository...${NC}"

# Initialize git if not already initialized
if [ ! -d ".git" ]; then
    git init
    git branch -M main
fi

# Configure git if not already configured
if [ -z "$(git config --global user.email)" ]; then
    echo -e "${YELLOW}Git user not configured. Please enter your details:${NC}"
    read -p "Enter your email: " git_email
    read -p "Enter your name: " git_name
    git config --global user.email "$git_email"
    git config --global user.name "$git_name"
fi

# Add all files
git add .

# Check if there are any commits
if ! git rev-parse HEAD > /dev/null 2>&1; then
    # First commit
    git commit -m "Initial commit: FastAPI Hello World application"
else
    # Subsequent commit (check if there are changes)
    if git diff --staged --quiet; then
        echo "No changes to commit"
    else
        git commit -m "Update FastAPI application"
    fi
fi

echo -e "${YELLOW}Adding GitHub repository as remote...${NC}"

# Remove existing origin remote if it exists
git remote remove origin 2>/dev/null || true

# Add GitHub repository as remote
git remote add origin $GITHUB_URL

echo -e "${YELLOW}Pushing code to GitHub repository...${NC}"

# Push to GitHub repository
git push -u origin main

echo -e "${GREEN}✓ Code pushed to GitHub repository${NC}"
echo -e "${GREEN}Repository URL: $GITHUB_URL${NC}"
echo -e "${YELLOW}Next: Run ./06-setup-build-triggers.sh${NC}"
EOF

# Create 06-setup-build-triggers.sh
cat > 06-setup-build-triggers.sh << 'EOF'
#!/bin/bash
# 06-setup-build-triggers.sh
# Create Cloud Build triggers for GitHub

set -e

echo "=== GCP CI/CD Pipeline Setup - Step 6: Setup Build Triggers ==="

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
    --description="Trigger for main branch deployments"

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
    --comment-control="COMMENTS_ENABLED" || echo -e "${YELLOW}PR trigger creation failed (this is optional)${NC}"

echo -e "${GREEN}✓ Build triggers created successfully${NC}"

echo -e "${YELLOW}Triggers created:${NC}"
echo "  - fastapi-main-trigger: Deploys when code is pushed to main branch"
echo "  - fastapi-pr-trigger: Tests pull requests to main branch"
echo ""
echo "You can view your triggers at:"
echo "https://console.cloud.google.com/cloud-build/triggers?project=$PROJECT_ID"

echo -e "${YELLOW}Next: Run ./07-test-pipeline.sh${NC}"
EOF

# Create 07-test-pipeline.sh
cat > 07-test-pipeline.sh << 'EOF'
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
EOF

# Create 08-test-application.sh
cat > 08-test-application.sh << 'EOF'
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
EOF

# Create 09-cleanup.sh
cat > 09-cleanup.sh << 'EOF'
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
EOF

# Create run-all.sh
cat > run-all.sh << 'EOF'
#!/bin/bash
# run-all.sh
# Master script to run all setup scripts in sequence

echo "=== GCP CI/CD Pipeline Setup - Master Script ==="
echo "This script will run all setup scripts in sequence."
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

scripts=(
    "01-setup-environment.sh"
    "02-create-application.sh"
    "03-setup-artifact-registry.sh"
    "04-setup-permissions.sh"
    "05-setup-source-repo.sh"
    "06-setup-build-triggers.sh"
    "07-test-pipeline.sh"
    "08-test-application.sh"
)

echo "Scripts to run:"
for script in "${scripts[@]}"; do
    echo "  - $script"
done
echo ""

read -p "Do you want to run all scripts automatically? (yes/no): " AUTO_RUN

for script in "${scripts[@]}"; do
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}Running: $script${NC}"
    echo -e "${YELLOW}========================================${NC}"
    
    if [ "$AUTO_RUN" != "yes" ]; then
        read -p "Press Enter to run $script, or Ctrl+C to exit..."
    fi
    
    if [ -f "$script" ]; then
        bash "$script"
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ $script completed successfully${NC}"
        else
            echo -e "${RED}✗ $script failed${NC}"
            echo "Would you like to continue with the next script? (yes/no)"
            read -p "> " continue_choice
            if [ "$continue_choice" != "yes" ]; then
                echo "Setup stopped at $script"
                exit 1
            fi
        fi
    else
        echo -e "${RED}Script $script not found!${NC}"
        exit 1
    fi
done

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}All scripts completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Your FastAPI CI/CD pipeline is now fully set up!"
echo "Check the output of the last script for your application URL."
EOF

# Make all scripts executable
chmod +x *.sh

echo "✓ All scripts created successfully!"
echo ""
echo "Individual scripts created:"
echo "  01-setup-environment.sh      - Setup GCP environment and APIs"
echo "  02-create-application.sh     - Create FastAPI application files"
echo "  03-setup-artifact-registry.sh - Setup Artifact Registry"
echo "  04-setup-permissions.sh      - Configure IAM permissions"
echo "  05-setup-source-repo.sh      - Setup Cloud Source Repository"
echo "  06-setup-build-triggers.sh   - Create Cloud Build triggers"
echo "  07-test-pipeline.sh          - Test the CI/CD pipeline"
echo "  08-test-application.sh       - Test the deployed application"
echo "  09-cleanup.sh                - Clean up all resources (optional)"
echo "  run-all.sh                   - Run all scripts in sequence"
echo ""
echo "Usage:"
echo "  Run individually: ./01-setup-environment.sh"
echo "  Run all at once:  ./run-all.sh"
EOF

# Make the script executable
chmod +x make-scripts.sh

echo "Created make-scripts.sh - run this to generate all individual scripts"