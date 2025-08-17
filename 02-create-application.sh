#!/bin/bash
# 02-create-application.sh
# Create the FastAPI application files

set -e

echo "=== GCP CI/CD Pipeline Setup - Step 2: Create Application ==="

# Load environment variables or create them if .env doesn't exist
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
echo "Loading environment variables from .env..."
source .env

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
