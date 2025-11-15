# PowerShell script to push ExamEye Shield Docker image to Docker Hub

param(
    [Parameter(Mandatory=$true)]
    [string]$DockerHubUsername
)

Write-Host "🐳 Pushing ExamEye Shield to Docker Hub..." -ForegroundColor Cyan

# Check if user is logged in
Write-Host "`n📝 Checking Docker Hub login..." -ForegroundColor Yellow
$loginCheck = docker info 2>&1 | Select-String "Username"
if (-not $loginCheck) {
    Write-Host "⚠️  Not logged in to Docker Hub. Please login first:" -ForegroundColor Yellow
    Write-Host "   docker login" -ForegroundColor Cyan
    Write-Host "`nOr we can login now..." -ForegroundColor Yellow
    docker login
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Docker login failed!" -ForegroundColor Red
        exit 1
    }
}

# Tag the image
$sourceImage = "exameye-shield---enhanced-edition-main-exameye-shield:latest"
$targetImage = "$DockerHubUsername/exameye-shield:latest"

Write-Host "`n🏷️  Tagging image..." -ForegroundColor Cyan
Write-Host "   Source: $sourceImage" -ForegroundColor Gray
Write-Host "   Target: $targetImage" -ForegroundColor Gray

docker tag $sourceImage $targetImage

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to tag image!" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Image tagged successfully!" -ForegroundColor Green

# Push the image
Write-Host "`n📤 Pushing image to Docker Hub..." -ForegroundColor Cyan
Write-Host "   This may take several minutes depending on your internet speed..." -ForegroundColor Yellow

docker push $targetImage

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Image pushed successfully to Docker Hub!" -ForegroundColor Green
    Write-Host "`n🌐 Your image is now available at:" -ForegroundColor Cyan
    Write-Host "   https://hub.docker.com/r/$DockerHubUsername/exameye-shield" -ForegroundColor Cyan
    Write-Host "`n📋 To pull and run the image:" -ForegroundColor Yellow
    Write-Host "   docker pull $targetImage" -ForegroundColor Gray
    Write-Host "   docker run -d -p 80:80 -e SUPABASE_URL=... -e SUPABASE_KEY=... $targetImage" -ForegroundColor Gray
} else {
    Write-Host "`n❌ Failed to push image to Docker Hub!" -ForegroundColor Red
    exit 1
}

