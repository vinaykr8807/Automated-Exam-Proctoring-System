@echo off
REM Docker Build Script for ExamEye Shield (Windows)
REM This script builds the Docker image with all environment variables

echo 🐳 Building ExamEye Shield Docker Image...

REM Load environment variables from .env file if it exists
if exist .env (
    echo 📝 Loading environment variables from .env file...
    for /f "tokens=1,2 delims==" %%a in (.env) do (
        if not "%%a"=="" if not "%%a"=="#" (
            set "%%a=%%b"
        )
    )
)

REM Default values (can be overridden by .env file)
if "%VITE_SUPABASE_URL%"=="" set VITE_SUPABASE_URL=https://ukwnvvuqmiqrjlghgxnf.supabase.co
if "%VITE_SUPABASE_PUBLISHABLE_KEY%"=="" (
    echo ⚠️  Warning: VITE_SUPABASE_PUBLISHABLE_KEY is not set
    echo    Set it in .env file or as environment variable
)

if "%VITE_PROCTORING_API_URL%"=="" set VITE_PROCTORING_API_URL=http://localhost:8001
if "%VITE_PROCTORING_WS_URL%"=="" set VITE_PROCTORING_WS_URL=ws://localhost:8001

REM Build the Docker image
docker build ^
    --build-arg VITE_SUPABASE_URL=%VITE_SUPABASE_URL% ^
    --build-arg VITE_SUPABASE_PUBLISHABLE_KEY=%VITE_SUPABASE_PUBLISHABLE_KEY% ^
    --build-arg VITE_PROCTORING_API_URL=%VITE_PROCTORING_API_URL% ^
    --build-arg VITE_PROCTORING_WS_URL=%VITE_PROCTORING_WS_URL% ^
    -t exameye-shield:latest ^
    .

if %ERRORLEVEL% EQU 0 (
    echo ✅ Docker image built successfully!
    echo.
    echo To run the container:
    echo   docker run -d -p 80:80 --name exameye-shield -e SUPABASE_URL=your-url -e SUPABASE_KEY=your-key exameye-shield:latest
    echo.
    echo Or use docker-compose:
    echo   docker-compose up -d
) else (
    echo ❌ Build failed!
    exit /b 1
)

