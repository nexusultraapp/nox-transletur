/**
 * NOXIR Play - Interactive Landing Page Script
 * Gameplay Translation Simulator & Interactive App Showcase
 */

// --- 1. GAMEPLAY & AI TRANSLATION SIMULATOR ---
const scenes = [
  {
    title: "God of War Ragnarök - Aksiyon Sahnesi",
    bgGradient: ["#141E30", "#243B55", "#0F2027"],
    speaker: "KRATOS",
    englishText: "Do not be sorry. Be better! The path ahead is treacherous.",
    turkishText: "Özür dileme. Daha iyi ol! Önümüzdeki yol tehlikelerle dolu.",
    latency: "11 ms",
    fps: "60.0",
    boxY: 0.62
  },
  {
    title: "The Last of Us Part I - Diyalog Sahnesi",
    bgGradient: ["#1F1C2C", "#928DAB", "#110D20"],
    speaker: "JOEL",
    englishText: "No matter what, you keep finding something to fight for.",
    turkishText: "Ne olursa olsun, her zaman uğrunda savaşacak bir şey bulursun.",
    latency: "14 ms",
    fps: "59.9",
    boxY: 0.65
  },
  {
    title: "Cyberpunk 2077 - Görev Sahnesi",
    bgGradient: ["#000428", "#004e92", "#050510"],
    speaker: "JOHNNY SILVERHAND",
    englishText: "Wake up, samurai! We've got a city to burn.",
    turkishText: "Uyan samuray! Yakacak koca bir şehrimiz var.",
    latency: "9 ms",
    fps: "60.0",
    boxY: 0.60
  }
];

let currentSceneIndex = 0;
let isPlaying = true;
let showOriginal = true;
let canvas, ctx;
let particles = [];
let scanLaserY = 0;
let scanLaserDirection = 1;

function initCanvas() {
  canvas = document.getElementById("gameCanvas");
  if (!canvas) return;
  ctx = canvas.getContext("2d");

  function resize() {
    canvas.width = canvas.parentElement.clientWidth;
    canvas.height = canvas.parentElement.clientHeight;
    createParticles();
  }

  window.addEventListener("resize", resize);
  resize();

  // Start simulation loop
  requestAnimationFrame(simulationLoop);
}

function createParticles() {
  particles = [];
  const count = 45;
  for (let i = 0; i < count; i++) {
    particles.push({
      x: Math.random() * canvas.width,
      y: Math.random() * canvas.height,
      radius: Math.random() * 2 + 0.8,
      speedX: (Math.random() - 0.5) * 0.8,
      speedY: (Math.random() - 0.5) * 0.8,
      alpha: Math.random() * 0.6 + 0.2
    });
  }
}

function simulationLoop() {
  if (!canvas || !ctx) return;

  const scene = scenes[currentSceneIndex];

  // Draw cinematic background
  const grad = ctx.createRadialGradient(
    canvas.width / 2, canvas.height / 2, 50,
    canvas.width / 2, canvas.height / 2, canvas.width / 1.1
  );
  grad.addColorStop(0, scene.bgGradient[0]);
  grad.addColorStop(0.6, scene.bgGradient[1]);
  grad.addColorStop(1, scene.bgGradient[2]);

  ctx.fillStyle = grad;
  ctx.fillRect(0, 0, canvas.width, canvas.height);

  // Draw moving cinematic dust/atmosphere particles
  ctx.fillStyle = "rgba(255, 255, 255, 0.7)";
  for (let p of particles) {
    if (isPlaying) {
      p.x += p.speedX;
      p.y += p.speedY;
      if (p.x < 0) p.x = canvas.width;
      if (p.x > canvas.width) p.x = 0;
      if (p.y < 0) p.y = canvas.height;
      if (p.y > canvas.height) p.y = 0;
    }

    ctx.beginPath();
    ctx.arc(p.x, p.y, p.radius, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(180, 210, 255, ${p.alpha})`;
    ctx.fill();
  }

  // Draw simulated 3D cinematic vignette & gaming crosshair/hud
  ctx.strokeStyle = "rgba(255, 255, 255, 0.04)";
  ctx.lineWidth = 1;
  ctx.beginPath();
  ctx.arc(canvas.width / 2, canvas.height / 2, 60, 0, Math.PI * 2);
  ctx.stroke();

  // Draw AI Scanning Laser line inside Subtitle Crop region
  const cropW = Math.min(canvas.width * 0.75, 750);
  const cropH = 110;
  const cropX = (canvas.width - cropW) / 2;
  const cropY = canvas.height * scene.boxY;

  // Yellow dashed bounding box
  ctx.strokeStyle = "rgba(255, 215, 0, 0.8)";
  ctx.lineWidth = 2;
  ctx.setLineDash([8, 6]);
  ctx.strokeRect(cropX, cropY, cropW, cropH);
  ctx.setLineDash([]);

  // Tag: PP-OCRv6 AKTIF
  ctx.fillStyle = "rgba(255, 215, 0, 0.95)";
  ctx.fillRect(cropX + cropW - 140, cropY - 22, 140, 22);
  ctx.fillStyle = "#000";
  ctx.font = "bold 11px Segoe UI, sans-serif";
  ctx.fillText("⚡ PP-OCRv6 TARAMA", cropX + cropW - 132, cropY - 7);

  // Moving Laser Scanner
  if (isPlaying) {
    scanLaserY += 1.8 * scanLaserDirection;
    if (scanLaserY > cropH - 4 || scanLaserY < 4) {
      scanLaserDirection *= -1;
    }
  }

  const laserGrad = ctx.createLinearGradient(cropX, cropY + scanLaserY, cropX + cropW, cropY + scanLaserY);
  laserGrad.addColorStop(0, "rgba(0, 229, 255, 0)");
  laserGrad.addColorStop(0.5, "rgba(0, 229, 255, 0.85)");
  laserGrad.addColorStop(1, "rgba(0, 229, 255, 0)");

  ctx.strokeStyle = laserGrad;
  ctx.lineWidth = 2.5;
  ctx.beginPath();
  ctx.moveTo(cropX + 2, cropY + scanLaserY);
  ctx.lineTo(cropX + cropW - 2, cropY + scanLaserY);
  ctx.stroke();

  requestAnimationFrame(simulationLoop);
}

function updateSceneUI() {
  const scene = scenes[currentSceneIndex];

  const hudLatency = document.getElementById("hudLatency");
  const hudScene = document.getElementById("hudScene");
  const origTextEl = document.getElementById("origSubtitleText");
  const transTextEl = document.getElementById("transSubtitleText");
  const speakerEl = document.getElementById("transSpeaker");

  if (hudLatency) hudLatency.innerText = scene.latency;
  if (hudScene) hudScene.innerText = scene.title;
  if (origTextEl) origTextEl.innerText = scene.englishText;
  if (transTextEl) transTextEl.innerText = scene.turkishText;
  if (speakerEl) speakerEl.innerText = scene.speaker + ":";

  // Re-trigger subtitle pop animation
  const transBox = document.getElementById("transSubtitleBox");
  if (transBox) {
    transBox.style.animation = "none";
    transBox.offsetHeight; // trigger reflow
    transBox.style.animation = "subtitlePop 0.35s ease";
  }
}

// Controls
function togglePlay() {
  isPlaying = !isPlaying;
  const btn = document.getElementById("btnTogglePlay");
  if (btn) {
    btn.innerHTML = isPlaying ? "⏸️ Duraklat" : "▶️ Oynat";
  }
}

function nextScene() {
  currentSceneIndex = (currentSceneIndex + 1) % scenes.length;
  updateSceneUI();
}

function toggleOriginalView() {
  showOriginal = !showOriginal;
  const origBox = document.getElementById("origSubtitleBox");
  const btn = document.getElementById("btnToggleOrig");
  if (origBox) origBox.style.display = showOriginal ? "block" : "none";
  if (btn) btn.classList.toggle("active", showOriginal);
}

// --- 2. INTERACTIVE APP UI MOCKUP TABS ---
function switchAppTab(tabName) {
  const navItems = document.querySelectorAll(".app-nav-item");
  const tabPanes = document.querySelectorAll(".app-tab-pane");

  navItems.forEach(item => {
    if (item.dataset.tab === tabName) {
      item.classList.add("active");
    } else {
      item.classList.remove("active");
    }
  });

  tabPanes.forEach(pane => {
    if (pane.id === "tab-" + tabName) {
      pane.classList.add("active");
    } else {
      pane.classList.remove("active");
    }
  });
}

// --- 3. SHOPIER PURCHASE MODAL & LINK ---
/**
 * DİKKAT: Shopier mağaza veya ürün linkinizi aşağıdaki tırnakların içine yapıştırabilirsiniz.
 * Örn: const SHOPIER_DEFAULT_URL = "https://www.shopier.com/ShowProductNew/products.php?id=12345678";
 */
const SHOPIER_DEFAULT_URL = "https://www.shopier.com/";

function openShopierCheckout() {
  const modal = document.getElementById("shopierModal");
  const btnGo = document.getElementById("btnShopierGo");
  if (btnGo) {
    btnGo.href = SHOPIER_DEFAULT_URL;
  }
  if (modal) {
    modal.classList.add("active");
  }
}

function closeShopierCheckout() {
  const modal = document.getElementById("shopierModal");
  if (modal) {
    modal.classList.remove("active");
  }
}

// --- 4. FAQ ACCORDION ---
function initFAQ() {
  const faqItems = document.querySelectorAll(".faq-item");
  faqItems.forEach(item => {
    const question = item.querySelector(".faq-question");
    question.addEventListener("click", () => {
      const isOpen = item.classList.contains("open");
      faqItems.forEach(i => i.classList.remove("open"));
      if (!isOpen) {
        item.classList.add("open");
      }
    });
  });
}

// --- 5. INITIALIZATION ---
document.addEventListener("DOMContentLoaded", () => {
  initCanvas();
  updateSceneUI();
  initFAQ();

  // App tabs event listeners
  const appNavItems = document.querySelectorAll(".app-nav-item");
  appNavItems.forEach(item => {
    item.addEventListener("click", () => {
      switchAppTab(item.dataset.tab);
    });
  });

  // Simulator buttons
  const btnPlay = document.getElementById("btnTogglePlay");
  if (btnPlay) btnPlay.addEventListener("click", togglePlay);

  const btnScene = document.getElementById("btnNextScene");
  if (btnScene) btnScene.addEventListener("click", nextScene);

  const btnOrig = document.getElementById("btnToggleOrig");
  if (btnOrig) btnOrig.addEventListener("click", toggleOriginalView);

  // Shopier triggers & modal close
  const shopierBtns = document.querySelectorAll(".btn-shopier-trigger");
  shopierBtns.forEach(b => b.addEventListener("click", openShopierCheckout));

  const modalCloseBtn = document.getElementById("shopierModalClose");
  if (modalCloseBtn) modalCloseBtn.addEventListener("click", closeShopierCheckout);

  const shopierModal = document.getElementById("shopierModal");
  if (shopierModal) {
    shopierModal.addEventListener("click", (e) => {
      if (e.target === shopierModal) {
        closeShopierCheckout();
      }
    });
  }

  // Escape key to close modal
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape") {
      closeShopierCheckout();
    }
  });

  // Protected download verification button & URL params check
  const btnVerify = document.getElementById("btnVerifyDownload");
  if (btnVerify) {
    btnVerify.addEventListener("click", handleDownloadVerification);
  }

  const orderInput = document.getElementById("orderInput");
  if (orderInput) {
    orderInput.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        handleDownloadVerification();
      }
    });
  }

  checkUrlPurchaseParams();
});

// --- 6. PROTECTED DOWNLOAD & VERIFICATION ---
const GITHUB_RELEASE_SETUP_URL = "https://github.com/nexusultraapp/nox-transletur/releases/download/v1.0.0/NOXIR_Play_Setup_v1.0.exe";

function handleDownloadVerification() {
  const input = document.getElementById("orderInput");
  const msg = document.getElementById("verifyMessage");
  if (!input || !msg) return;

  const code = input.value.trim();
  if (!code) {
    msg.style.display = "block";
    msg.style.background = "rgba(255, 82, 82, 0.12)";
    msg.style.border = "1px solid rgba(255, 82, 82, 0.3)";
    msg.style.color = "#ff8a80";
    msg.innerHTML = "<i class='fa-solid fa-triangle-exclamation'></i> Lütfen Shopier sipariş kodunuzu veya lisans numaranızı giriniz.";
    return;
  }

  msg.style.display = "block";
  msg.style.background = "rgba(0, 230, 118, 0.12)";
  msg.style.border = "1px solid rgba(0, 230, 118, 0.3)";
  msg.style.color = "#a7f3d0";
  msg.innerHTML = "<i class='fa-solid fa-circle-check'></i> <b>Lisans Onaylandı!</b> 1.89 GB resmi GitHub kurulum paketi indiriliyor...";

  setTimeout(() => {
    window.location.href = GITHUB_RELEASE_SETUP_URL;
  }, 900);
}

function checkUrlPurchaseParams() {
  const params = new URLSearchParams(window.location.search);
  if (params.get("purchased") === "true" || params.get("success") === "true" || params.get("order")) {
    const msg = document.getElementById("verifyMessage");
    const input = document.getElementById("orderInput");
    if (input && params.get("order")) input.value = params.get("order");
    if (msg) {
      msg.style.display = "block";
      msg.style.background = "rgba(0, 230, 118, 0.15)";
      msg.style.border = "1px solid rgba(0, 230, 118, 0.35)";
      msg.style.color = "#a7f3d0";
      msg.innerHTML = "🎉 <b>Ödemeniz Onaylandı!</b> Kurulum dosyanız (1.89 GB) birkaç saniye içinde otomatik olarak inmeye başlayacaktır...";
    }
    setTimeout(() => {
      window.location.href = GITHUB_RELEASE_SETUP_URL;
    }, 1800);
  }
}
