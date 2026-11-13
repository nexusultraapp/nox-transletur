/**
 * NOXIR Play - Landing Page Script
 * PS5 Real-Time AI Translation & LG TV Subtitle Overlay
 */

// --- 1. GAME TAB SWITCHER ---
function switchGameTab(gameName) {
  const tabBtns = document.querySelectorAll(".game-tab-btn");
  const views = document.querySelectorAll(".game-showcase-view");

  tabBtns.forEach(btn => {
    btn.classList.toggle("active", btn.dataset.game === gameName);
  });

  views.forEach(view => {
    view.classList.toggle("active", view.id === "view-" + gameName);
  });
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
const SHOPIER_DEFAULT_URL = "https://www.shopier.com/ggplayyusuf/52873712";

function openShopierCheckout(e) {
  if (e && e.target && e.target.tagName === "A" && e.target.href && e.target.href.includes("shopier")) {
    return; // Native <a> tag navigates directly
  }
  window.open(SHOPIER_DEFAULT_URL, "_blank");
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
  initFAQ();

  // App UI tabs event listeners
  const appNavItems = document.querySelectorAll(".app-nav-item");
  appNavItems.forEach(item => {
    item.addEventListener("click", () => {
      switchAppTab(item.dataset.tab);
    });
  });

  // Game showcase tabs event listeners (God of War, The Last of Us, Cyberpunk)
  const gameTabBtns = document.querySelectorAll(".game-tab-btn");
  gameTabBtns.forEach(btn => {
    btn.addEventListener("click", () => {
      switchGameTab(btn.dataset.game);
    });
  });

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
const PRIVATE_SETUP_DOWNLOAD_URL = "https://www.shopier.com/ggplayyusuf/52873712";

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
  msg.innerHTML = "<i class='fa-solid fa-circle-check'></i> <b>Lisans Onaylandı!</b> Kurulum paketi indirme sayfasına yönlendiriliyorsunuz...";

  setTimeout(() => {
    window.location.href = PRIVATE_SETUP_DOWNLOAD_URL;
  }, 1000);
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
      msg.innerHTML = "🎉 <b>Ödemeniz Onaylandı!</b> Kurulum dosyanız birkaç saniye içinde açılacaktır...";
    }
    setTimeout(() => {
      window.location.href = PRIVATE_SETUP_DOWNLOAD_URL;
    }, 1800);
  }
}
