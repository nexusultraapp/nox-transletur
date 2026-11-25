(() => {
  const video = document.getElementById('hdmiVideo');
  const subtitle = document.getElementById('subtitleText');
  const debugHud = document.getElementById('debugHud');
  const missionOverlay = document.getElementById('missionOverlay');
  const missionText = document.getElementById('missionText');
  const phoneOverlay = document.getElementById('phoneOverlay');
  const phoneText = document.getElementById('phoneText');
  const regionTimers = { Mission: null, Phone: null };

  function fitRegionText(box, textEl) {
    if (!box || !textEl) return;
    const maxH = Math.max(20, box.clientHeight - 14);
    const maxW = Math.max(40, box.clientWidth - 20);
    let fontSize = Math.max(14, Math.min(28, Math.round(maxH * 0.34)));
    textEl.style.fontSize = `${fontSize}px`;
    while (fontSize > 11 && (textEl.scrollHeight > maxH || textEl.scrollWidth > maxW)) {
      fontSize -= 1;
      textEl.style.fontSize = `${fontSize}px`;
    }
  }

  function handleRegionPacket(packet) {
    const isPhone = packet.region === 'Phone';
    const box = isPhone ? phoneOverlay : missionOverlay;
    const textEl = isPhone ? phoneText : missionText;
    const key = isPhone ? 'Phone' : 'Mission';
    if (!box || !textEl) return;

    clearTimeout(regionTimers[key]);

    if (packet.clear || !packet.text || !packet.text.trim()) {
      textEl.textContent = '';
      box.style.display = 'none';
      return;
    }

    const x = Math.max(0.0, Math.min(0.92, Number(packet.x) || 0.03));
    const y = Math.max(0.0, Math.min(0.92, Number(packet.y) || 0.08));
    const w = Math.max(0.08, Math.min(1.0 - x, Number(packet.width) || 0.30));
    const h = Math.max(0.05, Math.min(1.0 - y, Number(packet.height) || 0.14));

    box.style.left = `${(x * 100).toFixed(2)}%`;
    box.style.top = `${(y * 100).toFixed(2)}%`;
    box.style.width = `${(w * 100).toFixed(2)}%`;
    box.style.height = `${(h * 100).toFixed(2)}%`;

    if (packet.hideOriginal === false) {
      box.classList.add('transparent-mode');
    } else {
      box.classList.remove('transparent-mode');
    }

    const text = packet.text.trim();
    textEl.textContent = text;
    box.style.display = 'flex';
    fitRegionText(box, textEl);
    updateDebug(`${key}: "${text}"`);

    regionTimers[key] = setTimeout(() => {
      if (textEl.textContent === text) {
        textEl.textContent = '';
        box.style.display = 'none';
      }
    }, 12000);
  }

  let config = {
    pcIp: '192.168.1.101',
    port: 8765,
    hdmiInput: 1,
    subtitleDurationMs: 3500,
    fontSize: '38px',
    bottomPercent: '7%'
  };

  let socket = null;
  let clearTimer = null;
  let isDebugVisible = false;
  let reconnectTimer = null;
  let lastReceivedText = '';

  function updateDebug(msg) {
    if (debugHud) {
      debugHud.textContent = `[NOXIR TV] ${msg}`;
    }
    console.log(`[NOXIR TV] ${msg}`);
  }

  let currentBottomPercent = 7;
  let hudTimeout = null;

  function showBriefHud(msg) {
    if (debugHud) {
      debugHud.textContent = `[NOXIR TV] ${msg}`;
      debugHud.style.display = 'block';
      clearTimeout(hudTimeout);
      hudTimeout = setTimeout(() => {
        if (!isDebugVisible) debugHud.style.display = 'none';
      }, 2500);
    }
  }

  function applyBottomPosition(pct) {
    currentBottomPercent = Math.max(2, Math.min(30, pct));
    const overlay = document.getElementById('subtitleOverlay');
    if (overlay) {
      overlay.style.bottom = `${currentBottomPercent}%`;
    }
    try {
      localStorage.setItem('noxir_bottom_pct', currentBottomPercent.toString());
    } catch {}
  }

  // 1. Ayarları config.json veya localStorage üzerinden yükle
  async function loadConfig() {
    try {
      const resp = await fetch('config.json');
      if (resp.ok) {
        const json = await resp.json();
        config = Object.assign(config, json);
      }
    } catch (e) {
      console.warn('config.json okunamadı, varsayılanlar devrede:', e);
    }

    if (config.fontSize) subtitle.style.fontSize = config.fontSize;

    try {
      const urlParams = new URLSearchParams(window.location.search);
      const qIp = urlParams.get('pcIp') || urlParams.get('ip');
      if (qIp) {
        config.pcIp = qIp;
        localStorage.setItem('noxir_pc_ip', qIp);
      } else if (config.pcIp) {
        localStorage.setItem('noxir_pc_ip', config.pcIp);
      }
    } catch {}

    try {
      const savedPct = localStorage.getItem('noxir_bottom_pct');
      if (savedPct) {
        currentBottomPercent = parseInt(savedPct, 10);
      } else if (config.bottomPercent) {
        currentBottomPercent = parseInt(config.bottomPercent, 10) || 7;
      }
    } catch {
      currentBottomPercent = 7;
    }
    applyBottomPosition(currentBottomPercent);
  }

  // 2. HDMI video kaynağını başlat
  function initHdmiVideo() {
    if (!video) return;
    try {
      video.play().catch((err) => {
        console.warn('Otomatik oynatma kısıtlandı veya kullanıcı etkileşimi bekleniyor:', err);
      });
    } catch (e) {
      console.error('HDMI video başlatma istisnası:', e);
    }
  }

  // 3. PC WebSocket Altyazı Bağlantısı
  function connectWebSocket() {
    if (socket && (socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING)) {
      return;
    }

    clearTimeout(reconnectTimer);
    const wsUrl = `ws://${config.pcIp}:${config.port}/api/captions`;
    updateDebug(`PC'ye bağlanılıyor: ${wsUrl}...`);

    try {
      socket = new WebSocket(wsUrl);

      socket.addEventListener('open', () => {
        updateDebug(`PC Bağlandı (${config.pcIp}:${config.port}) · Altyazı dinleniyor`);
      });

      socket.addEventListener('message', (event) => {
        let packet;
        try {
          packet = JSON.parse(event.data);
        } catch {
          return;
        }

        if (packet.type === 'region') {
          handleRegionPacket(packet);
          return;
        }

        if (packet.type === 'clear' || !packet.text) {
          subtitle.textContent = '';
          subtitle.style.display = 'none';
          lastReceivedText = '';
          clearTimeout(clearTimer);
          return;
        }

        if (packet.bottomPercent !== undefined && packet.bottomPercent !== null) {
          applyBottomPosition(packet.bottomPercent);
        }

        // Altyazı metin rengi siyah (#000000) olarak sabit
        subtitle.style.color = '#000000';

        if (packet.fontSize) {
          const tvFontSize = Math.round(packet.fontSize * 1.5);
          subtitle.style.fontSize = `${tvFontSize}px`;
        }

        if (packet.outline !== undefined) {
          if (packet.outline) {
            subtitle.style.textShadow = '0 0 6px #fff, 0 0 10px #fff, 1px 1px 2px #fff, -1px -1px 2px #fff';
            subtitle.style.webkitTextStroke = '0px';
          } else {
            subtitle.style.textShadow = 'none';
            subtitle.style.webkitTextStroke = '0px';
          }
        }

        if (packet.bg !== undefined) {
          if (packet.bg) {
            subtitle.style.backgroundColor = 'rgba(255, 255, 255, 0.92)';
            subtitle.style.padding = '8px 18px';
            subtitle.style.borderRadius = '8px';
          } else {
            subtitle.style.backgroundColor = 'transparent';
            subtitle.style.padding = '2px 8px';
          }
        }

        if (packet.hideOriginal !== undefined) {
          if (packet.hideOriginal) {
            subtitle.classList.add('hide-original');
          } else {
            subtitle.classList.remove('hide-original');
          }
        }

        const text = packet.text.trim();
        if (text) {
          subtitle.textContent = text;
          subtitle.style.display = 'inline-block';
          lastReceivedText = text;
          updateDebug(`Altyazı: "${text}"`);

          clearTimeout(clearTimer);
          const duration = packet.durationMs || config.subtitleDurationMs || 6500;
          clearTimer = setTimeout(() => {
            if (subtitle.textContent === text) {
              subtitle.textContent = '';
              subtitle.style.display = 'none';
            }
          }, duration);
        }
      });

      socket.addEventListener('close', () => {
        updateDebug('PC bağlantısı kesildi. Yeniden bağlanılıyor...');
        scheduleReconnect();
      });

      socket.addEventListener('error', () => {
        scheduleReconnect();
      });
    } catch (err) {
      updateDebug(`Soket hatası: ${err.message}`);
      scheduleReconnect();
    }
  }

  function scheduleReconnect() {
    clearTimeout(reconnectTimer);
    reconnectTimer = setTimeout(() => {
      connectWebSocket();
    }, 3000);
  }

  // 4. Ekran Koruyucu Engelleme (Screen Saver Inhibitor)
  // LG webOS, kumandaya basılmadığında ekran koruyucu (fireworks / siyah ekran) başlatır.
  // Bu mekanizma üç katmanlı koruma ile ekran koruyucuyu tamamen engeller:
  // 1. W3C Screen Wake Lock API (webOS 6.0+, webOS 22/23/24)
  // 2. webOS tvpower Luna Service (registerScreenSaverRequest + ack: false veto)
  // 3. Görünürlük değiştiğinde uyanıklığı otomatik tazeleme
  let screensaverSubBridge = null;
  let screenWakeLock = null;

  function initScreenSaverPrevention() {
    // A) Modern webOS (Chromium tabanlı) W3C Screen Wake Lock
    async function requestWakeLock() {
      if ('wakeLock' in navigator && !screenWakeLock) {
        try {
          screenWakeLock = await navigator.wakeLock.request('screen');
          screenWakeLock.addEventListener('release', () => {
            screenWakeLock = null;
          });
          updateDebug('Screen WakeLock devrede (Ekran uyanık tutuluyor)');
        } catch (err) {
          console.warn('[NOXIR TV] WakeLock hatası:', err);
        }
      }
    }

    requestWakeLock();

    // B) webOS Luna Service Bus (Tüm webOS TV sürümleri)
    // Sistem ekran koruyucu başlatmak istediğinde bu istemciye sinyal gönderir.
    // 'ack: false' cevabı dönerek ekran koruyucunun devreye girmesi kesin olarak veto edilir.
    const BridgeClass = window.WebOSServiceBridge || window.PalmServiceBridge;
    if (typeof BridgeClass !== 'undefined') {
      try {
        screensaverSubBridge = new BridgeClass();
        screensaverSubBridge.onservicecallback = (msg) => {
          try {
            const data = JSON.parse(msg);
            if (data && data.state === 'Active' && data.timestamp) {
              updateDebug('webOS ekran koruyucu talebi yakalandı -> Engellendi (ack: false)');
              const respBridge = new BridgeClass();
              respBridge.call(
                'luna://com.webos.service.tvpower/power/responseScreenSaverRequest',
                JSON.stringify({
                  clientName: 'com.noxir.play.tv',
                  ack: false,
                  timestamp: data.timestamp
                })
              );
            }
          } catch (e) {
            console.error('[NOXIR TV] ScreenSaver yanıt hatası:', e);
          }
        };

        screensaverSubBridge.call(
          'luna://com.webos.service.tvpower/power/registerScreenSaverRequest',
          JSON.stringify({
            subscribe: true,
            clientName: 'com.noxir.play.tv'
          })
        );
        updateDebug('webOS tvpower ekran koruyucu engelleyici aktif');
      } catch (e) {
        console.warn('[NOXIR TV] WebOSServiceBridge başlatılamadı:', e);
      }
    }

    // C) TV ekranı veya giriş kaynağı değişip tekrar geldiğinde uyanıklığı tazele
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'visible') {
        requestWakeLock();
        if (video && video.paused) {
          video.play().catch(() => {});
        }
      }
    });
  }

  // 5. Kumanda Tuş Kontrolleri
  // - Mavi tuş (406) veya 'D': Durum / Debug HUD aç/kapat
  // - Yukarı ok (38) / Kanal Yukarı (33): Altyazı konumunu yukarı kaydır (+1%)
  // - Aşağı ok (40) / Kanal Aşağı (34): Altyazı konumunu aşağı kaydır (-1%)
  document.addEventListener('keydown', (e) => {
    // 406: LG webOS Blue button, 68: 'D' key
    if (e.keyCode === 406 || e.keyCode === 68) {
      isDebugVisible = !isDebugVisible;
      if (debugHud) {
        debugHud.style.display = isDebugVisible ? 'block' : 'none';
      }
    }
    // 38: Yukarı ok, 33: Kanal / Sayfa Yukarı
    else if (e.keyCode === 38 || e.keyCode === 33) {
      applyBottomPosition(currentBottomPercent + 1);
      showBriefHud(`Altyazı Konumu: %${currentBottomPercent} (Yukarı)`);
    }
    // 40: Aşağı ok, 34: Kanal / Sayfa Aşağı
    else if (e.keyCode === 40 || e.keyCode === 34) {
      applyBottomPosition(currentBottomPercent - 1);
      showBriefHud(`Altyazı Konumu: %${currentBottomPercent} (Aşağı)`);
    }
  });

  // Başlatma
  loadConfig().then(() => {
    initHdmiVideo();
    initScreenSaverPrevention();
    connectWebSocket();
    // Kalıcı siyah maske kaldırıldı. Ekran tamamen şeffaftır, yalnızca altyazı gelince metin görünür.
  });
})();
