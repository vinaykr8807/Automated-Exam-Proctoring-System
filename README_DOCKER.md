# 🐳 Quick Docker Deployment Guide

## Single Docker Image with Both Frontend & Backend

This project uses a **single Docker image** that contains both the React frontend and Python backend, running together.

## 🚀 Quick Start

### 1. Create `.env` file

```env
# Backend
SUPABASE_URL=https://ukwnvvuqmiqrjlghgxnf.supabase.co
SUPABASE_KEY=your-service-role-key

# Frontend (used at build time)
VITE_SUPABASE_URL=https://ukwnvvuqmiqrjlghgxnf.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=your-anon-key
VITE_PROCTORING_API_URL=http://localhost:8001
VITE_PROCTORING_WS_URL=ws://localhost:8001
```

### 2. Build and Run

**Option A: Using Docker Compose (Easiest)**
```bash
docker-compose up -d
```

**Option B: Using Build Script**
```bash
./build-docker.sh
docker run -d -p 80:80 --name exameye-shield \
  -e SUPABASE_URL=your-url \
  -e SUPABASE_KEY=your-key \
  exameye-shield:latest
```

**Option C: Manual Build**
```bash
docker build \
  --build-arg VITE_SUPABASE_URL=https://ukwnvvuqmiqrjlghgxnf.supabase.co \
  --build-arg VITE_SUPABASE_PUBLISHABLE_KEY=your-anon-key \
  --build-arg VITE_PROCTORING_API_URL=http://localhost:8001 \
  --build-arg VITE_PROCTORING_WS_URL=ws://localhost:8001 \
  -t exameye-shield:latest .

docker run -d -p 80:80 --name exameye-shield \
  -e SUPABASE_URL=your-url \
  -e SUPABASE_KEY=your-key \
  exameye-shield:latest
```

### 3. Access Application

- **Frontend**: http://localhost
- **Backend API**: http://localhost/api/health
- **WebSocket**: ws://localhost/api/ws/

## 🚂 Deploy to Railway

1. **Push code to GitHub**
2. **Create Railway project** → Connect GitHub repo
3. **Railway auto-detects Dockerfile**
4. **Set environment variables** in Railway dashboard:
   ```
   SUPABASE_URL=...
   SUPABASE_KEY=...
   VITE_SUPABASE_URL=...
   VITE_SUPABASE_PUBLISHABLE_KEY=...
   VITE_PROCTORING_API_URL=https://your-railway-url.railway.app/api
   VITE_PROCTORING_WS_URL=wss://your-railway-url.railway.app/api/ws
   ```
5. **Deploy** - Railway builds and deploys automatically!

## 📋 What's Inside?

- ✅ React Frontend (built and served by Nginx)
- ✅ Python FastAPI Backend (runs on port 8001)
- ✅ Supervisor (manages both services)
- ✅ Nginx (serves frontend, proxies API to backend)
- ✅ All dependencies pre-installed

## 🔍 Verify It's Working

```bash
# Check container status
docker ps

# View logs
docker logs exameye-shield

# Check services inside container
docker exec exameye-shield supervisorctl status
```

## 📚 Full Documentation

See `DOCKER_DEPLOYMENT.md` for detailed documentation.

