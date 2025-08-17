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
