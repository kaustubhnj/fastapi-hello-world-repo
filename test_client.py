#!/usr/bin/env python3
"""
Client to test the authenticated Cloud Run service.
"""

import subprocess
import requests
import json
import sys

def get_identity_token(audience):
    """Get Google Cloud identity token for specific audience using gcloud."""
    try:
        result = subprocess.run(
            ['gcloud', 'auth', 'print-identity-token', f'--audiences={audience}'],
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error getting identity token: {e}")
        return None

def test_service(url, token):
    """Make authenticated request to the Cloud Run service."""
    headers = {
        'Authorization': f'Bearer {token}',
        'Content-Type': 'application/json'
    }
    
    try:
        # Test the root endpoint
        print(f"Testing: {url}")
        response = requests.get(url, headers=headers)
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}")
        print()
        
        # Test the health endpoint
        health_url = f"{url}/health"
        print(f"Testing: {health_url}")
        response = requests.get(health_url, headers=headers)
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}")
        print()
        
        # Test the version endpoint
        version_url = f"{url}/version"
        print(f"Testing: {version_url}")
        response = requests.get(version_url, headers=headers)
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}")
        
    except requests.exceptions.RequestException as e:
        print(f"Request error: {e}")
    except json.JSONDecodeError:
        print(f"Response: {response.text}")

def main():
    # Cloud Run service URL (the actual URL from service describe)
    service_url = "https://fastapi-hello-world-crpxn6ivgq-uw.a.run.app"
    
    print("Getting identity token...")
    token = get_identity_token(service_url)
    
    if not token:
        print("Failed to get identity token")
        sys.exit(1)
    
    print("Testing Cloud Run service...")
    test_service(service_url, token)

if __name__ == "__main__":
    main()