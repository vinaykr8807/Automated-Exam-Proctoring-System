# ExamEye Shield - AI-Powered Exam Proctoring System

## 🚀 Local Setup Guide

This guide will help you set up and run the AI-powered exam proctoring application on your local machine.

---

## 📋 Prerequisites

Before you begin, ensure you have the following installed on your machine:

1. **Python 3.9 or higher**
   - Download from: https://www.python.org/downloads/
   - Verify: `python --version` or `python3 --version`

2. **Node.js 16 or higher** (includes npm)
   - Download from: https://nodejs.org/
   - Verify: `node --version` and `npm --version`

3. **MongoDB** (Local installation or MongoDB Atlas free tier)
   - Option A: Local MongoDB - https://www.mongodb.com/try/download/community
   - Option B: MongoDB Atlas (Free) - https://www.mongodb.com/cloud/atlas/register
   - Verify: `mongod --version` (for local installation)

4. **Git** (to clone the repository)
   - Download from: https://git-scm.com/downloads
   - Verify: `git --version`

---

## 📥 Installation Steps

### Step 1: Clone/Download the Repository

```bash
# If using Git
git clone <your-repository-url>
cd exam-proctoring-app

# OR simply extract the downloaded ZIP file and navigate to the folder
cd exam-proctoring-app
```

### Step 2: Backend Setup

1. **Navigate to backend directory:**
   ```bash
   cd backend
   ```

2. **Create Python virtual environment:**
   ```bash
   # On Windows
   python -m venv venv
   venv\Scripts\activate

   # On Mac/Linux
   python3 -m venv venv
   source venv/bin/activate
   ```

3. **Install Python dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

4. **Download YOLO model (required for object detection):**
   ```bash
   python download_model.py
   ```

5. **Create `.env` file in backend folder:**
   ```bash
   # Create .env file
   touch .env  # On Mac/Linux
   # OR
   type nul > .env  # On Windows
   ```

6. **Edit backend/.env file and add:**
   ```env
   # MongoDB Connection
   MONGO_URL=mongodb://localhost:27017/exam_proctoring

   # If using MongoDB Atlas, use this format instead:
   # MONGO_URL=mongodb+srv://<username>:<password>@cluster0.xxxxx.mongodb.net/exam_proctoring

   # Admin Password (for admin dashboard)
   ADMIN_PASSWORD=vinay

   # Supabase Configuration (Optional - for image storage)
   SUPABASE_URL=https://ukwnvvuqmiqrjlghgxnf.supabase.co
   SUPABASE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVrd252dnVxbWlxcmpsZ2hneG5mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ1NTU3NzUsImV4cCI6MjA2MDEzMTc3NX0.3VHYXmGdUAU0IW8vGZlvklvOY1kqXAOpBCxwSzL33TM
   ```

### Step 3: Frontend Setup

1. **Open a NEW terminal** (keep backend terminal open)

2. **Navigate to frontend directory:**
   ```bash
   cd frontend
   ```

3. **Install Node dependencies:**
   ```bash
   npm install
   # OR if you prefer yarn
   # yarn install
   ```

4. **Create `.env` file in frontend folder:**
   ```bash
   # Create .env file
   touch .env  # On Mac/Linux
   # OR
   type nul > .env  # On Windows
   ```

5. **Edit frontend/.env file and add:**
   ```env
   # Backend API URL
   VITE_REACT_APP_BACKEND_URL=http://localhost:8001

   # Supabase Configuration (Optional)
   VITE_SUPABASE_URL=https://ukwnvvuqmiqrjlghgxnf.supabase.co
   VITE_SUPABASE_PUBLISHABLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVrd252dnVxbWlxcmpsZ2hneG5mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQ1NTU3NzUsImV4cCI6MjA2MDEzMTc3NX0.3VHYXmGdUAU0IW8vGZlvklvOY1kqXAOpBCxwSzL33TM
   ```

### Step 4: Start MongoDB (if using local installation)

```bash
# On Windows
mongod

# On Mac/Linux
sudo mongod
# OR
brew services start mongodb-community  # If installed via Homebrew
```

---

## 🎯 Running the Application

### Start Backend Server (Terminal 1)

```bash
cd backend
# Activate virtual environment if not already activated
# Windows: venv\Scripts\activate
# Mac/Linux: source venv/bin/activate

# Run the server
python server.py
# OR
uvicorn server:app --host 0.0.0.0 --port 8001 --reload
```

**Expected Output:**
```
INFO:     Uvicorn running on http://0.0.0.0:8001
INFO:     Application startup complete.
```

### Start Frontend Server (Terminal 2)

```bash
cd frontend

# Run the development server
npm run dev
# OR
yarn dev
```

**Expected Output:**
```
VITE v4.x.x  ready in XXX ms

➜  Local:   http://localhost:3000/
➜  Network: use --host to expose
```

---

## 🌐 Accessing the Application

Once both servers are running:

1. **Student Portal:** http://localhost:3000/
   - Register as a student
   - Complete environment verification
   - Take proctored exam

2. **Admin Dashboard:** http://localhost:3000/admin/login
   - Password: `vinay`
   - Monitor students in real-time
   - View violations and export reports

---

## 🔧 Configuration

### MongoDB Configuration

**Option 1: Local MongoDB**
```env
MONGO_URL=mongodb://localhost:27017/exam_proctoring
```

**Option 2: MongoDB Atlas (Recommended for production)**
1. Create free account at https://www.mongodb.com/cloud/atlas
2. Create a cluster
3. Get connection string
4. Update `.env`:
```env
MONGO_URL=mongodb+srv://<username>:<password>@cluster0.xxxxx.mongodb.net/exam_proctoring
```

### Supabase Configuration (Optional)

The application uses Supabase for storing violation snapshots. You can:
- Use the provided credentials (limited storage)
- Create your own Supabase project at https://supabase.com
- Or disable image storage (snapshots will be stored as base64 in MongoDB)

---

## 🎨 Features

### Student Features:
- ✅ Quick registration with auto-generated ID
- ✅ Environment verification (camera, lighting, face detection)
- ✅ Real-time AI proctoring during exam
- ✅ Violation detection: looking away, multiple faces, phone/book detection
- ✅ Browser monitoring: copy/paste, tab switching
- ✅ Audio monitoring for excessive noise

### Admin Features:
- ✅ Real-time monitoring dashboard
- ✅ Live violation alerts with WebSocket
- ✅ Statistics and analytics
- ✅ Violation timeline charts
- ✅ Evidence gallery with snapshots
- ✅ Export reports (CSV and PDF)
- ✅ Student-wise violation tracking

### AI Detection:
- 🤖 **MediaPipe** for face detection and head pose estimation
- 🤖 **YOLOv8n** for object detection (phone, books)
- 🤖 Real-time processing every 2 seconds
- 🤖 Confidence thresholds for accurate detection

---

## 🐛 Troubleshooting

### Issue: Backend won't start

**Error: `ModuleNotFoundError`**
```bash
# Solution: Reinstall dependencies
pip install -r requirements.txt
```

**Error: MongoDB connection failed**
```bash
# Solution: Check if MongoDB is running
# Windows: Check Task Manager for mongod process
# Mac/Linux: ps aux | grep mongod

# Start MongoDB if not running
mongod
```

### Issue: Frontend won't start

**Error: `Cannot find module`**
```bash
# Solution: Delete node_modules and reinstall
rm -rf node_modules package-lock.json
npm install
```

**Error: `Port 3000 already in use`**
```bash
# Solution: Kill the process using port 3000
# Windows:
netstat -ano | findstr :3000
taskkill /PID <PID> /F

# Mac/Linux:
lsof -ti:3000 | xargs kill -9
```

### Issue: Camera not working

**Solution:**
- Grant browser camera permissions
- Check if another application is using the camera
- Try a different browser (Chrome recommended)

### Issue: YOLO model not found

**Error: `Model file not found`**
```bash
# Solution: Download the model manually
cd backend
python download_model.py
```

### Issue: CORS errors in browser

**Solution:**
- Ensure backend is running on http://localhost:8001
- Check frontend .env has correct VITE_REACT_APP_BACKEND_URL
- Clear browser cache and reload

---

## 📁 Project Structure

```
exam-proctoring-app/
├── backend/
│   ├── server.py              # Main FastAPI application
│   ├── proctoring_service.py  # AI detection logic
│   ├── models.py              # Pydantic data models
│   ├── websocket_manager.py   # WebSocket handling
│   ├── export_service.py      # CSV/PDF export
│   ├── supabase_db_service.py # Supabase integration
│   ├── download_model.py      # YOLO model downloader
│   ├── requirements.txt       # Python dependencies
│   └── .env                   # Backend environment variables
│
├── frontend/
│   ├── src/
│   │   ├── pages/            # React pages
│   │   ├── components/       # UI components
│   │   ├── services/         # API services
│   │   └── utils/            # Helper utilities
│   ├── package.json          # Node dependencies
│   └── .env                  # Frontend environment variables
│
└── README_LOCAL_SETUP.md     # This file
```

---

## 🔒 Security Notes

1. **Change Admin Password:**
   - Update `ADMIN_PASSWORD` in backend/.env
   - Update password validation in backend/server.py

2. **MongoDB Security:**
   - Enable authentication in production
   - Use strong passwords
   - Restrict network access

3. **Supabase Keys:**
   - The provided keys are for development only
   - Create your own Supabase project for production
   - Never commit .env files to version control

---

## 📝 Environment Variables Reference

### Backend (.env)
```env
MONGO_URL=mongodb://localhost:27017/exam_proctoring
ADMIN_PASSWORD=vinay
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_key
```

### Frontend (.env)
```env
VITE_REACT_APP_BACKEND_URL=http://localhost:8001
VITE_SUPABASE_URL=your_supabase_url
VITE_SUPABASE_PUBLISHABLE_KEY=your_supabase_key
```

---

## 🚀 Quick Start Script

Create a file `start.sh` (Mac/Linux) or `start.bat` (Windows):

**Mac/Linux (start.sh):**
```bash
#!/bin/bash

# Start MongoDB
brew services start mongodb-community

# Start Backend
cd backend
source venv/bin/activate
python server.py &

# Start Frontend
cd ../frontend
npm run dev &

echo "Application started!"
echo "Frontend: http://localhost:3000"
echo "Backend: http://localhost:8001"
```

**Windows (start.bat):**
```batch
@echo off

REM Start Backend
start cmd /k "cd backend && venv\Scripts\activate && python server.py"

REM Wait 5 seconds
timeout /t 5

REM Start Frontend
start cmd /k "cd frontend && npm run dev"

echo Application started!
echo Frontend: http://localhost:3000
echo Backend: http://localhost:8001
```

---

## 📞 Support

If you encounter any issues:
1. Check the troubleshooting section above
2. Verify all prerequisites are installed
3. Ensure MongoDB is running
4. Check that both .env files are configured correctly
5. Look for error messages in terminal outputs

---

## 🎉 Success!

If everything is set up correctly, you should see:
- ✅ Backend running on http://localhost:8001
- ✅ Frontend running on http://localhost:3000
- ✅ MongoDB connected
- ✅ AI models loaded
- ✅ WebSocket connections active

Happy proctoring! 🎓
