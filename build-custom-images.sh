#!/bin/bash
# Build Custom Dify Images with RBAC modifications

set -e

echo "=== Building Custom Dify RBAC Images ==="

# Set variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIFY_ROOT="$(dirname "$SCRIPT_DIR")/dify"
RBAC_ROOT="$SCRIPT_DIR"

# Check if Dify directory exists
if [ ! -d "$DIFY_ROOT" ]; then
    echo "Error: Dify directory not found at $DIFY_ROOT"
    exit 1
fi

echo "Dify Root: $DIFY_ROOT"
echo "RBAC Root: $RBAC_ROOT"

# Build API image
echo "Building custom API image..."
cd "$DIFY_ROOT"
docker build -f "$RBAC_ROOT/Dockerfile.api" -t dify-api-custom-rbac:latest .

# Build Web image
echo "Building custom Web image..."
docker build -f "$RBAC_ROOT/Dockerfile.web" -t dify-web-custom-rbac:latest .

echo "=== Build completed successfully ==="
echo ""
echo "Custom images created:"
echo "  - dify-api-custom-rbac:latest"
echo "  - dify-web-custom-rbac:latest"
echo ""
echo "To use these images, copy docker-compose.override.yml to your Dify directory:"
echo "  cp $RBAC_ROOT/docker-compose.override.yml $DIFY_ROOT/"
echo ""
echo "Then run: docker-compose up -d"