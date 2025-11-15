# PowerShell script to build and run ExamEye Shield Docker container
# Make sure you have your Supabase keys ready!

Write-Host "🐳 Building and Running ExamEye Shield Docker Container..." -ForegroundColor Cyan

# Check if .env file exists
if (Test-Path .env) {
    Write-Host "✅ Found .env file, loading environment variables..." -ForegroundColor Green
    Get-Content .env | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($key, $value, "Process")
        }
    }
} else {
    Write-Host "⚠️  No .env file found. Using environment variables from system or defaults." -ForegroundColor Yellow
    Write-Host "   Make sure to set: SUPABASE_KEY, VITE_SUPABASE_PUBLISHABLE_KEY" -ForegroundColor Yellow
}

# Get environment variables (with defaults)
$SUPABASE_URL = $env:SUPABASE_URL
if (-not $SUPABASE_URL) { $SUPABASE_URL = "https://ukwnvvuqmiqrjlghgxnf.supabase.co" }

$SUPABASE_KEY = $env:SUPABASE_KEY
if (-not $SUPABASE_KEY) { 
    Write-Host "❌ SUPABASE_KEY is not set! Please set it in .env file or as environment variable." -ForegroundColor Red
    exit 1
}

$VITE_SUPABASE_URL = $env:VITE_SUPABASE_URL
if (-not $VITE_SUPABASE_URL) { $VITE_SUPABASE_URL = "https://ukwnvvuqmiqrjlghgxnf.supabase.co" }

$VITE_SUPABASE_PUBLISHABLE_KEY = $env:VITE_SUPABASE_PUBLISHABLE_KEY
if (-not $VITE_SUPABASE_PUBLISHABLE_KEY) { 
    Write-Host "❌ VITE_SUPABASE_PUBLISHABLE_KEY is not set! Please set it in .env file or as environment variable." -ForegroundColor Red
    exit 1
}

$VITE_PROCTORING_API_URL = $env:VITE_PROCTORING_API_URL
if (-not $VITE_PROCTORING_API_URL) { $VITE_PROCTORING_API_URL = "http://localhost:8001" }

$VITE_PROCTORING_WS_URL = $env:VITE_PROCTORING_WS_URL
if (-not $VITE_PROCTORING_WS_URL) { $VITE_PROCTORING_WS_URL = "ws://localhost:8001" }

Write-Host "`n📦 Building Docker image..." -ForegroundColor Cyan
docker build `
    --build-arg VITE_SUPABASE_URL="$VITE_SUPABASE_URL" `
    --build-arg VITE_SUPABASE_PUBLISHABLE_KEY="$VITE_SUPABASE_PUBLISHABLE_KEY" `
    --build-arg VITE_PROCTORING_API_URL="$VITE_PROCTORING_API_URL" `
    --build-arg VITE_PROCTORING_WS_URL="$VITE_PROCTORING_WS_URL" `
    -t exameye-shield:latest `
    .

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Docker build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "`n🚀 Starting container..." -ForegroundColor Cyan

# Stop and remove existing container if it exists
docker stop exameye-shield 2>$null
docker rm exameye-shield 2>$null

# Run the container
docker run -d `
    --name exameye-shield `
    -p 80:80 `
    -e SUPABASE_URL="$SUPABASE_URL" `
    -e SUPABASE_KEY="$SUPABASE_KEY" `
    -e PORT=8001 `
    exameye-shield:latest

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Container started successfully!" -ForegroundColor Green
    Write-Host "`n🌐 Access your application at: http://localhost" -ForegroundColor Cyan
    Write-Host "📊 Backend health check: http://localhost/api/health" -ForegroundColor Cyan
    Write-Host "`n📋 View logs: docker logs -f exameye-shield" -ForegroundColor Yellow
    Write-Host "🛑 Stop container: docker stop exameye-shield" -ForegroundColor Yellow
} else {
    Write-Host "❌ Failed to start container!" -ForegroundColor Red
    exit 1
}

