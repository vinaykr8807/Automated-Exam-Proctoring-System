# 🐳 Push Docker Image to Docker Hub

## Steps to Push to Docker Hub

### 1. Login to Docker Hub

```bash
docker login
```

Enter your Docker Hub username and password when prompted.

### 2. Tag the Image

Replace `YOUR_DOCKERHUB_USERNAME` with your actual Docker Hub username:

```bash
docker tag exameye-shield---enhanced-edition-main-exameye-shield:latest YOUR_DOCKERHUB_USERNAME/exameye-shield:latest
```

### 3. Push the Image

```bash
docker push YOUR_DOCKERHUB_USERNAME/exameye-shield:latest
```

### 4. Verify

Check your Docker Hub repository to confirm the image was pushed successfully.

---

## Quick Script

You can also use this PowerShell script:

```powershell
# Set your Docker Hub username
$DOCKERHUB_USERNAME = "your-username"

# Login (will prompt for password)
docker login

# Tag the image
docker tag exameye-shield---enhanced-edition-main-exameye-shield:latest "$DOCKERHUB_USERNAME/exameye-shield:latest"

# Push the image
docker push "$DOCKERHUB_USERNAME/exameye-shield:latest"
```

---

## After Pushing

Once pushed, you can pull and run the image from anywhere:

```bash
docker pull YOUR_DOCKERHUB_USERNAME/exameye-shield:latest
docker run -d -p 80:80 \
  -e SUPABASE_URL=your-url \
  -e SUPABASE_KEY=your-key \
  YOUR_DOCKERHUB_USERNAME/exameye-shield:latest
```

---

## Deploy on Railway with Docker Hub

1. Go to Railway → New Service
2. Select "Deploy from Docker Hub"
3. Enter: `YOUR_DOCKERHUB_USERNAME/exameye-shield:latest`
4. Set environment variables
5. Deploy!

