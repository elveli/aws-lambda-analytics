#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "📦 Packaging Python Lambda Layer dependencies..."
echo "=========================================="
cd lambda/layer

# Clean up previous builds to avoid stale artifacts
rm -rf python/
mkdir -p python/

# Install dependencies into the target 'python' directory
# AWS Lambda extracts layers to /opt, and /opt/python is automatically added to the PYTHONPATH
pip install -r requirements.txt --target python/

cd ../../

echo "=========================================="
echo "🚀 Initializing and Applying Terraform..."
echo "=========================================="
cd terraform

# Run Terraform commands
terraform init
terraform apply
