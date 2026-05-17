# Security Dashboard — Setup Guide

## What this does
Combines all your Wyze and D-Link camera streams into one browser-based
dashboard with a 4-camera-per-row grid, click-to-expand, and remote access.

---

## Step 1 — Install Docker Desktop on Mac

1. Go to https://www.docker.com/products/docker-desktop/
2. Download "Docker Desktop for Mac" (choose Apple Silicon or Intel to match your Mac)
3. Open the `.dmg`, drag Docker to Applications, launch it
4. Wait for the whale icon in your menu bar to stop animating — Docker is ready

---

## Step 2 — Find your Mac's local IP address

Open **Terminal** and run:
```
ipconfig getifaddr en0
```
Copy the result (e.g. `192.168.1.100`). You'll need it shortly.

---

## Step 3 — Get your Wyze API key

1. Go to https://developer-api-console.wyze.com
2. Sign in with your Wyze account
3. Click **API Keys** → **Add Key**
4. Copy the **API ID** and **API Key**

---

## Step 4 — Find your D-Link camera IPs and RTSP URLs

1. Open your router's admin page (usually http://192.168.1.1)
2. Look at connected devices — find your D-Link cameras and note their IPs
3. The RTSP URL format is usually:
   ```
   rtsp://admin:YOUR_PASSWORD@CAMERA_IP:554/live/ch00_0
   ```
   If that doesn't work, try:
   ```
   rtsp://admin:YOUR_PASSWORD@CAMERA_IP:554/play1.sdp
   ```
   You can test a URL with VLC: File → Open Network → paste the URL

---

## Step 5 — Configure the app

In the `security-dashboard` folder:

1. Copy `.env.example` to `.env`:
   ```
   cp .env.example .env
   ```

2. Open `.env` in a text editor and fill in:
   - Your Wyze email, password, API ID, API key
   - Your Mac's IP address (from Step 2)
   - Your D-Link camera RTSP URLs

3. Open `dashboard/app.js` and edit the `CAMERAS` array:
   - Replace `HOST_IP` with your Mac's IP address in every `streamUrl`
   - Update labels and camera names to match your actual cameras
   - The Wyze camera name in the stream URL must match the camera name
     shown in the Wyze app (lowercase, hyphens instead of spaces)

4. If you have more than 2 D-Link cameras, duplicate the `dlink-cam2`
   block in `docker-compose.yml` for each additional camera and add the
   corresponding `DLINK_CAMN_RTSP` line to `.env`

---

## Step 6 — Start the dashboard

Open Terminal, navigate to the `security-dashboard` folder, and run:

```bash
cd ~/security-dashboard       # adjust path if needed
docker compose up -d
```

Docker will download the required images (takes a few minutes the first time).

After it starts:
- Dashboard: http://localhost:3000
- Wyze bridge UI: http://localhost:5000 (shows which cameras are connected)
- D-Link HLS server: http://localhost:8080

---

## Step 7 — Remote access with Tailscale (access from anywhere)

Tailscale creates a private VPN — no port forwarding or static IP needed.

1. Go to https://tailscale.com and create a free account
2. Download Tailscale for Mac and install it
3. Also install Tailscale on your phone/laptop you'll view from remotely
4. Sign in on both devices with the same Tailscale account
5. In Tailscale's menu bar icon on the Mac, find the Mac's Tailscale IP
   (looks like `100.x.x.x`)
6. From any device on Tailscale, open:
   ```
   http://100.x.x.x:3000
   ```
   Replace `100.x.x.x` with your Mac's Tailscale IP.

---

## Step 8 — Camera name mapping for Wyze

The stream URL `http://HOST_IP:8888/front-door/stream.m3u8` uses the
camera's name from the Wyze app, converted to lowercase with spaces
replaced by hyphens.

Examples:
| Wyze app name     | Stream URL path     |
|-------------------|---------------------|
| Front Door        | /front-door/        |
| Backyard Cam      | /backyard-cam/      |
| Garage Left       | /garage-left/       |

Open http://localhost:5000 after starting to see the exact names wyze-bridge
detected.

---

## Useful commands

```bash
# Start all services
docker compose up -d

# Stop all services
docker compose down

# See logs for a specific service
docker compose logs -f wyze-bridge
docker compose logs -f dlink-cam1

# Restart a single service
docker compose restart dlink-cam1

# Pull latest images (for updates)
docker compose pull && docker compose up -d
```

---

## Dashboard controls

| Action | How |
|--------|-----|
| Expand a camera | Click any tile |
| Close expanded view | Click X or press Escape |
| Toggle grid layout (2/3/4 cols) | Click the grid icon in the header |
| Fullscreen | Click the fullscreen icon |
| Status dot | Green = live, Orange = connecting, Red = error (auto-retries) |
