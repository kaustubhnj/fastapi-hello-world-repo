#!/bin/bash
# 05-setup-source-repo.sh
# Set up GitHub repository and push code

set -e

echo "=== GCP CI/CD Pipeline Setup - Step 5: Setup GitHub Repository ==="

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
