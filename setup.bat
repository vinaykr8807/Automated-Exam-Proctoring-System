@echo off
echo ========================================
echo ExamEye Shield - Setup Script
echo ========================================
echo.

echo [1/6] Setting up Backend...
cd backend
if not exist venv (
    echo Creating Python virtual environment...
    python -m venv venv
)

echo Activating virtual environment...
call venv\Scripts\activate

echo Installing Python dependencies...
pip install -r requirements.txt

echo Downloading AI models...
python download_model.py

echo.
echo [2/6] Setting up Frontend...
cd ..\frontend

echo Installing Node.js dependencies...
npm install

echo.
echo [3/6] Creating environment files...
cd ..

if not exist backend\.env (
    echo Creating backend/.env file...
    echo MONGO_URL=mongodb://localhost:27017/exam_proctoring > backend\.env
    echo DB_NAME=exam_proctoring >> backend\.env
    echo ADMIN_PASSWORD=vinay >> backend\.env
    echo SUPABASE_URL=https://ukwnvvuqmiqrjlghgxnf.supabase.co >> backend\.env
    echo SUPABASE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVrd252dnVxbWlxcmpsZ2hneG5mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ1NTU3NzUsImV4cCI6MjA2MDEzMTc3NX0.3VHYXmGdUAU0IW8vGZlvklvOY1kqXAOpBCxwSzL33TM >> backend\.env
)

if not exist frontend\.env (
    echo Creating frontend/.env file...
    echo VITE_REACT_APP_BACKEND_URL=http://localhost:8001 > frontend\.env
)

echo.
echo [4/6] Setup complete!
echo.
echo ========================================
echo Next Steps:
echo ========================================
echo 1. Start MongoDB (if using local installation)
echo 2. Run: start_backend.bat
echo 3. Run: start_frontend.bat
echo 4. Open: http://localhost:3000
echo ========================================
echo.
pause