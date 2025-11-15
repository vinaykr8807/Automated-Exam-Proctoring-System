# Multi-stage Dockerfile for ExamEye Shield
# Combines Frontend (React) and Backend (Python FastAPI) in one image

# ============================================
# Stage 1: Frontend Build
# ============================================
FROM node:18-alpine AS frontend-builder

WORKDIR /app/frontend

# Accept build arguments for frontend environment variables
ARG VITE_SUPABASE_URL
ARG VITE_SUPABASE_PUBLISHABLE_KEY
ARG VITE_PROCTORING_API_URL
ARG VITE_PROCTORING_WS_URL

# Set environment variables for build
ENV VITE_SUPABASE_URL=$VITE_SUPABASE_URL
ENV VITE_SUPABASE_PUBLISHABLE_KEY=$VITE_SUPABASE_PUBLISHABLE_KEY
ENV VITE_PROCTORING_API_URL=$VITE_PROCTORING_API_URL
ENV VITE_PROCTORING_WS_URL=$VITE_PROCTORING_WS_URL

# Copy frontend package files
COPY frontend/package*.json ./
COPY frontend/bun.lockb ./

# Install frontend dependencies
RUN npm ci

# Copy frontend source code
COPY frontend/ .

# Build frontend (environment variables are embedded at build time)
RUN npm run build

# ============================================
# Stage 2: Backend Setup
# ============================================
FROM python:3.11-slim-bookworm AS backend-setup

WORKDIR /app/backend

# Install system dependencies for OpenCV and MediaPipe
# Using bookworm (stable) packages and retry logic for network issues
RUN apt-get update --fix-missing && \
    apt-get install -y --no-install-recommends \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    supervisor \
    nginx \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy backend requirements
COPY backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend code
COPY backend/ .

# Download YOLOv8n model
RUN python download_model.py

# ============================================
# Stage 3: Final Production Image
# ============================================
FROM python:3.11-slim-bookworm

WORKDIR /app

# Install system dependencies
# Using bookworm (stable) packages and retry logic for network issues
RUN apt-get update --fix-missing && \
    apt-get install -y --no-install-recommends \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    supervisor \
    nginx \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy Python dependencies from backend-setup
COPY --from=backend-setup /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=backend-setup /usr/local/bin /usr/local/bin

# Copy backend application
COPY --from=backend-setup /app/backend /app/backend

# Copy frontend build
COPY --from=frontend-builder /app/frontend/build /app/frontend/build

# Create nginx configuration for frontend
RUN echo 'server { \
    listen 80; \
    server_name _; \
    root /app/frontend/build; \
    index index.html; \
    \
    # Gzip compression \
    gzip on; \
    gzip_vary on; \
    gzip_min_length 1024; \
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json application/javascript; \
    \
    # SPA routing \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
    \
    # API proxy to backend \
    location /api/ { \
        proxy_pass http://localhost:8001; \
        proxy_http_version 1.1; \
        proxy_set_header Upgrade $http_upgrade; \
        proxy_set_header Connection "upgrade"; \
        proxy_set_header Host $host; \
        proxy_set_header X-Real-IP $remote_addr; \
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; \
        proxy_set_header X-Forwarded-Proto $scheme; \
    } \
    \
    # WebSocket proxy \
    location /api/ws/ { \
        proxy_pass http://localhost:8001; \
        proxy_http_version 1.1; \
        proxy_set_header Upgrade $http_upgrade; \
        proxy_set_header Connection "upgrade"; \
        proxy_set_header Host $host; \
        proxy_set_header X-Real-IP $remote_addr; \
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; \
        proxy_set_header X-Forwarded-Proto $scheme; \
    } \
    \
    # Cache static assets \
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ { \
        expires 1y; \
        add_header Cache-Control "public, immutable"; \
    } \
}' > /etc/nginx/sites-available/default

# Create supervisor configuration to run both services
RUN echo '[supervisord] \
nodaemon=true \
logfile=/var/log/supervisor/supervisord.log \
pidfile=/var/run/supervisord.pid \
\
[program:backend] \
command=uvicorn server:app --host 0.0.0.0 --port 8001 --workers 2 \
directory=/app/backend \
autostart=true \
autorestart=true \
stderr_logfile=/var/log/supervisor/backend.err.log \
stdout_logfile=/var/log/supervisor/backend.out.log \
\
[program:nginx] \
command=nginx -g "daemon off;" \
autostart=true \
autorestart=true \
stderr_logfile=/var/log/supervisor/nginx.err.log \
stdout_logfile=/var/log/supervisor/nginx.out.log' > /etc/supervisor/conf.d/supervisord.conf

# Create startup script
RUN echo '#!/bin/bash \
set -e \
\
# Start supervisor which manages both nginx and backend \
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf' > /app/start.sh && \
chmod +x /app/start.sh

# Expose ports
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD curl -f http://localhost:80/ || exit 1

# Start supervisor
CMD ["/app/start.sh"]

