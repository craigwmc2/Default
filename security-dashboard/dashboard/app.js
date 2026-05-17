// Inline camera config — edit this to match your setup.
// streamUrl uses HOST_IP — replace with your Mac's local IP or Tailscale IP.
const CAMERAS = [
  {
    id:        "wyze-cam1",
    label:     "Front Door",
    type:      "wyze",
    streamUrl: "http://HOST_IP:8888/front-door/stream.m3u8",
  },
  {
    id:        "wyze-cam2",
    label:     "Backyard",
    type:      "wyze",
    streamUrl: "http://HOST_IP:8888/backyard/stream.m3u8",
  },
  {
    id:        "wyze-cam3",
    label:     "Garage",
    type:      "wyze",
    streamUrl: "http://HOST_IP:8888/garage/stream.m3u8",
  },
  {
    id:        "dlink-cam1",
    label:     "Driveway",
    type:      "dlink",
    streamUrl: "http://HOST_IP:8080/hls/dlink-cam1/stream.m3u8",
  },
  {
    id:        "dlink-cam2",
    label:     "Side Gate",
    type:      "dlink",
    streamUrl: "http://HOST_IP:8080/hls/dlink-cam2/stream.m3u8",
  },
];

const LAYOUTS = [2, 3, 4];
let currentLayout = 4;
let lightboxHls = null;

// ── Grid setup ──────────────────────────────────────────────────────────────
const grid = document.getElementById("grid");
grid.style.setProperty("--cols", currentLayout);

CAMERAS.forEach((cam) => {
  const tile = document.createElement("div");
  tile.className = "tile";
  tile.dataset.id = cam.id;

  const video = document.createElement("video");
  video.autoplay = true;
  video.muted = true;
  video.playsInline = true;

  const placeholder = document.createElement("div");
  placeholder.className = "tile-placeholder";
  placeholder.innerHTML = `<span class="icon">&#128247;</span><span>${cam.label}</span>`;

  const status = document.createElement("div");
  status.className = "tile-status loading";

  const label = document.createElement("div");
  label.className = "tile-label";
  label.innerHTML = `
    <span class="tile-type ${cam.type}">${cam.type.toUpperCase()}</span>
    ${cam.label}
  `;

  const overlay = document.createElement("div");
  overlay.className = "tile-overlay";

  tile.append(video, placeholder, status, label, overlay);
  grid.appendChild(tile);

  attachStream(video, cam.streamUrl, status, placeholder);

  tile.addEventListener("click", () => openLightbox(cam, video));
});

updateCamCount();

// ── HLS stream attachment ────────────────────────────────────────────────────
function attachStream(video, url, statusEl, placeholderEl) {
  if (Hls.isSupported()) {
    const hls = new Hls({
      enableWorker: true,
      lowLatencyMode: true,
      backBufferLength: 10,
    });
    hls.loadSource(url);
    hls.attachMedia(video);

    hls.on(Hls.Events.MANIFEST_PARSED, () => {
      video.play().catch(() => {});
      statusEl.className = "tile-status live";
      placeholderEl.classList.add("hidden");
    });

    hls.on(Hls.Events.ERROR, (_, data) => {
      if (data.fatal) {
        statusEl.className = "tile-status error";
        // Auto-retry after 10 s
        setTimeout(() => {
          hls.destroy();
          statusEl.className = "tile-status loading";
          placeholderEl.classList.remove("hidden");
          attachStream(video, url, statusEl, placeholderEl);
        }, 10_000);
      }
    });
  } else if (video.canPlayType("application/vnd.apple.mpegurl")) {
    // Safari native HLS
    video.src = url;
    video.addEventListener("loadedmetadata", () => {
      video.play().catch(() => {});
      statusEl.className = "tile-status live";
      placeholderEl.classList.add("hidden");
    });
    video.addEventListener("error", () => {
      statusEl.className = "tile-status error";
    });
  }
}

// ── Lightbox ─────────────────────────────────────────────────────────────────
const lightbox      = document.getElementById("lightbox");
const lightboxVideo = document.getElementById("lightbox-video");
const lightboxLabel = document.getElementById("lightbox-label");
const lightboxClose = document.getElementById("lightbox-close");

function openLightbox(cam, _tileVideo) {
  lightboxLabel.textContent = cam.label;
  lightbox.classList.remove("hidden");

  if (lightboxHls) { lightboxHls.destroy(); lightboxHls = null; }

  if (Hls.isSupported()) {
    lightboxHls = new Hls({ enableWorker: true });
    lightboxHls.loadSource(cam.streamUrl);
    lightboxHls.attachMedia(lightboxVideo);
    lightboxHls.on(Hls.Events.MANIFEST_PARSED, () => lightboxVideo.play().catch(() => {}));
  } else {
    lightboxVideo.src = cam.streamUrl;
    lightboxVideo.play().catch(() => {});
  }
}

function closeLightbox() {
  lightbox.classList.add("hidden");
  lightboxVideo.pause();
  lightboxVideo.src = "";
  if (lightboxHls) { lightboxHls.destroy(); lightboxHls = null; }
}

lightboxClose.addEventListener("click", closeLightbox);
lightbox.addEventListener("click", (e) => { if (e.target === lightbox) closeLightbox(); });
document.addEventListener("keydown", (e) => { if (e.key === "Escape") closeLightbox(); });

// ── Layout toggle ────────────────────────────────────────────────────────────
document.getElementById("layout-btn").addEventListener("click", () => {
  const idx = LAYOUTS.indexOf(currentLayout);
  currentLayout = LAYOUTS[(idx + 1) % LAYOUTS.length];
  grid.style.setProperty("--cols", currentLayout);
});

// ── Fullscreen ────────────────────────────────────────────────────────────────
document.getElementById("fullscreen-btn").addEventListener("click", () => {
  if (!document.fullscreenElement) {
    document.documentElement.requestFullscreen();
  } else {
    document.exitFullscreen();
  }
});

// ── Clock ─────────────────────────────────────────────────────────────────────
function updateClock() {
  document.getElementById("clock").textContent =
    new Date().toLocaleString(undefined, {
      weekday: "short", month: "short", day: "numeric",
      hour: "2-digit", minute: "2-digit", second: "2-digit",
    });
}
updateClock();
setInterval(updateClock, 1000);

function updateCamCount() {
  document.getElementById("cam-count").textContent = `${CAMERAS.length} cameras`;
}
