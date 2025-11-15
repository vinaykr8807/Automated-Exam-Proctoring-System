#!/bin/bash

# Docker Build Script for ExamEye Shield
# This script builds the Docker image with all environment variables

set -e

echo "🐳 Building ExamEye Shield Docker Image..."

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    echo "📝 Loading environment variables from .env file..."
    export $(cat .env | grep -v '^#' | xargs)
fi

# Default values (can be overridden by .env file)
VITE_SUPABASE_URL=${VITE_SUPABASE_URL:-"https://ukwnvvuqmiqrjlghgxnf.supabase.co"}
VITE_SUPABASE_PUBLISHABLE_KEY=${VITE_SUPABASE_PUBLISHABLE_KEY:-""}
VITE_PROCTORING_API_URL=${VITE_PROCTORING_API_URL:-"http://localhost:8001"}
VITE_PROCTORING_WS_URL=${VITE_PROCTORING_WS_URL:-"ws://localhost:8001"}

# Check if required variables are set
if [ -z "$VITE_SUPABASE_PUBLISHABLE_KEY" ]; then
    echo "⚠️  Warning: VITE_SUPABASE_PUBLISHABLE_KEY is not set"
    echo "   Set it in .env file or as environment variable"
fi

# Build the Docker image
docker build \
    --build-arg VITE_SUPABASE_URL="$VITE_SUPABASE_URL" \
    --build-arg VITE_SUPABASE_PUBLISHABLE_KEY="$VITE_SUPABASE_PUBLISHABLE_KEY" \
    --build-arg VITE_PROCTORING_API_URL="$VITE_PROCTORING_API_URL" \
    --build-arg VITE_PROCTORING_WS_URL="$VITE_PROCTORING_WS_URL" \
    -t exameye-shield:latest \
    .

echo "✅ Docker image built successfully!"
echo ""
echo "To run the container:"
echo "  docker run -d -p 80:80 --name exameye-shield \\"
echo "    -e SUPABASE_URL=your-supabase-url \\"
echo "    -e SUPABASE_KEY=your-supabase-key \\"
echo "    exameye-shield:latest"
echo ""
echo "Or use docker-compose:"
echo "  docker-compose up -d"

