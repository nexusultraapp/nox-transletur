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
async function loadSiteVersionManifest() {
  try {
    const resp = await fetch(`version.json?t=${Date.now()}`, { cache: "no-store" });
    if (!resp.ok) return;
    const data = await resp.json();
    if (data && data.version) {
      const heroBadge = document.getElementById("heroVersionBadge");
      if (heroBadge) {
        heroBadge.innerHTML = `<i class="fa-solid fa-bolt"></i> Yeni Nesil Yapay Zeka Oyun Çevirisi · v${data.version}`;
      }

      const changelogTitle = document.getElementById("siteChangelogTitle");
      if (changelogTitle) {
        changelogTitle.textContent = `${data.title || "NOXIR Play v" + data.version} ile Bunlar Getirildi`;
      }

      const changelogMeta = document.getElementById("siteChangelogMeta");
      if (changelogMeta) {
        changelogMeta.textContent = `Sürüm: v${data.version}${data.releaseDate ? " · " + data.releaseDate : ""}`;
      }

      const changelogList = document.getElementById("siteChangelogList");
      if (changelogList && data.changelog) {
        const lines = data.changelog
          .split(/\r?\n/)
          .map(l => l.replace(/^[•\-\*]\s*/, "").trim())
          .filter(Boolean);
        if (lines.length > 0) {
          changelogList.innerHTML = "";
          lines.forEach(line => {
            const li = document.createElement("li");
            const icon = document.createElement("i");
            icon.className = "fa-solid fa-check";
            li.appendChild(icon);
            li.appendChild(document.createTextNode(" " + line));
            changelogList.appendChild(li);
          });
        }
      }
      const updateBtn = document.getElementById("siteUpdateDownloadBtn");
      if (updateBtn) {
        updateBtn.href = `updates/NOXIR_Play_Update_v${data.version}.exe`;
        updateBtn.innerHTML = `<i class="fa-solid fa-cloud-arrow-down"></i> Güncelleme İndir (v${data.version})`;
      }
    }
  } catch (_) {
    // Sessizce geç, varsayılan HTML metni görünmeye devam eder
  }
}

document.addEventListener("DOMContentLoaded", () => {
  initFAQ();
  loadSiteVersionManifest();

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
});
