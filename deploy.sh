#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "📦 Packaging Python Lambda Layer dependencies..."
echo "=========================================="
cd lambda/layer

# Clean up previous builds to avoid stale artifacts
rm -rf python/
mkdir -p python/

# Handle systems where pip is aliased as pip3 or python3 -m pip
if command -v pip3 &> /dev/null; then
    PIP_CMD="pip3"
elif command -v pip &> /dev/null; then
    PIP_CMD="pip"
elif command -v python3 &> /dev/null; then
    PIP_CMD="python3 -m pip"
elif command -v python &> /dev/null; then
    PIP_CMD="python -m pip"
else
    echo "❌ Error: pip or python could not be found. Please ensure Python and pip are installed."
    exit 1
fi

echo "Using pip command: $PIP_CMD"

# Install dependencies into the target 'python' directory
# AWS Lambda extracts layers to /opt, and /opt/python is automatically added to the PYTHONPATH
$PIP_CMD install -r requirements.txt --target python/

cd ../../

echo "=========================================="
echo "🚀 Initializing and Applying Terraform..."
echo "=========================================="
cd terraform

# Run Terraform commands
terraform init
terraform apply
