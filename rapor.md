# NOXIR Play — Kapsamlı Proje İncelemesi ve Kaynak Kodu Raporu

> **İnceleme tarihi:** 11 Kasım 2026  
> **Proje kökü:** `C:\Users\00yus\OneDrive\Desktop\test`  
> **Kapsam:** Tüm kaynak dosyalar, proje/derleme betikleri, yapılandırmalar, yerel köprü kodu, Python AI köprüsü, LG webOS TV uygulaması, modeller ve çalışma ortamı.  
> **Yöntem:** Statik kod incelemesi, dosya/dizin envanteri, bağımlılık ve ortam kontrolü. Bu raporun sonunda, incelemeye konu metin tabanlı kaynak dosyaların tamamı yer alır.

---

## İçindekiler

1. [Yönetici Özeti](#1-yönetici-özeti)
2. [Proje Künyesi ve Teknoloji Yığını](#2-proje-künyesi-ve-teknoloji-yığını)
3. [Dizin Yapısı](#3-dizin-yapısı)
4. [Mimari ve Veri Akışları](#4-mimari-ve-veri-akışları)
5. [Bileşen Bazında İnceleme](#5-bileşen-bazında-inceleme)
6. [Yapılandırma ve Kalıcı Veriler](#6-yapılandırma-ve-kalıcı-veriler)
7. [Bağımlılıklar ve Ortam](#7-bağımlılıklar-ve-ortam)
8. [Güvenlik, Gizlilik ve Lisanslar](#8-güvenlik-gizlilik-ve-lisanslar)
9. [Bulgular ve Önceliklendirme](#9-bulgular-ve-önceliklendirme)
10. [README ile Kod Arasındaki Farklar](#10-readme-ile-kod-arasındaki-farklar)
11. [Derleme, Çalıştırma ve Yayınlama](#11-derleme-çalıştırma-ve-yayınlama)
12. [Test ve Doğrulama Durumu](#12-test-ve-doğrulama-durumu)
13. [Yol Haritası ve Öneriler](#13-yol-haritası-ve-öneriler)
14. [Ek: Tam Kaynak Kodlar](#14-ek-tam-kaynak-kodlar)

---

## 1. Yönetici Özeti

**NOXIR Play**, bir PlayStation 5 oyunundaki altyazıları ekran görüntüsünden okuyup Türkçeye çeviren ve çeviriyi LG webOS TV üzerinde gösteren bir prototip sistemdir. Proje üç ana parçadan oluşur:

1. **Windows WPF uygulaması** (`pc/NoxirPlay.PC`): PSN hesabıyla giriş, PS5 Remote Play eşleştirmesi, Chiaki-NG tabanlı video oturumu, FFmpeg ile HLS/önizleme üretimi, OCR ve çeviri hattı, yerel HTTP/WebSocket sunucusu.
2. **Python AI köprüsü** (`pc/NoxirPlay.PC/ai_bridge`): RapidOCR/EasyOCR ile metin tanıma, Opus-MT ve NLLB-200 ile yerel çeviri, Google Translate yedeği, oyun sözlüğü ve metin kalite kuralları.
3. **LG webOS TV uygulaması** (`tv/noxirplay-tv`): TV'de HDMI girişini tam ekran gösterir ve PC'den WebSocket ile gelen Türkçe altyazıları bir katman üzerinde çizer.

Kod tabanı, README'nin iddia ettiğinden **belirgin biçimde daha ileri** durumdadır: video oturumu, OCR, çeviri, altyazı yayını ve TV tarafı altyazı gösterimi kodlanmıştır. Buna karşılık sistem uçtan uca ürünleşmemiştir; en önemli sorunlar şunlardır:

- **TV uygulaması PC'nin HLS akışını kullanmıyor.** `index.html` doğrudan `ext://hdmi:1` kaynağını açıyor. Yani PS5 görüntüsü TV'ye HDMI kablosuyla gidiyor; PC yalnızca OCR için ikinci bir görüntü kopyası alıyor. Bu durum "capture card olmadan PS5 görüntüsünü ağdan TV'ye aktarma" hedefiyle çelişir.
- **Eşleştirme ve token altyapısı TV tarafında kullanılmıyor.** `/api/pair`, `/api/stream/{dosya}?token=...` ve `TvPaired` olayı PC'de mevcut; fakat TV uygulaması ne eşleşiyor ne de HLS istiyor. `/api/captions` WebSocket'i ise token doğrulaması yapmıyor.
- **Python AI köprüsü taşınabilir değil.** `server.py` içinde bu makineye özel `C:\Users\00yus\...` yolları var; model klasörleri çıktı dizinine kopyalanmıyor; `requirements.txt` yok; sistem Python'una ve kurulu paketlere bağımlı.
- **DeepL hata yolu yanlış.** İstek başarısız olduğunda `DeepLTranslateAsync` girdi metnini aynen döndürüyor; çağıran taraf bunu "başarılı çeviri" sanıp İngilizce metni TV'ye gönderiyor.
- **"Kurulumu yeniden yap" çeviri tercihlerini korumuyor.** Kayıt sırasında kırpma ve `HideOriginalText` alanları verilmediği için varsayılan değerlere sıfırlanıyor.
- **README güncel değil.** "Video oturumu ve altyazı çevirisi henüz uygulanmadı" deniyor; oysa ikisi de kodda var. Ayrıca README HLS tabanlı TV akışı anlatıyor, kod ise HDMI kullanıyor.
- **Lisans riski büyük.** Chiaki-NG AGPL-3.0-only-OpenSSL ile bağlanıyor; NLLB-200 modelinin lisansı depoda belgelenmemiş (yaygın olarak CC-BY-NC-4.0, yani ticari kullanım kısıtlı). Üst düzey bir `LICENSE` dosyası yok.

**Genel değerlendirme:** Proje, teknik olarak etkileyici bir Ar-Ge prototipi; fakat dağıtılabilir bir ürün olmadan önce taşınabilirlik, güvenlik, lisans, TV-PC entegrasyonu ve hata yönetimi konularında ciddi iyileştirmeler gerekiyor.

---

## 2. Proje Künyesi ve Teknoloji Yığını

| Katman | Teknoloji | Ayrıntı |
|---|---|---|
| PC arayüzü | C# / WPF / XAML | `net8.0-windows10.0.19041.0`, tek pencere, kod-arkası (code-behind) ağırlıklı |
| Gömülü tarayıcı | Microsoft WebView2 | PSN OAuth girişi, `1.0.3537.50` |
| Yerel sunucu | ASP.NET Core Minimal API | `Microsoft.AspNetCore.App` framework referansı, Kestrel, `0.0.0.0:8765` |
| WebSocket | ASP.NET Core WebSockets | `/api/captions`, altyazı yayını |
| Şifreleme | Windows DPAPI | `ProtectedData`, `CurrentUser` kapsamı |
| Yerel köprü | C / CMake / Chiaki-NG | `libnoxir-chiaki-bridge.dll`, PS5 kaydı ve H.264 oturumu |
| Video işleme | FFmpeg | H.264 pipe → HLS; ayrıca MJPEG önizleme |
| AI/OCR | Python 3.9+ | RapidOCR (ONNX Runtime), isteğe bağlı EasyOCR |
| Çeviri | CTranslate2 | Opus-MT `opus-mt-tc-big-en-tr` (int8), NLLB-200 distilled 600M (int8) |
| Çevrimiçi yedek | Google Translate | Resmî olmayan `translate_a/single` uç noktası |
| TV uygulaması | HTML/CSS/JavaScript | LG webOS web uygulaması, `ext://hdmi:1` + WebSocket |
| Paketleme | `ares-*` CLI | webOS IPK üretimi ve kurulumu |
| Ortam | Windows 10/11 x64 | .NET SDK 8.0.426 ve 10.0.401 kurulu; FFmpeg PATH'te |

**Ürün adı:** NOXIR Play. Arayüzde yer yer "PS5 Translate" de kullanılıyor; marka tutarlılığı yok.

---

## 3. Dizin Yapısı

Aşağıdaki ağaçta yalnızca kaynak, yapılandırma ve belge dosyaları gösterilmiştir. `bin`, `obj`, `.tools`, model ikilileri, DLL'ler ve görseller hariç tutulmuştur.

```text
test/
├─ Başlat.bat                         # PC uygulamasını derleyip başlatan betik
├─ NOXIRPlay.slnx                     # Yeni nesil .slnx çözüm dosyası
├─ README.md                          # Proje tanıtımı (kodla kısmen uyumsuz)
├─ rapor.md                           # Bu rapor
├─ test.mjpeg                         # Referanssız örnek MJPEG
├─ test_frame.jpg                     # Referanssız örnek kare
├─ .tools/                            # ~1.5 GB: MSYS2, Chiaki-NG kaynağı, derleme çıktıları
├─ electron-react-ts/
│  └─ package.json                    # Yalnızca iskelet; kaynak yok, entegre değil
├─ pc/
│  └─ NoxirPlay.PC/
│     ├─ NoxirPlay.PC.csproj          # Gerçek proje dosyası
│     ├─ p.csproj                     # Eski/çift proje; çözümde değil
│     ├─ App.xaml / App.xaml.cs       # Uygulama girişi, global hata yakalama
│     ├─ AssemblyInfo.cs              # WPF tema bilgisi
│     ├─ MainWindow.xaml              # Tüm arayüz (kurulum + ayarlar)
│     ├─ MainWindow.xaml.cs           # Ana iş mantığı, PSN OAuth, çeviri döngüsü
│     ├─ RemotePlayService.cs         # Native oturum + pipe + FFmpeg orkestrasyonu
│     ├─ FfmpegStreamService.cs       # H.264 → HLS; kullanılmayan ekran yakalama
│     ├─ PreviewFrameService.cs       # MJPEG önizleme + kare çözme + log
│     ├─ LocalLanServer.cs            # 8765: health, pair, HLS, captions WS
│     ├─ ChiakiPs5RegistrationService.cs # PS5 kaydı + DPAPI saklama
│     ├─ PsnRemotePlayAuthService.cs  # Ölü kod: alternatif PSN OAuth servisi
│     ├─ OcrService.cs                # Bitmap kırpma + JPEG + AI köprüsü çağrısı
│     ├─ AiBridgeService.cs           # Python süreç yönetimi + HTTP istemcisi
│     ├─ GoogleTranslateService.cs    # Google Translate HTTP istemcisi
│     ├─ TextQualityPipeline.cs       # OCR temizleme, yer tutucu, Türkçe imla
│     ├─ TranslationSettingsService.cs# DPAPI ile ayar saklama
│     ├─ ai_bridge/
│     │  ├─ server.py                 # OCR/çeviri HTTP sunucusu (tek iş parçacıklı)
│     │  ├─ word_segmenter.py         # Bitişik kelime ayırma (Viterbi)
│     │  └─ test_server.py            # Bağımlılık/model duman testi
│     ├─ models/
│     │  ├─ game_dictionary.json      # Oyun kalıpları ve terim düzeltmeleri
│     │  ├─ opus-mt-en-tr/            # ~229.6 MB; CC-BY-4.0
│     │  └─ nllb-200-ct2-int8/        # ~681.4 MB; lisans dosyası yok
│     └─ native/
│        ├─ libnoxir-chiaki-bridge.dll# Önceden derlenmiş köprü (~2.31 MB)
│        ├─ *.dll                     # Chiaki/curl/OpenSSL/iconv vb. çalışma zamanı
│        ├─ chiaki-bridge/
│        │  ├─ CMakeLists.txt         # Chiaki-NG'ye karşı derleme
│        │  └─ noxir_chiaki_bridge.c  # Dışa aktarılan C fonksiyonları
│        └─ licenses/
│           ├─ NOTICE.md              # Chiaki-NG atfı
│           └─ Chiaki-NG-AGPL-3.0-only-OpenSSL.txt
└─ tv/
   ├─ Paketle.bat                     # IPK paketleme
   ├─ TV_Baglanti_Ayarla.bat          # webOS geliştirici cihazı tanımlama
   ├─ TVye_Yukle_ve_Baslat.bat        # IPK kurulumu + uygulama başlatma
   ├─ dist/                           # 0.1.0 ve 1.0.0 IPK çıktıları
   └─ noxirplay-tv/
      ├─ appinfo.json                 # webOS uygulama tanımı
      ├─ config.json                  # PC IP/port, altyazı süresi, font
      ├─ index.html                   # HDMI video + altyazı katmanı
      ├─ app.js                       # WebSocket, yeniden bağlanma, tuşlar
      ├─ style.css                    # Tam ekran video, maske, HUD
      └─ icon.png                     # Uygulama simgesi
```

**Boyut özeti:** Proje toplamı yaklaşık **2.58 GB**; bunun ~1.5 GB'ı `.tools`, ~911 MB'ı iki AI modeli, ~2.3 MB'ı yerel köprü DLL'idir.

---

## 4. Mimari ve Veri Akışları

### 4.1 Kurulum ve PS5 eşleştirme akışı

```text
Kullanıcı
  │
  ▼
WPF: WelcomeView → "İleri"
  │
  ▼
WebView2: Sony PSN OAuth sayfası
  │  (authorization code, redirect)
  ▼
MainWindow.GetPsnAccountIdAsync()
  │  1) code → access_token  (Basic auth: client_id + client_secret)
  │  2) access_token → user_id
  │  3) user_id → 8 bayt little-endian → Base64 AccountID
  ▼
ChiakiPs5RegistrationService.RegisterPs5Async(ip, 8 haneli kod, accountId)
  │
  ▼
libnoxir-chiaki-bridge.dll → noxir_register_ps5()
  │  Chiaki-NG registration API, 30 sn timeout
  ▼
RegisteredPs5 { IP, nickname, server MAC, registration key, RP key, tarih }
  │
  ▼
DPAPI (CurrentUser) → %LOCALAPPDATA%\NOXIR Play\ps5-registration.dat
```

**Notlar:**

- PSN parolası uygulama tarafından okunmaz; yalnızca Sony'nin sayfasında kullanılır.
- `client_id` ve `client_secret`, Chiaki-NG'de herkese açık olan Remote Play istemci değerleridir; kullanıcı sırrı değildir. Yine de kaynakta sabit tutulmaları ve kötüye kullanım riski belgelenmelidir.
- `PsnRemotePlayAuthService.cs` aynı işi daha düzenli biçimde (refresh token, katı redirect doğrulaması) yapar ancak **hiçbir yerden çağrılmaz**. Ana pencere kendi OAuth kodunu kullanır.

### 4.2 Video akışı

```text
PS5
  │  Remote Play / Chiaki-NG (H.264, 720p60)
  ▼
libnoxir-chiaki-bridge.dll
  │  stream_video_sample() → WriteFile
  ▼
Named pipe: \\.\pipe\noxirplay-remote-h264
  │
  ├─► FFmpeg #1: -f h264 -i pipe:0 -c:v copy -f hls
  │      └─ %LOCALAPPDATA%\NOXIR Play\stream\index.m3u8 + segment_*.ts
  │         └─ LocalLanServer /api/stream/{dosya}?token=...  (TV bunu KULLANMIYOR)
  │
  └─► FFmpeg #2: -f h264 -i pipe:0 -vf fps=60,scale=960:-2 -f image2pipe -c:v mjpeg
         └─ PreviewFrameService → JPEG kare çözme → BitmapSource
            ├─ WPF ayarlar ekranındaki canlı önizleme
            └─ OCR için _latestFrame
```

**Önemli:** TV uygulaması HLS akışını talep etmez. `index.html` içindeki `<video>` kaynağı `ext://hdmi:1`'dir. Dolayısıyla PS5'in HDMI çıkışı doğrudan TV'ye bağlı olmalıdır; PC'nin HLS çıktısı fiilen kullanılmaz. Bu, README'deki "PS5 → NOXIR Play PC → yerel HLS → LG webOS" zinciriyle çelişir.

### 4.3 OCR ve çeviri akışı

```text
WPF: "Çeviriyi Başlat"
  │
  ▼
RunLiveTranslationLoopAsync (100 ms aralık)
  │
  ├─ _latestFrame (frozen BitmapSource)
  ├─ Kullanıcının seçtiği kırpma dikdörtgeni
  ├─ OcrService → JPEG (kalite 90)
  ▼
POST http://127.0.0.1:18765/ocr
  │
  ▼
server.py: run_ocr()
  │  2× büyütme → ham / CLAHE / beyaz-sarı maske varyantları
  │  RapidOCR (text_score=0.48) veya EasyOCR
  │  fix_ocr_typos + speaker/dialog ayrıştırma
  ▼
OcrDetailedResult { text, raw_text, confidence, speaker, dialog, görsel }
  │
  ▼
TextQualityPipeline: CleanOcrNoise → FixOcrMergedWords → ShouldSkipTranslation
  │  Levenshtein benzerliği ≥ %80 ise tekrar çevirme
  ▼
Seçilen servise göre çeviri zinciri:
  Opus-MT → NLLB-200 → Google Translate
  veya NLLB → Opus → Google
  veya DeepL → Opus
  veya Google → Opus
  │
  ▼
TextQualityPipeline: UnshieldPlaceholders → PostProcessTurkish
  │
  ├─ WPF: LiveSubtitleText
  └─ WebSocket: /api/captions → TV altyazı katmanı
```

### 4.4 TV tarafı akışı

```text
LG webOS TV
  │
  ├─ <video src="ext://hdmi:1">  → PS5'in HDMI görüntüsü (PC'den bağımsız)
  │
  └─ WebSocket ws://<pcIp>:8765/api/captions
        │  JSON: { type: "caption"|"clear", text, hideOriginal }
        ▼
     subtitleText + mask-permanent / hide-original sınıfları
        │
        └─ 6.5 sn sonra otomatik temizleme (config.subtitleDurationMs)
```

TV uygulaması ayrıca:

- Mavi tuş (406) veya `D` ile debug HUD'u açar.
- Sarı tuş (405), `Y` veya `G` ile kalıcı siyah maskeyi açar/kapatır.
- Bağlantı koparsa 3 saniyede bir yeniden bağlanır.

### 4.5 Portlar ve uç noktalar

| Port | Bileşen | Dinleme adresi | Amaç |
|---|---|---|---|
| 8765 | `LocalLanServer` | `0.0.0.0` | Health, pairing, HLS, captions WebSocket |
| 18765 | `server.py` | `127.0.0.1` | OCR ve çeviri HTTP API |
| 9922 | webOS geliştirici modu | TV | `ares-*` SSH bağlantısı |

| Uç nokta | Yöntem | Kimlik doğrulama | Kullanım |
|---|---|---|---|
| `/api/health` | GET | Yok | Servis ve HLS hazırlık durumu |
| `/api/pair` | POST | 6 haneli kod, 10 dk, IP başına 8 deneme/dk | Token + adres + port |
| `/api/stream/{dosya}` | GET | `?token=` | HLS playlist/segment |
| `/api/captions` | WebSocket | **Yok** (token opsiyonel, doğrulanmıyor) | Altyazı yayını |
| `/health` (Python) | GET | Yok (yalnızca localhost) | Model hazırlık durumu |
| `/ocr` | POST | Yok (yalnızca localhost) | Görüntü → metin |
| `/translate` | POST | Yok (yalnızca localhost) | Metin → çeviri |

---

## 5. Bileşen Bazında İnceleme

### 5.1 Windows uygulaması — giriş ve ana pencere

#### `pc/NoxirPlay.PC/App.xaml` (9 satır)

Uygulama tanımı. `StartupUri="MainWindow.xaml"` ile ana pencereyi açar. Kaynak sözlüğü boştur.

#### `pc/NoxirPlay.PC/App.xaml.cs` (34 satır)

Global hata yakalama:

- `AppDomain.UnhandledException`: loglar ve mesaj kutusu gösterir.
- `DispatcherUnhandledException`: loglar, mesaj gösterir ve `Handled = true` yapar.
- `TaskScheduler.UnobservedTaskException`: loglar ve `SetObserved()` çağırır.

**Risk:** UI thread istisnalarının "handled" işaretlenmesi, uygulamayı tutarsız durumda bırakabilir. Ayrıca hata mesajlarında tam stack trace kullanıcıya gösterilir; son kullanıcı için uygun değildir.

#### `pc/NoxirPlay.PC/AssemblyInfo.cs` (9 satır)

Standart WPF `ThemeInfo` özniteliği. İşlevsel katkısı yok.

#### `pc/NoxirPlay.PC/MainWindow.xaml` (412 satır)

Tek pencerede dört görünüm:

1. **`HomeView`**: "PS5 görüntüsünü başlat" düğmesi, PS5 durum kartı, çeviri ayarları düğmesi.
2. **`TranslationSettingsView`**: OCR motoru, çeviri servisi, DeepL API anahtarı, kaynak/hedef dil, canlı önizleme, kırpma çerçevesi, dikey konum/yükseklik kaydırıcıları, "orijinali gizle" onay kutusu, canlı altyazı kutusu, "Çeviriyi Başlat/Durdur", "Ayarları kaydet", "Kurulumu yeniden yap".
3. **`WelcomeView`**: karşılama ve "İleri".
4. **`PsnConnectView`**: solda açıklama/durum, sağda WebView2.
5. **`Ps5ConnectView`**: PS5 IP ve 8 haneli kod, durum, eşleştir/ileri/geri.

**Tasarım notları:**

- Koyu tema, mor (`#8567F5`) vurgu, yuvarlatılmış paneller.
- Özel `PrimaryButton`, `SecondaryButton`, `FieldBox`, `SegmentButton` stilleri.
- `FieldBox` içinde `Tag` ile placeholder metni gösterilir.
- Kırpma çerçevesi `Canvas` üzerinde `Border` olarak çizilir; yalnızca dikey sürükleme desteklenir.
- XAML'daki OCR/seçenek metinleri ile C# varsayılan metinleri birebir aynı değildir; `SelectComboItem` eşleşmezse ilk öğeye düşer.

**Eksikler:**

- Kırpma alanının **genişliği ve X konumu** için kullanıcı kontrolü yok; yalnızca Y ve yükseklik değiştirilebilir.
- "Orijinal İngilizce altyazıyı gizle" seçeneği TV tarafında gerçekten uygulanmıyor (bkz. `style.css` ve `app.js`).
- TV IP'si / eşleştirme kodu için TV uygulamasında giriş alanı yok.

#### `pc/NoxirPlay.PC/MainWindow.xaml.cs` (1.129 satır)

Uygulamanın en büyük ve en kritik dosyası. Sorumlulukları:

**a) PSN OAuth**

- `PsnLoginUrl` sabiti ile Sony OAuth sayfası oluşturulur.
- `InitializePsnWebViewAsync()` WebView2 profilini `%LOCALAPPDATA%\NOXIR Play\WebView2` altında oluşturur.
- `NavigationStarting` içinde redirect URL'i `StartsWith(PsnRedirectPrefix)` ile yakalanır, `args.Cancel = true` yapılır ve `code` alınır.
- `GetPsnAccountIdAsync(code)`:
  - Basic auth ile `POST /2.0/oauth/token` → `access_token`.
  - `GET /2.0/oauth/token/{access_token}` → `user_id`.
  - `user_id` → 8 bayt little-endian → Base64 AccountID.
- `CompletePsnLoginAsync` başarılıysa PS5 ekranına geçer.

**Sorunlar:**

- `StartsWith` ile redirect doğrulaması, `.../redirectevil` gibi bir yolu da kabul eder; host yine Sony olduğu için risk düşüktür, ancak `PsnRemotePlayAuthService.IsRemotePlayRedirect` daha katıdır ve kullanılmalıdır.
- `HttpClient` için timeout/cancellation yok; ağ takılırsa UI bekler.
- Hata durumunda kullanıcıya ham istisna mesajı gösterilir.

**b) PS5 eşleştirme**

- `VerifyPs5_Click`: IP ve 8 haneli kod doğrular, `_ps5Registration.RegisterPs5Async` çağırır.
- Başarıda `_registeredPs5` atanır, "İleri" düğmesi görünür olur.
- `ContinueAfterPairing_Click`: ana içeriği açar.

**c) Çeviri ayarları**

- `TranslationSettingsService.Load()` ile DPAPI'li ayarlar yüklenir.
- `SelectComboItem` ile combo kutuları doldurulur.
- `SaveTranslationSettings_Click`: tüm alanları (kırpma ve `HideOriginalText` dahil) kaydeder.
- `RestartSetup_Click`: **hatalı** biçimde yalnızca OCR/servis/dil/API anahtarını içeren yeni bir `TranslationSettings` oluşturur; kırpma ve `HideOriginalText` verilmez. Kayıt varsayılanlara döner.

**d) Canlı önizleme ve kırpma**

- `UpdateSubtitleRegionPreview(BitmapSource)` her kareyi `_latestFrame`'e yazar, ~24 FPS ile UI'ı günceller.
- `RenderPreviewFrame` yalnızca ayarlar görünümü açıkken çalışır.
- `CropYSlider_ValueChanged` / `CropHeightSlider_ValueChanged` değerleri yüzdeye çevirir ve taşmayı engeller.
- `CropBox_MouseDown/Move/Up` dikey sürükleme yapar.
- `UpdateCropBoxUI` çerçeveyi ve etiketleri günceller.

**e) Canlı çeviri döngüsü**

`RunLiveTranslationLoopAsync`:

1. `_latestFrame`'i alır; değilse dondurmaya çalışır.
2. Kırpma dikdörtgenini hesaplar.
3. `OcrService.RecognizeDetailedTextAsync` çağırır.
4. Metin varsa ve güven ≥ 0.35 ise:
   - `CleanOcrNoise`, `FixOcrMergedWords`, `ShouldSkipTranslation`.
   - Levenshtein benzerliği ≥ 0.80 ise atlar.
   - Konuşmacı/diyalog ayrıştırması.
   - `ShieldPlaceholders`.
   - Seçilen servise göre sıralı çeviri ve yedekler.
   - `UnshieldPlaceholders`, `PostProcessTurkish`.
   - Konuşmacı varsa başa ekler.
   - WPF'e yazar ve `BroadcastCaptionAsync` ile TV'ye gönderir.
5. 6 boş OCR sonrası TV'ye `clear` gönderir.
6. 100 ms bekler.

**Sorunlar:**

- OCR/AI servisi kapalıysa her 100 ms'de bir 4 saniyelik istek denenir; log ve CPU israfı olur, geri çekilme (backoff) yok.
- `CalculateSimilarity` her çağrıda `(n+1)×(m+1)` int matrisi ayırır; altyazılar kısa olduğu için pratikte sorun değil, ancak döngüde gereksiz tahsis yaratır.
- `DeepLTranslateAsync` hata durumunda `text` döndürür; çağıran `!string.IsNullOrWhiteSpace(translated)` kontrolü nedeniyle bunu başarı sanır.
- `DeepLTranslateAsync` kaynak dil göndermez; hedef dil eşlemesi yalnızca TR/EN/DE/FR/ES destekler, diğerleri TR'ye düşer.
- `AiBridgeService.TranslateAiAsync` 30 saniyelik CTS kullanır, ancak `HttpClient.Timeout` 15 saniyedir; fiilî üst sınır 15 saniyedir.
- `StopLiveTranslation` TV'ye `clear` göndermez; son altyazı TV'de 6.5 saniye kalır.
- Ayarlar canlı çeviri sırasında değiştirilirse yeni değerler ancak durdur/başlat ile uygulanır (bilinçli olabilir).

**f) Yaşam döngüsü**

- `Window_Closing`: kapanmayı iptal eder, canlı çeviriyi durdurur, `RemotePlayService.DisposeAsync`, `AiBridgeService.KillServer` çağırır, sonra `Close()` ile yeniden kapatır.
- `Window_Loaded`: AI köprüsünü hemen ısıtır (`Task.Run`), kayıtlı PS5'i yükler.

**Risk:** AI köprüsü, kullanıcı çeviriyi hiç kullanmasa bile uygulama açılışında ~1 GB model yüklemeye başlar. Yavaş disklerde açılış ve bellek kullanımı olumsuz etkilenir.

### 5.2 Windows uygulaması — video ve ağ

#### `pc/NoxirPlay.PC/RemotePlayService.cs` (309 satır)

Orkestrasyon sınıfı:

- `StartAsync(RegisteredPs5)`:
  1. FFmpeg'i bulur (`AppContext.BaseDirectory` veya PATH).
  2. Kayıt anahtarlarını Base64'ten çözer, 16 bayt olduğunu doğrular.
  3. `%LOCALAPPDATA%\NOXIR Play\stream` klasörünü belirler.
  4. Named pipe sunucusunu oluşturur.
  5. `LocalLanServer`'ı başlatır.
  6. `FfmpegStreamService.StartH264InputAsync` ile HLS FFmpeg'ini başlatır.
  7. `pipe.WaitForConnectionAsync` görevini başlatır.
  8. `NativeMethods.StartPs5Stream` çağırır.
  9. Başarıda native izleyiciyi, pipe pompasını ve MJPEG önizlemeyi başlatır.
- `MonitorNativeSessionAsync`: 750 ms'de bir `noxir_get_stream_error` okur; 30 saniye video gelmezse hata üretir; native hata varsa `StreamFaulted` yayınlar.
- `PumpPipeAsync`: pipe'tan 64 KB bloklar okur, FFmpeg stdin'e ve önizleme kuyruğuna yazar; ilk veride `RequestIdr` çağırır.
- `StopAsync`: native oturumu 8 saniye timeout ile durdurur, pipe'ı kapatır, pompayı bekler, önizleme/FFmpeg/LAN sunucusunu kapatır, 350 ms bekler.
- `NativeMethods`: `noxir_start_ps5_stream`, `noxir_stop_ps5_stream`, `noxir_get_stream_error`, `noxir_request_idr` P/Invoke tanımları.

**Olumlu:** Anahtarlar `CryptographicOperations.ZeroMemory` ile temizlenir; hata durumunda kaynaklar temizlenir; pipe hazır değilse native taraf bunu kalıcı hata saymaz.

**Riskler:**

- `chiaki_session_join` bloklanabilir; 8 saniyelik `Task.Run` timeout'u thread'i serbest bırakmaz, yalnızca beklemeyi bırakır. Süreç kapanışı asılı kalabilir.
- FFmpeg stdin yavaşlarsa pipe okuma da yavaşlar; native `WriteFile` bloklanabilir ve akış stall olabilir.
- HLS, TV kullanmasa bile sürekli üretilir; CPU/disk israfı ve gereksiz hata yüzeyi.

#### `pc/NoxirPlay.PC/FfmpegStreamService.cs` (126 satır)

İki mod:

1. **`StartH264InputAsync` (aktif):** `-f h264 -i pipe:0 -an -c:v copy -f hls -hls_time 1 -hls_list_size 4 ...`
2. **`StartAsync` (ölü kod):** `ddagrab` ile ekran yakalama + `h264_mf`; README'de bahsedilen yol. Hiçbir yerden çağrılmıyor.

`PrepareStreamFolder` klasördeki tüm dosyaları siler. `StopAsync` süreç ağacını öldürür.

**Not:** `-c:v copy` H.264 elementary stream'i HLS'e paketler; SPS/PPS'in akışta olması gerekir. Chiaki çıktısı genellikle bunu sağlar. `-fflags +genpts` zaman damgalarını üretir.

#### `pc/NoxirPlay.PC/PreviewFrameService.cs` (217 satır)

- FFmpeg'i MJPEG `image2pipe` olarak başlatır: 60 FPS, 960 px genişlik, `-q:v 5`.
- Sınırlı `Channel<byte[]>` (256, `DropWrite`) ile yazma kuyruğu.
- `ReadLoopAsync` 2 MB tamponda JPEG `FF D8 ... FF D9` çiftlerini arar, `JpegBitmapDecoder` ile çözer, `FrameReady` yayınlar.
- `Log` metodu `AppContext.BaseDirectory\preview.log` dosyasına yazar.

**Riskler:**

- Log dosyası sınırsız büyür; her kare/olay loglanır. Kurulum `Program Files` altındaysa yazma başarısız olur ve sessizce yutulur.
- Loglar tanınan altyazı metinlerini içerebilir (gizlilik).
- 2 MB'tan büyük JPEG kareleri düşer (960 px'de beklenmez).
- `TryWrite` her paket için kopya ayırır; yüksek FPS'de GC baskısı.

#### `pc/NoxirPlay.PC/LocalLanServer.cs` (203 satır)

ASP.NET Core minimal API:

- `UseUrls("http://0.0.0.0:8765")`.
- CORS: `Access-Control-Allow-Origin: *`, `GET,POST,OPTIONS`, `Content-Type`.
- `/api/health`: servis adı, `ready`, `streamReady` (index.m3u8 var mı).
- `/api/pair`: 6 haneli kod, 10 dakika, IP başına dakikada 8 deneme, sabit zamanlı karşılaştırma, tek kullanımlık, 32 bayt token.
- `/api/stream/{fileName}`: token doğrular; path traversal'ı `Path.GetFileName(fileName) != fileName` ile engeller; yalnızca `.m3u8` ve `.ts`; playlist içindeki segment yollarını token'lı hale getirir; `.ts` için range destekli dosya döner.
- `/api/captions`: WebSocket; **token doğrulamaz**; bağlantıyı sözlüğe ekler; gelen mesajları okur (yalnızca kapanışı bekler).
- `BroadcastCaptionAsync`: tüm açık soketlere JSON yayınlar.
- `FindLocalIpv4`: gateway'i olan Ethernet/Wi-Fi adaptöründen IPv4 seçer.

**Olumlu:** Pairing kodu sabit zamanlı karşılaştırılır; HLS path traversal ve uzantı kontrolü vardır; segment URL'leri token'lanır.

**Sorunlar:**

- `/api/captions` kimlik doğrulaması yok; LAN'daki herkes altyazıları dinleyebilir. Altyazılar düşük hassasiyetli olabilir, ancak yine de kullanıcı verisidir.
- CORS `*` ve `0.0.0.0` dinleme, LAN'daki herkese açık yüzeyi büyütür.
- Pairing kodu sunucu oluşturulduğunda üretilir ve 10 dakika sonra dolar; kullanıcı kodu gördükten sonra değil, akış başladıktan sonra saymaya başlar.
- Aynı token'la iki WebSocket bağlanırsa sözlükte ikincisi birinciyi ezer; birinci kapanınca yanlış kayıt silinebilir.
- `TvPaired` olayı hiçbir yerde abone değil.
- `LocalAddress` bulunamazsa Türkçe bir metin döner; bu metin URL'lerde kullanılmaz ama UI'da garip görünür.

#### `pc/NoxirPlay.PC/ChiakiPs5RegistrationService.cs` (185 satır)

- `RegisteredPs5` record'u: IP, nickname, server MAC, registration key, RP key tipi/değeri, kayıt tarihi.
- `RegisterPs5Async`: IP ve 8 haneli kod doğrular; AccountID'nin 8 bayt olduğunu kontrol eder; native `noxir_register_ps5` çağırır; sonucu DPAPI ile kaydeder.
- `LoadRegistration` / `ClearRegistration` / `SaveRegistration`.
- `SaveRegistration`: önce `.new` dosyasına yazar, sonra `File.Move(overwrite: true)` ile atomik değiştirir.

**Olumlu:** DPAPI `CurrentUser`; anahtarlar `finally` içinde sıfırlanır; hata mesajları kullanıcı dostudur.

**Not:** `LoadRegistration` DPAPI ve JSON hatalarını yutar ve `null` döner; bozuk kayıt sessizce "eşleştirilmemiş" sayılır.

#### `pc/NoxirPlay.PC/PsnRemotePlayAuthService.cs` (226 satır)

Tam bir PSN OAuth istemcisi:

- `CreateDeviceUid`, `CreateAuthorizationUri`.
- `CompleteLoginAsync`: redirect doğrular, code'u token'a çevirir, AccountID alır, DPAPI ile kaydeder.
- `RefreshAsync`: refresh token desteği.
- `IsRemotePlayRedirect`: şema, host ve path'i katı biçimde doğrular.
- `Load`, `Save`, `Dispose`.

**Durum:** **Ölü kod.** `MainWindow` bu sınıfı kullanmıyor; kendi OAuth mantığını tekrar ediyor. İki uygulama arasında tutarsızlık (refresh yok, redirect doğrulaması zayıf) buradan kaynaklanıyor.

#### `pc/NoxirPlay.PC/OcrService.cs` (99 satır)

- `ExtractJpegBytes`: `CroppedBitmap` + `JpegBitmapEncoder` (kalite 90).
- `SafeExtractImageBytes`: frozen bitmap'i doğrudan işler; değilse freeze etmeyi dener; olmazsa UI dispatcher'ında çalıştırır.
- `RecognizeDetailedTextAsync`: motor seçimini (`Easy` → `easyocr`, aksi halde `rapid`) AI köprüsüne iletir; sonucu loglar.
- `RecognizeTextAsync`: yalnızca metin döndüren sarmalayıcı.

**Not:** `languageHint` parametresi alınır ama kullanılmaz; OCR motoru dil ipucunu desteklemiyor.

#### `pc/NoxirPlay.PC/AiBridgeService.cs` (367 satır)

- `EnsureBridgeRunningAsync`: `/health` kontrolü; gerekirse Python'u başlatır; 25 saniyeye kadar 500 ms aralıklarla bekler.
- `StartPythonServer`: `server.py` ve `python.exe` bulur; süreci gizli pencerede başlatır; stderr'i loglar; çıkışta `KillServer` bağlar.
- `FindPythonExe`: `%LOCALAPPDATA%\Programs\Python\Python313...39`, sonra klasör taraması, sonra `where python/python3/py`, en son `"python"`.
- `FindServerScript`: çıktı dizini, üst dizinler ve çalışma dizini adayları.
- `RecognizeRapidOcrDetailedAsync`: `/ocr` veya `/ocr?engine=easyocr`; 4 saniye timeout; JSON'u `OcrDetailedResult`'a çevirir.
- `TranslateAiAsync`: `/translate`; 30 saniye CTS; `translation` alanını döndürür.
- `RecognizeRapidOcrAsync(BitmapSource)`, `TranslateNllbAsync` sarmalayıcıları.
- `OcrDetailedResult` record'u.

**Sorunlar:**

- `FindPythonExe` son çare olarak `"python"` döndürür; Windows'ta Microsoft Store alias'ı gerçek Python değildir ve süreç başlatılamaz. Bu makinede tam olarak bu durum gözlemlendi.
- `HttpClient.Timeout = 15 sn`, çeviri CTS'si 30 sn; fiilî sınır 15 sn.
- Python stdout'u yönlendirilir ama okunmaz; yeterince çıktı üretilirse boru dolabilir.
- `/health` 200 döndüğü anda "hazır" kabul edilir; oysa modeller arka planda yükleniyor olabilir. İlk OCR isteği başarısız olabilir.
- `FindServerScript` çıktı dizininde `ai_bridge` var, ancak `models` klasörü kopyalanmadığı için model yolları üretimde bulunamaz.

#### `pc/NoxirPlay.PC/GoogleTranslateService.cs` (193 satır)

- Dil adlarını ISO kodlarına çevirir.
- `gtx` → `gt4` → `translate.google.com` alternatif uç noktası sırasıyla dener.
- 10 saniyelik timeout, gzip/deflate/brotli otomatik açma, JSON ayrıştırma.
- Hataları loglar ve boş string döndürür.

**Not:** Resmî olmayan uç nokta; değişebilir, hız sınırına takılabilir ve kullanım koşulları belirsizdir. Yedek olarak makul, birincil yol olmamalı.

#### `pc/NoxirPlay.PC/TextQualityPipeline.cs` (282 satır)

Yedi aşamalı metin kalite hattı:

1. `CleanOcrNoise`: CJK/geometrik parazitleri temizler, yapışık nokta/iki noktayı ayırır, tireli satır birleştirir, cümle ortası kırılımları boşluğa çevirir, çoklu boşlukları sadeleştirir.
2. `FixOcrMergedWords`: "usa" → "us a", "tothe" → "to the" gibi ~35 kural.
3. `ShouldSkipTranslation`: çok kısa, birim/skor, HUD komutu, tekrar eden karakter, sesli harfsiz, sembol yoğun, tek harfli kelime yığını gibi durumları eler.
4. `ShieldPlaceholders`: `{0}`, `%s`, HTML etiketi, `[Button]` gibi yer tutucuları `__PH_n__` ile korur.
5. `UnshieldPlaceholders`: çeviri sonrası geri koyar (model boşluk eklemiş olsa bile regex toleranslı).
6. `PostProcessTurkish`: baş/son kaçak sembolleri, noktalama boşluklarını, tırnakları düzeltir.
7. `FixTurkishCasing`: cümle başlarında Türkçe `İ/ı` kuralları.

**Olumlu:** Oyun altyazısı için düşünülmüş, test edilebilir saf fonksiyonlar. **Not:** C# ve Python tarafında benzer kurallar iki kez uygulanıyor; bakım yükü ve tutarsızlık riski var.

#### `pc/NoxirPlay.PC/TranslationSettingsService.cs` (70 satır)

- `TranslationSettings` record'u: OCR motoru, çeviri servisi, kaynak/hedef dil, API anahtarı, kırpma yüzdeleri, `HideOriginalText`.
- `Load` / `Save`: DPAPI `CurrentUser`, atomik `.new` + `Move`.
- `Defaults`: RapidOCR, Opus-MT, otomatik algıla, Türkçe, boş anahtar, `HideOriginalText = true`.
- Record varsayılan kırpma: `Y=0.78`, `H=0.14`, `X=0.10`, `W=0.80`.

**Tutarsızlık:** `MainWindow` alan başlangıçları `Y=0.70`, `H=0.25`, `X=0.05`, `W=0.90`; ayar dosyası yoksa record varsayılanları geçerli olur. XAML'daki kaydırıcılar ise 75/20 gösterir. Üç ayrı "varsayılan" değer var.

### 5.3 Python AI köprüsü

#### `pc/NoxirPlay.PC/ai_bridge/server.py` (821 satır)

Genel yapı:

- **Global modeller:** `rapid_ocr`, `opus_translator`, `sp_opus_src/tgt`, `ct2_translator`, `nllb_tokenizer`; her biri kendi kilidiyle korunur.
- **Model yolları:** `MODEL_DIRS` ve `OPUS_DIRS`; ilk üçü göreli, sonuncular **bu makineye özel mutlak yollar**.
- **Dil haritası:** Türkçe/İngilizce/Japonca/Korece/Çince/Almanca/Fransızca/İspanyolca/İtalyanca/Rusça; `map_lang` NFC normalizasyonu ve ASCII fallback yapar.
- **OCR:** `init_rapid_ocr` (`text_score=0.48`), `init_easy_ocr`, `run_easy_ocr`, `evaluate_variant`, `run_ocr`.
  - `run_ocr`: 2× büyütme; ham varyant; %75+ güven ve ≥2 kelime değilse CLAHE; skor < 0.65 ise beyaz/sarı HSV maskesi; Latin/CJK oranı ve güven eşiğiyle parazit eleme; PNG base64 çıktısı.
- **Oyun sözlüğü:** `DEFAULT_GAME_PHRASES` (~37 kalıp), `DEFAULT_GAME_TERMS` (~9 regex), `game_dictionary.json` yükleme/oluşturma, `apply_game_domain_post`.
- **Önbellek:** 5.000 girişli sözlük; taşınca ilk 1.000'i siler (gerçek LRU değil, FIFO benzeri).
- **Opus-MT:** `model.bin` > 10 MB olan klasörü seçer; `source.spm`/`target.spm`; CTranslate2 `int8`, 4-8 thread, `beam_size=1`.
- **NLLB-200:** `model.bin` > 100 MB; `AutoTokenizer`; CUDA varsa dener, yoksa CPU int8; `target_prefix=[[tgt_code]]`, `beam_size=1`.
- **Google:** `translate.googleapis.com` `gtx`/`gt4`, gzip açma, 8 sn timeout.
- **`do_translate`:** önbellek → oyun kalıbı → Opus (en→tr) → NLLB → Google.
- **HTTP:** `BaseHTTPRequestHandler`; `GET /health`, `POST /ocr`, `POST /translate`; JSON yanıt; log mesajları bastırılır.
- **Başlatma:** `_load_all` arka plan thread'inde RapidOCR + Opus + NLLB yükler; `HTTPServer` **tek iş parçacıklı** çalışır.

**Kritik sorunlar:**

- **Taşınabilirlik:** `r"C:\Users\00yus\OneDrive\Desktop\test\..."` ve `r"C:\Users\00yus\OneDrive\Desktop\NOXIRTranslate\..."` yolları. Başka makinede model bulunamaz.
- **Paketleme:** `NoxirPlay.PC.csproj` yalnızca `ai_bridge/**` kopyalar; `models/**` kopyalanmaz. Çıktı dizininde `models` olmadığı için göreli yollar da çalışmaz.
- **Tek iş parçacığı:** OCR/çeviri sürerken `/health` ve diğer istekler kuyruğa girer; C# tarafındaki 2 saniyelik health timeout'u yanlış "hazır değil" sonucu verebilir.
- **Eager yükleme:** Opus (~229 MB) ve NLLB (~681 MB) her zaman yüklenir; toplam bellek ~1 GB+. Kullanıcı yalnızca Google/DeepL seçse bile bu maliyet ödenir.
- **"Otomatik algıla" gerçek değil:** `map_lang("Otomatik algıla")` → `eng_Latn`; yani kaynak dil İngilizce varsayılır. Google yolunda da `en` gönderilir.
- **Sağlık yanılgısı:** `/health` model yüklenmeden de 200 döner; `rapidocr` alanı `false` olsa bile C# yalnızca HTTP 200'e bakar.
- **`init_game_dictionary()` import sırasında çalışır** ve dosya yoksa yazmaya çalışır; salt okunur kurulumda uyarı verir.
- **Hata yönetimi:** OCR/çeviri hataları 500 döner; C# boş sonuç üretir ve döngü devam eder.
- **Güvenlik:** Sunucu yalnızca `127.0.0.1` dinler; bu iyi. Ancak herhangi bir yerel süreç OCR/çeviri API'sini kullanabilir; kimlik doğrulama yok.

#### `pc/NoxirPlay.PC/ai_bridge/word_segmenter.py` (101 satır)

- ~200 İngilizce/oyun kelimesi ve frekansları.
- `split_concatenated_word`: Viterbi ile bitişik kelimeleri ayırır (`olddriver` → `old driver`).
- `segment_text`: 6+ harfli saf alfabetik kelimelere uygular.
- Bilinmeyen parçalar için uzunluğa bağlı ceza kullanır.

**Not:** Sözlük RDR2 temalı kişi/terimler içeriyor; genel oyunlar için sınırlı. Yalnızca İngilizce varsayımı var.

#### `pc/NoxirPlay.PC/ai_bridge/test_server.py` (102 satır)

Manuel duman testi:

- Python sürümü ve yolu.
- `rapidocr_onnxruntime`, `cv2`, `numpy`, `ctranslate2`, `sentencepiece`, `transformers` importları.
- Opus/NLLB `model.bin` varlık ve boyut kontrolü.
- Opus ile "Hello, how are you?" çeviri denemesi.
- Eksik paketler için `pip install` önerisi.

**Not:** `requirements.txt` yok; bu betik tek başına kurulumu yeniden üretemez.

### 5.4 Yerel köprü (C)

#### `pc/NoxirPlay.PC/native/chiaki-bridge/noxir_chiaki_bridge.c` (448 satır)

Dışa aktarılan fonksiyonlar:

| Fonksiyon | Amaç |
|---|---|
| `noxir_register_ps5` | Chiaki-NG ile PS5 kaydı; MAC, nickname, registration key, RP key döndürür |
| `noxir_start_ps5_stream` | 720p60 H.264 Remote Play oturumu başlatır |
| `noxir_stop_ps5_stream` | Oturumu durdurur, pipe'ı kapatır, join/fini yapar |
| `noxir_get_stream_error` | Hata durumunu ve mesajını döndürür |
| `noxir_request_idr` | Anahtar kare (IDR) ister |

**Kayıt akışı:**

- `ChiakiRegistInfo`: `CHIAKI_TARGET_PS5_1`, host, `psn_account_id`, 8 haneli `pin`.
- `chiaki_regist_start` + olay callback'i; 30 saniye `WaitForSingleObject`.
- Başarıda `registered_host` kopyalanır.

**Yayın akışı:**

- `ChiakiConnectInfo`: `ps5=true`, host, regist key, morning key, 720p60, H.264, `audio_video_disabled = CHIAKI_AUDIO_DISABLED`, `enable_idr_on_fec_failure=true`.
- Video sample callback'i pipe'a yazar; pipe yoksa `CreateFileA("\\\\.\\pipe\\noxirplay-remote-h264", ...)` ile bağlanır.
- Pipe bağlı değilse callback `true` döner (kalıcı hata değil); 30 saniye video gelmezse C# tarafı hata verir.
- `stream_cant_display`: HDCP/korumalı içerik hatası.
- `stream_event`: `CHIAKI_EVENT_QUIT` ve `STOPPED` dışı nedenlerde hata.

**Crash handler:**

- `AddVectoredExceptionHandler(1, native_exception_filter)` yalnızca erişim ihlali (AV) için `%LOCALAPPDATA%\NOXIR Play\native-crash.log` yazar.
- Modül, RVA, işlem, hedef adres ve dönüş adresi bilgisi toplar.
- `SetUnhandledExceptionFilter` bilinçli olarak kullanılmaz (CLR handler'ını bozmamak için).

**Riskler:**

- `stream_context` global ve tek oturum; eşzamanlı start/stop korunmuyor.
- `chiaki_lib_init()` her start'ta çağrılır, `chiaki_lib_deinit()` yok.
- Vectored exception handler hiç kaldırılmaz.
- `_snprintf` taşma durumunda null-terminate etmeyebilir; `strlen`/`strncat` taşma riski düşük ama mevcut.
- `noxir_stop_ps5_stream` içindeki `chiaki_session_join` bloklanabilir; C# timeout'u thread'i durdurmaz.
- Ses tamamen devre dışı; TV'ye ses aktarımı yok (HDMI kullanılıyorsa TV sesi doğrudan alır).

#### `pc/NoxirPlay.PC/native/chiaki-bridge/CMakeLists.txt` (39 satır)

- `CHIAKI_SOURCE_DIR` zorunlu.
- GUI/CLI/test/FFmpeg decoder/Pi decoder/setsu/SteamDeck/Opus/mbedTLS kapalı; sistem curl/nanopb/jerasure/json-c/miniupnpc açık.
- `add_subdirectory` ile Chiaki-NG'yi dahil eder.
- `noxir_chiaki_bridge` paylaşımlı kütüphanesini `chiaki-lib`e bağlar.
- Çıktı adı `noxir-chiaki-bridge`, hedef dizin `${CMAKE_BINARY_DIR}/out`, sonra `native/libnoxir-chiaki-bridge.dll`e kopyalar.

**Not:** `.tools/native-build.log` son derlemenin başarısız olduğunu gösteriyor; ancak `native/libnoxir-chiaki-bridge.dll` ve `.tools/chiaki-build/out/libnoxir-chiaki-bridge.dll` mevcut. Derleme tekrarlanabilirliği belirsiz.

### 5.5 LG webOS TV uygulaması

#### `tv/noxirplay-tv/appinfo.json` (17 satır)

- `id`: `com.noxir.play.tv`
- `version`: `1.0.0`
- `type`: `web`, `main`: `index.html`
- `resolution`: `1920x1080`
- `requiredPermissions`: `media.display`
- `handlesRelaunch`: `true`

#### `tv/noxirplay-tv/index.html` (25 satır)

- Tam ekran `<video id="hdmiVideo">`; kaynak `ext://hdmi:1`, tür `service/webos-external`.
- `subtitleOverlay` + `subtitleText` (`aria-live="polite"`).
- `debugHud`.
- `app.js` yüklenir.

**Kritik:** HLS veya PC akışı yok; doğrudan HDMI.

#### `tv/noxirplay-tv/app.js` (169 satır)

- Varsayılan config: `pcIp: 192.168.1.101`, `port: 8765`, `hdmiInput: 1`, `subtitleDurationMs: 6500`, `fontSize: 38px`, `bottomPercent: 7%`.
- `loadConfig`: `config.json` fetch eder, varsayılanlarla birleştirir; font ve alt konumu uygular.
- `initHdmiVideo`: `video.play()` dener; otomatik oynatma kısıtlamasını yakalar.
- `connectWebSocket`: `ws://<pcIp>:<port>/api/captions`; açık/bağlanıyor durumunda tekrar bağlanmaz.
- Mesaj: `clear` veya boş metin → temizle; `hideOriginal` → `hide-original` sınıfı; metin → göster, `durationMs` veya config süresi kadar sonra temizle.
- `close`/`error` → 3 saniye sonra yeniden bağlan.
- Tuşlar: 406/D debug; 405/Y/G kalıcı maske.
- Başlangıçta `mask-permanent` sınıfı eklenir.

**Sorunlar:**

- `hideOriginal` için CSS kuralı yok; sınıf eklenir ama görsel etkisi yoktur. PC'deki "orijinali gizle" seçeneği TV'de çalışmaz.
- `mask-permanent` varsayılan olarak açıktır; kullanıcı PC'de kapatsa bile TV açılışta kapatıcı bandı ekler.
- `pcIp` sabittir; TV'de ayar ekranı yoktur. Kullanıcı `config.json`u düzenleyip yeniden paketlemelidir.
- `hdmiInput` config'i hiç kullanılmaz; kaynak HTML'de sabittir.
- Token/pairing yok; WebSocket doğrudan açılır.
- `lastReceivedText` yalnızca atanır, karşılaştırmada kullanılmaz.
- TV ile PC arasında saat/yeniden bağlanma dışında sağlık kontrolü yok.

#### `tv/noxirplay-tv/style.css` (99 satır)

- Tam ekran video, siyah arka plan, `object-fit: contain`.
- Altyazı katmanı alt %5, `z-index: 10`, `pointer-events: none`.
- `mask-permanent`: opak siyah bant, gölge, min. 80 px.
- `subtitle-text`: 40 px, beyaz, kalın, çok katmanlı gölge, `pre-line`.
- Maske yokken metin varsa siyah arka plan; boşsa gizli.
- Debug HUD: sol üst, yarı saydam koyu, monospace, yeşil.

**Not:** `hide-original` sınıfı için kural yok; `mask-permanent` ile karışıklık var.

#### `tv/noxirplay-tv/config.json` (9 satır)

- `pcIp`: `192.168.1.101` (sabit).
- `port`: `8765`.
- `hdmiInput`: `1` (kullanılmıyor).
- `subtitleDurationMs`: `6500`.
- `fontSize`: `38px`.
- `bottomPercent`: `7%`.

### 5.6 Betikler ve yardımcı dosyalar

#### `Başlat.bat` (33 satır)

- Proje köküne geçer.
- `dotnet build pc\NoxirPlay.PC\NoxirPlay.PC.csproj`.
- `bin\Debug\net8.0-windows10.0.19041.0\NoxirPlay.PC.exe` yolunu çalıştırır.
- Sıfır olmayan çıkışta `%LOCALAPPDATA%\NOXIR Play\native-crash.log` varsa gösterir.

**Not:** Debug yolu sabit; `-c Release` veya farklı TFM ile çalışmaz. `dotnet` PATH'te olmalıdır.

#### `tv/Paketle.bat` (14 satır)

- `ares-package.cmd tv\noxirplay-tv -o tv\dist`.
- Başarıda `com.noxir.play.tv_1.0.0_all.ipk` oluştuğunu söyler.

#### `tv/TV_Baglanti_Ayarla.bat` (33 satır)

- TV IP ve passphrase ister.
- `ares-setup-device.cmd -m noxir-tv ...`; başarısızsa `-a` ile ekler.
- `ares-novacom.cmd --getkey` ve `ares-device.cmd -i` ile test eder.

#### `tv/TVye_Yukle_ve_Baslat.bat` (45 satır)

- IPK yoksa paketler.
- `ares-install.cmd -d noxir-tv` ile kurar.
- `ares-launch.cmd -d noxir-tv com.noxir.play.tv` ile başlatır.
- Bağlantı hatalarında kontrol listesi gösterir.

#### `electron-react-ts/package.json` (29 satır)

- `pc-app-example`, Electron 28 + React 18 + Zustand + Vite + TypeScript iskeleti.
- `main`, `dev`, `build`, `preview` betikleri tanımlı.
- Ancak `tsconfig.main.json`, `src/`, `vite.config.*`, `index.html` yok; `npm run dev` çalışmaz.
- Ana projeyle hiçbir entegrasyonu yok; büyük olasılıkla terk edilmiş bir başlangıç.

#### `README.md` (39 satır)

- Projenin amacını ve akışını anlatır.
- Bileşenleri ve "henüz tamamlanmayan işler"i listeler.
- Geliştirme ve webOS paketleme komutlarını verir.
- **Kodla uyumsuz:** video oturumu ve altyazı çevirisinin "henüz uygulanmadığını" söyler; TV'nin HLS kullandığını ima eder; `.slnx` için gereken SDK sürümünü ve ASP.NET Core runtime'ı belirtmez.

#### `NOXIRPlay.slnx` (5 satır)

- Yalnızca `pc/NoxirPlay.PC/NoxirPlay.PC.csproj` projesini içerir.
- `p.csproj` ve TV uygulaması çözümde değildir.

#### `pc/NoxirPlay.PC/NoxirPlay.PC.csproj` (23 satır)

- `WinExe`, `net8.0-windows10.0.19041.0`, nullable, implicit usings, WPF.
- `Microsoft.AspNetCore.App` framework referansı.
- `Microsoft.Web.WebView2 1.0.3537.50`.
- `System.Security.Cryptography.ProtectedData 8.0.0`.
- `native\*.dll` çıktı köküne kopyalanır.
- `native\licenses\**\*` kopyalanır.
- `ai_bridge\**` kopyalanır.
- **`models\**` kopyalanmaz.**

#### `pc/NoxirPlay.PC/p.csproj` (20 satır)

- Aynı ayarlar + `PaddleOCRSharp 6.2.0`.
- Aynı `AssemblyName` (`NoxirPlay.PC`).
- Çözümde değil; eski deneme. Aynı çıktı adı nedeniyle IDE/derleme karışıklığına yol açabilir.

#### `pc/NoxirPlay.PC/models/game_dictionary.json` (52 satır)

- `phrases`: 37 oyun diyalog kalıbı.
- `terms`: 9 Türkçe çeviri düzeltme regex'i.
- `server.py` bu dosyayı yükler; yoksa oluşturur.

#### `pc/NoxirPlay.PC/native/licenses/NOTICE.md` (8 satır)

- Chiaki-NG v1.10.1, commit `f30da0aaeb96fc0026cc03683153f682352e7d7c`.
- AGPL-3.0-only-OpenSSL.
- Sony tarafından onaylanmadığı notu.

---

## 6. Yapılandırma ve Kalıcı Veriler

| Veri | Konum | Koruma | İçerik |
|---|---|---|---|
| PS5 kaydı | `%LOCALAPPDATA%\NOXIR Play\ps5-registration.dat` | DPAPI `CurrentUser` | IP, nickname, MAC, registration key, RP key |
| Çeviri ayarları | `%LOCALAPPDATA%\NOXIR Play\translation-settings.dat` | DPAPI `CurrentUser` | Motor, dil, API anahtarı, kırpma, maske |
| PSN kimlik bilgileri (ölü kod) | `%LOCALAPPDATA%\NOXIR Play\psn-remote-play.dat` | DPAPI `CurrentUser` | Access/refresh token, AccountID, device UID |
| WebView2 profili | `%LOCALAPPDATA%\NOXIR Play\WebView2` | Windows kullanıcı profili | PSN oturum çerezleri |
| HLS çıktısı | `%LOCALAPPDATA%\NOXIR Play\stream` | Dosya sistemi | `index.m3u8`, `segment_*.ts` |
| Native çökme logu | `%LOCALAPPDATA%\NOXIR Play\native-crash.log` | Dosya sistemi | AV adresi, modül, RVA |
| Uygulama logu | `<uygulama dizini>\preview.log` | Dosya sistemi | Kare/pipe/OCR/çeviri olayları, tanınan metinler |
| TV yapılandırması | `tv/noxirplay-tv/config.json` | Paket içi | PC IP, port, süre, font |
| Oyun sözlüğü | `pc/NoxirPlay.PC/models/game_dictionary.json` | Paket içi | Kalıplar ve terimler |
| Modeller | `pc/NoxirPlay.PC/models/*` | Paket içi | Opus-MT, NLLB-200 |

**Öneriler:**

- `preview.log`u `%LOCALAPPDATA%\NOXIR Play\logs` altına taşıyın, boyut/rotation ekleyin ve altyazı metnini varsayılan olarak loglamayın.
- TV `config.json`u çalışma zamanında düzenlenebilir hale getirin (webOS storage veya ayar ekranı).
- Model klasörünü yayın paketine dahil edin veya ilk çalıştırmada indirme/seçme mekanizması ekleyin.

---

## 7. Bağımlılıklar ve Ortam

### 7.1 Doğrulanan ortam

| Bileşen | Durum |
|---|---|
| .NET SDK | **8.0.426** ve **10.0.401** kurulu (`C:\Program Files\dotnet\sdk`) |
| .NET Runtime | SDK ile birlikte; hedef `net8.0-windows10.0.19041.0` |
| ASP.NET Core Runtime | Framework referansı için gerekli; README'de belirtilmemiş |
| FFmpeg | PATH'te: `C:\Users\00yus\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg...\ffmpeg.exe` (9.0.2 full build) |
| `ares-package.cmd` | PATH'te: `C:\Users\00yus\AppData\Roaming\npm\ares-package.cmd` |
| Python | `python` komutu WindowsApps alias'ına düşüyor ve **çalışmıyor**; bu nedenle Python bağımlılık doğrulaması yapılamadı |
| Native DLL | `native/libnoxir-chiaki-bridge.dll` mevcut (~2.31 MB) |
| Chiaki derleme | `.tools/chiaki-build/out/libnoxir-chiaki-bridge.dll` mevcut; `.tools/native-build.log` son derlemede hata gösteriyor |

### 7.2 Python paketleri (kurulu olduğu varsayılan)

`server.py` ve `test_server.py` şunlara ihtiyaç duyar:

- `numpy`
- `opencv-python-headless` (`cv2`)
- `rapidocr_onnxruntime`
- `ctranslate2`
- `sentencepiece`
- `transformers`
- `easyocr` (isteğe bağlı; yoksa RapidOCR'a düşer)

**Eksik:** `requirements.txt`, sürüm sabitlemesi, sanal ortam kurulumu, otomatik kurulum betiği. Bu, yeni bir makinede kurulumu kırılgan hale getirir.

### 7.3 Model gereksinimleri

| Model | Boyut | Lisans | Not |
|---|---:|---|---|
| `opus-mt-tc-big-en-tr` (CTranslate2 int8) | ~229.6 MB | CC-BY-4.0 | `MODEL_LICENSE.txt` ve `manifest.json` mevcut; atıf gerekli |
| `nllb-200-distilled-600M` (CTranslate2 int8) | ~681.4 MB | Depoda lisans dosyası yok | Hugging Face model kartında CC-BY-NC-4.0 olarak bilinir; ticari kullanım riski doğrulanmalı |

### 7.4 Yerel DLL'ler

`native/` altında Chiaki-NG ve bağımlılıkları: `libcurl`, `libssl/libcrypto`, `libssh2`, `libevent`, `libnghttp2/3`, `libngtcp2`, `libidn2`, `libunistring`, `libiconv`, `libintl`, `libjson-c`, `libminiupnpc`, `libpsl`, `libbrotli*`, `libzstd`, `zlib1`, `libwinpthread`. Bunlar çıktı köküne kopyalanır.

**Risk:** DLL sürümleri ve kaynakları belgelenmemiş; lisans metinleri yalnızca Chiaki için var. curl/OpenSSL/iconv gibi bileşenlerin lisans bildirimleri eksik olabilir.

---

## 8. Güvenlik, Gizlilik ve Lisanslar

### 8.1 Olumlu yönler

- PS5 kayıt anahtarları ve çeviri ayarları **DPAPI CurrentUser** ile şifrelenir.
- Kayıt dosyaları atomik yazılır (`.new` + `Move`).
- Anahtarlar bellekte `CryptographicOperations.ZeroMemory` ile temizlenir.
- PSN parolası uygulama tarafından okunmaz/saklanmaz.
- HLS dosya sunumunda path traversal ve uzantı allowlist'i vardır.
- Pairing kodu sabit zamanlı karşılaştırılır; deneme sınırı vardır.
- Python AI sunucusu yalnızca `127.0.0.1` dinler.
- Native crash logu yalnızca AV durumunda ve sınırlı bilgiyle yazılır.

### 8.2 Riskler

| Risk | Önem | Açıklama |
|---|---|---|
| Kimlik doğrulamasız captions WebSocket | **Yüksek** | `/api/captions` token istemez; LAN'daki herkes altyazıları dinleyebilir. TV zaten tokensiz bağlanıyor. |
| CORS `*` + `0.0.0.0` | Orta | LAN'a açık HTTP yüzeyi; pairing/HLS dışındaki uç noktalar korunmasız. |
| Düz HTTP/WS | Orta | Altyazı ve eşleştirme trafiği şifresiz; LAN dinleyicisi görebilir. |
| Hardcoded mutlak yollar | Orta | `server.py` kişisel kullanıcı adı/yolunu sızdırır; taşınabilirliği bozar. |
| PSN client secret kaynakta | Düşük/Orta | Herkese açık Chiaki değeri; yine de kötüye kullanım ve marka riski. |
| Loglarda altyazı metni | Orta | `preview.log` tanınan metinleri içerir; gizlilik ve disk büyümesi. |
| AGPL yükümlülükleri | **Yüksek** | Chiaki-NG AGPL; dağıtımda kaynak sunma ve lisans uyumu gerekir. Üst düzey `LICENSE` yok. |
| NLLB lisansı | **Yüksek** | Ticari kullanım kısıtı olabilir; depoda lisans dosyası yok. |
| Üçüncü taraf DLL lisansları | Orta | curl/OpenSSL/iconv vb. bildirimleri eksik. |
| Rastgele port yok | Düşük | 8765 sabit; çakışma ve keşif kolaylığı. |
| Tek örnek koruması yok | Düşük | İki uygulama örneği 8765'te çakışır. |

### 8.3 Lisans değerlendirmesi

- **Chiaki-NG:** AGPL-3.0-only-OpenSSL. Bu, köprü DLL'sini kullanan dağıtılmış uygulamanın kaynak kodunun AGPL koşullarıyla sunulmasını gerektirebilir. `NOTICE.md` ve lisans metni var; ancak projenin kendi lisansı ve kaynak sunumu politikası yok.
- **Opus-MT:** CC-BY-4.0; atıf ve değişiklik bildirimi gerekir. `MODEL_LICENSE.txt` mevcut.
- **NLLB-200:** Model kartına göre CC-BY-NC-4.0 olabilir; ticari dağıtımda hukuki inceleme gerekir. Depoda lisans dosyası yok.
- **RapidOCR / ONNX Runtime / OpenCV / CTranslate2 / transformers:** Kendi lisansları (Apache/MIT/BSD vb.) ayrıca bildirilmelidir.
- **Sony/PlayStation:** Proje Sony tarafından onaylanmış değildir; README/NOTICE bunu belirtir. PSN OAuth istemci kimliklerinin kullanımı Sony koşullarına tabidir.

> Bu bölüm hukuki tavsiye değildir; dağıtımdan önce lisans uzmanına danışılmalıdır.

---

## 9. Bulgular ve Önceliklendirme

Aşağıdaki tablo, kod incelemesinde tespit edilen bulguları önem sırasına göre listeler.

| ID | Önem | Alan | Bulgu | Kanıt / Etki | Öneri |
|---|---|---|---|---|---|
| B-01 | **Kritik** | Ürün mimarisi | TV, PC HLS akışını kullanmıyor; `ext://hdmi:1` gösteriyor | `tv/noxirplay-tv/index.html:11-13`; PC'de HLS boşuna üretiliyor | HLS'i TV'ye bağla veya "HDMI + altyazı" modelini açıkça benimse; README'yi düzelt |
| B-02 | **Kritik** | Paketleme | `models/**` çıktıya kopyalanmıyor; `server.py` mutlak yollar kullanıyor | `NoxirPlay.PC.csproj:17-19`; `server.py:55-68` | Modelleri kopyala; yolları yapılandırılabilir yap; `requirements.txt` ekle |
| B-03 | **Kritik** | Güvenlik | `/api/captions` kimlik doğrulaması yok | `LocalLanServer.cs:127-150` | Token zorunlu kıl; TV'ye pairing akışı ekle; origin kontrolü |
| B-04 | **Kritik** | Lisans | AGPL ve NLLB lisans uyumu belirsiz | `NOTICE.md`; NLLB klasöründe lisans yok | Üst düzey LICENSE, kaynak sunumu, model lisanslarını ekle |
| B-05 | **Yüksek** | Çeviri | DeepL hatasında girdi metni dönüyor; başarı sanılıyor | `MainWindow.xaml.cs:1095-1104`, `936-937` | Hata durumunda boş/exception döndür; `usedEngine` yanlış işaretlenmesin |
| B-06 | **Yüksek** | Ayarlar | "Kurulumu yeniden yap" kırpma/maske ayarlarını sıfırlıyor | `MainWindow.xaml.cs:474-479` | Kayıtta tüm alanları koru veya mevcut `_translationSettings`i kullan |
| B-07 | **Yüksek** | AI | Python sunucusu tek iş parçacıklı; health/OCR/çeviri birbirini bloke eder | `server.py:807-817` | `ThreadingHTTPServer` veya ASGI; model kilidi + istek kuyruğu |
| B-08 | **Yüksek** | AI | `/health` modeller yüklenmeden 200 döner | `server.py:736-743`; `AiBridgeService.cs:60-72` | `ready` alanını model durumuna bağla; C# yanıtı kontrol etsin |
| B-09 | **Yüksek** | Performans | Opus + NLLB her zaman yükleniyor (~911 MB) | `server.py:800-805` | Tembel yükleme; seçilen motora göre yükle; bellek limiti |
| B-10 | **Yüksek** | UX | TV `pcIp` sabit; ayar ekranı yok | `config.json:2`; `app.js:29-45` | TV'de IP girişi veya keşif (mDNS) ekle |
| B-11 | **Yüksek** | UX | PC'deki "orijinali gizle" TV'de çalışmıyor | `app.js:91-97`; `style.css`'te `.hide-original` yok | CSS kuralı ekle veya `mask-permanent` ile eşle |
| B-12 | **Orta** | Dil | "Otomatik algıla" gerçek algılama yapmıyor; İngilizce varsayıyor | `server.py:80-81, 671-672` | Dil algılama ekle veya etiketi "İngilizce" yap |
| B-13 | **Orta** | Zaman aşımı | Çeviri 30 sn CTS, HttpClient 15 sn | `AiBridgeService.cs:12, 319` | Tek bir tutarlı timeout kullan |
| B-14 | **Orta** | Dayanıklılık | AI kapalıyken 100 ms'de bir 4 sn istek; backoff yok | `MainWindow.xaml.cs:786-1039` | Üstel geri çekilme, devre kesici |
| B-15 | **Orta** | Loglama | `preview.log` sınırsız ve altyazı içeriyor | `PreviewFrameService.cs:22-39` | Rotation, LocalAppData, metin maskeleme |
| B-16 | **Orta** | Eşleştirme | Kod, sunucu başladıktan 10 dk sonra doluyor | `LocalLanServer.cs:22-23` | Süreyi kod gösterildiğinde başlat |
| B-17 | **Orta** | Güvenlik | CORS `*`, HTTP düz metin | `LocalLanServer.cs:44-55` | Yalnızca TV origin'i; HTTPS/WSS veya oturum anahtarı |
| B-18 | **Orta** | Yapılandırma | Üç farklı kırpma varsayılanı | `MainWindow.xaml.cs:30-33`, `TranslationSettingsService.cs:13-16`, XAML 210/217 | Tek kaynak (settings record) kullan |
| B-19 | **Orta** | Yapı | `PsnRemotePlayAuthService` ölü kod | `PsnRemotePlayAuthService.cs` hiç çağrılmıyor | Ana pencereyi bu servise taşı veya sil |
| B-20 | **Orta** | Yapı | `p.csproj` çift proje, aynı assembly adı | `p.csproj` | Sil veya arşivle |
| B-21 | **Orta** | Yapı | `electron-react-ts` yarım iskelet | Yalnızca `package.json` | Tamamla veya kaldır |
| B-22 | **Orta** | Native | `chiaki_session_join` bloklanabilir; 8 sn timeout thread'i durdurmuyor | `RemotePlayService.cs:236-239`; C `342-343` | Ayrı süreç/iş parçacığı; iptal edilebilir kapatma |
| B-23 | **Düşük** | UI | Kırpma X/genişlik kontrolü yok | `MainWindow.xaml:199-219` | X/genişlik kaydırıcıları ekle |
| B-24 | **Düşük** | UI | Combo metinleri ile C# varsayılanları uyuşmuyor | XAML 129/140; C# 41-42; settings 64-65 | Tek sabit listesi kullan |
| B-25 | **Düşük** | TV | `hdmiInput` config'i kullanılmıyor | `app.js:9`; `index.html:12` | Kaynağı dinamik oluştur |
| B-26 | **Düşük** | TV | `lastReceivedText` kullanılmıyor | `app.js:19, 102` | Kaldır veya zamanlayıcıda kullan |
| B-27 | **Düşük** | Derleme | `.tools` 1.5 GB; native build logu başarısız | `.tools/native-build.log` | Temizle; tekrarlanabilir build betiği |
| B-28 | **Düşük** | README | Video/çeviri "yok" diyor; HLS anlatıyor | `README.md:11, 18-23` | Güncelle |
| B-29 | **Düşük** | README | .NET 8 Desktop Runtime yeterli değil | `README.md:27` | SDK, ASP.NET Core runtime, WebView2, Python ekle |
| B-30 | **Düşük** | Test | C# için otomatik test yok | — | Birim testleri: TextQualityPipeline, similarity, settings, HLS path |

### 9.1 En kritik beş bulgunun ayrıntısı

#### B-01 — TV ile PC arasındaki kopukluk

Kod, iki farklı ürün vizyonunu aynı anda taşıyor:

- **PC vizyonu:** PS5 → Chiaki → HLS → TV.
- **TV vizyonu:** PS5 → HDMI → TV; PC yalnızca altyazı gönderir.

TV uygulaması HLS'i hiç istemiyor. Bu nedenle:

- PC'de `FfmpegStreamService` ve `LocalLanServer` HLS kısmı boşuna çalışır.
- README'deki akış ve "capture card olmadan" iddiası yanlıştır.
- Eşleştirme kodu ve token altyapısı kullanılmaz.
- Kullanıcıya gösterilen "TV'de `<ip>:8765` ve kod ile bağlan" mesajı yanıltıcıdır.

**Karar gerekiyor:** Ya TV uygulaması HLS'i oynatacak (ve pairing/token akışı tamamlanacak), ya da HDMI modeli resmîleşecek ve HLS/eşleştirme kodu kaldırılacak. İkinci yol, "capture card'sız ağdan aktarım" hedefinden vazgeçmek anlamına gelir.

#### B-02 — Model paketleme ve taşınabilirlik

`NoxirPlay.PC.csproj` şunları kopyalar:

- `native\*.dll`
- `native\licenses\**\*`
- `ai_bridge\**`

Şunları kopyalamaz:

- `models\**`
- `ffmpeg.exe`
- Python bağımlılıkları

`server.py` göreli yolları denedikten sonra bu makineye özel mutlak yollara düşer. Başka bir makinede:

1. `ai_bridge/server.py` çalışır.
2. `MODEL_DIRS`/`OPUS_DIRS` göreli yolları bulamaz.
3. Mutlak yollar da bulunmaz.
4. `init_opus`/`init_nllb` başarısız olur; yalnızca Google yedeği kalır (internet varsa).

**Çözüm:** Modelleri yayın paketine dahil et veya ilk çalıştırmada indir; `models` yolunu `AppContext.BaseDirectory` üzerinden yapılandır; `requirements.txt` ve `setup.ps1` ekle; Python'u `py -3` ile başlat veya gömülü Python kullan.

#### B-03 — Captions WebSocket güvenliği

`/api/captions`:

```csharp
var token = context.Request.Query["token"].ToString();
var socketId = !string.IsNullOrWhiteSpace(token) ? token : ("direct_" + Guid.NewGuid().ToString("N"));
using var socket = await context.WebSockets.AcceptWebSocketAsync();
```

Token yalnızca sözlük anahtarı olarak kullanılıyor; `IsPaired` çağrılmıyor. TV de tokensiz bağlanıyor. Sonuç: LAN'daki herhangi bir tarayıcı/komut satırı altyazıları dinleyebilir.

**Çözüm:** `IsPaired(token)` zorunlu; TV'de pairing akışı; kısa ömürlü oturum token'ı; origin kontrolü; WSS.

#### B-05 — DeepL hata yolu

```csharp
if (!resp.IsSuccessStatusCode) return text;
...
catch { }
return text;
```

Çağıran:

```csharp
translated = await DeepLTranslateAsync(...);
if (!string.IsNullOrWhiteSpace(translated)) usedEngine = "DeepL API";
```

API 403/456/429 döndüğünde İngilizce metin "DeepL çevirisi" olarak TV'ye gider. **Çözüm:** Hata durumunda `string.Empty` döndür veya özel exception fırlat; `usedEngine` yalnızca gerçek çeviri varsa atansın.

#### B-06 — Ayar sıfırlama

```csharp
_translationSettingsService.Save(new TranslationSettings(
    OcrEngine: ...,
    TranslationService: ...,
    SourceLanguage: ...,
    TargetLanguage: ...,
    ApiKey: ...));
```

Record'un kalan parametreleri varsayılan: `CropY=0.78`, `CropHeight=0.14`, `CropX=0.10`, `CropWidth=0.80`, `HideOriginal=true`. Kullanıcının `%70/%25` veya kapalı maske ayarı kaybolur. **Çözüm:** Mevcut `_translationSettings`i `with` ile güncelle veya tüm alanları açıkça geçir.

---

## 10. README ile Kod Arasındaki Farklar

| README ifadesi | Kodda gerçek | Değerlendirme |
|---|---|---|
| "PS5 → NOXIR Play PC → yerel HLS akışı → LG webOS" | TV `ext://hdmi:1` kullanıyor; HLS tüketilmiyor | **Yanlış/eksik** |
| "Video oturumu ve altyazı çevirisi henüz uygulanmadı" | `RemotePlayService`, `server.py`, `RunLiveTranslationLoopAsync` mevcut | **Güncel değil** |
| "PS5 kayıt isteği Chiaki-NG C kayıt motoru üzerinden" | Doğru (`noxir_register_ps5`) | Doğru |
| "Başarılı cihaz kaydı DPAPI ile şifrelenir" | Doğru (`ProtectedData.CurrentUser`) | Doğru |
| "PC ekranını FFmpeg ile HLS'ye dönüştürme" | `FfmpegStreamService.StartAsync` (ddagrab) ölü kod; aktif yol H.264 pipe → HLS | Kısmen doğru |
| "TV eşleştirme kodu tek kullanımlık ve 10 dakika" | Kod var; TV kullanmıyor; süre sunucu başlangıcından | Kısmen doğru |
| "`.NET 8 Desktop Runtime` yeterli" | ASP.NET Core runtime, WebView2, FFmpeg, Python gerekli | **Eksik** |
| "`dotnet build NOXIRPlay.slnx`" | `.slnx` için SDK 9+ gerekir; .NET 8 SDK desteklemez | **Eksik** |
| "Oyun sesinin aktarımı yok" | Doğru; `CHIAKI_AUDIO_DISABLED` | Doğru |
| "Gerçek PS5/LG TV doğrulaması yok" | Muhtemelen doğru; depoda test kanıtı yok | Doğru |

---

## 11. Derleme, Çalıştırma ve Yayınlama

### 11.1 Ön koşullar

- Windows 10 2004+ / Windows 11 x64.
- **.NET SDK 9 veya 10** (`.slnx` için) veya doğrudan `.csproj` ile .NET 8 SDK.
- **ASP.NET Core Runtime 8** (framework-dependent yayın için).
- **WebView2 Evergreen Runtime** (Windows 11'de genellikle kurulu).
- **FFmpeg** PATH'te veya uygulama dizininde (`ffmpeg.exe`).
- **Python 3.9+** ve paketler (`requirements.txt` yok; elle kurulum).
- **Opus-MT ve NLLB modelleri** `models/` altında.
- webOS TV için `ares-*` CLI ve Developer Mode.

### 11.2 PC derleme

```powershell
# Çözümle (SDK 9+)
dotnet build NOXIRPlay.slnx

# veya doğrudan proje
dotnet build pc\NoxirPlay.PC\NoxirPlay.PC.csproj

# Release
dotnet build pc\NoxirPlay.PC\NoxirPlay.PC.csproj -c Release
```

Çalıştırma:

```powershell
pc\NoxirPlay.PC\bin\Debug\net8.0-windows10.0.19041.0\NoxirPlay.PC.exe
```

veya `Başlat.bat`.

### 11.3 Python AI köprüsü

```powershell
# Önerilen: sanal ortam
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install numpy opencv-python-headless rapidocr_onnxruntime ctranslate2 sentencepiece transformers
# isteğe bağlı: python -m pip install easyocr

# Duman testi
python pc\NoxirPlay.PC\ai_bridge\test_server.py

# Sunucuyu elle başlatma
python pc\NoxirPlay.PC\ai_bridge\server.py 18765
```

**Not:** Uygulama Python'u kendisi başlatır; elle başlatma yalnızca hata ayıklama içindir. `python` alias'ı bozuksa `py -3` kullanın veya `AiBridgeService.FindPythonExe`'yi iyileştirin.

### 11.4 TV paketleme ve kurulum

```powershell
# Cihaz tanımlama (bir kez)
tv\TV_Baglanti_Ayarla.bat

# Paketleme
tv\Paketle.bat
# veya
ares-package -o tv\dist tv\noxirplay-tv

# Kurulum ve başlatma
tv\TVye_Yukle_ve_Baslat.bat
```

**Önce** `tv/noxirplay-tv/config.json` içindeki `pcIp` değerini PC'nin LAN IP'sine ayarlayın. TV ve PC aynı ağda olmalıdır.

### 11.5 Yayınlama kontrol listesi

- [ ] `models/` çıktı paketine dahil edildi mi?
- [ ] `ffmpeg.exe` paketlendi mi veya PATH ön koşulu belgelendi mi?
- [ ] Python bağımlılıkları `requirements.txt` ile sabitlendi mi?
- [ ] ASP.NET Core Runtime ve WebView2 ön koşulları belgelendi mi?
- [ ] `LICENSE`, `NOTICE`, AGPL kaynak sunumu ve model lisansları eklendi mi?
- [ ] TV `pcIp` yapılandırması kullanıcı tarafından yapılabiliyor mu?
- [ ] `/api/captions` token doğrulaması açık mı?
- [ ] Log rotation ve LocalAppData yolu uygulandı mı?
- [ ] Tek örnek (single-instance) koruması var mı?
- [ ] Gerçek PS5 + LG TV ile uçtan uca test yapıldı mı?

---

## 12. Test ve Doğrulama Durumu

### 12.1 Bu incelemede doğrulananlar

- Tüm metin kaynak dosyaları okundu ve satır sayıları çıkarıldı.
- Proje ağacı, model boyutları, DLL'ler ve IPK'lar envanterlendi.
- .NET SDK sürümleri, FFmpeg ve `ares-package` varlığı kontrol edildi.
- `README`, `.slnx`, `.csproj` ve betiklerin kodla uyumu karşılaştırıldı.
- `server.py` model yolları, `/health`, OCR/çeviri akışı statik olarak izlendi.
- `LocalLanServer` uç noktaları ve kimlik doğrulama davranışı incelendi.
- `MainWindow` OAuth, eşleştirme, kırpma ve çeviri döngüsü satır satır izlendi.
- TV uygulamasının HLS yerine HDMI kullandığı doğrulandı.
- Native C köprüsünün dışa aktarımları ve hata yolları incelendi.

### 12.2 Doğrulanamayanlar

- **Gerçek PS5 ile eşleştirme ve video oturumu:** PS5 ve ağ ortamı yok.
- **LG TV üzerinde kurulum/çalıştırma:** TV ve `ares` cihaz bağlantısı yok.
- **Python bağımlılıkları:** `python` komutu bu makinede çalışmıyor (WindowsApps alias).
- **Uçtan uca OCR/çeviri:** AI sunucusu ve modeller bu incelemede çalıştırılmadı.
- **Native derleme:** `.tools/native-build.log` başarısız; önceden derlenmiş DLL var.
- **Performans ölçümleri:** FPS, gecikme, CPU/RAM ölçülmedi.

### 12.3 Mevcut testler

- `ai_bridge/test_server.py`: manuel bağımlılık/model testi.
- C# tarafında **otomatik test yok**.
- `TextQualityPipeline`, `CalculateSimilarity`, `TranslationSettingsService`, HLS path traversal ve pairing mantığı birim testine uygun; öncelikli test hedefleri bunlar olmalı.

### 12.4 Önerilen test matrisi

| Alan | Test |
|---|---|
| Metin kalitesi | `CleanOcrNoise`, `FixOcrMergedWords`, `ShouldSkipTranslation`, `PostProcessTurkish` için tablo tabanlı birim testleri |
| Benzerlik | Levenshtein eşikleri, boş/çok uzun metinler |
| Ayarlar | DPAPI round-trip, bozuk dosya, varsayılanlar, `RestartSetup` koruması |
| HLS | Path traversal, `.m3u8` token yeniden yazımı, eksik segment |
| Pairing | Süre, tek kullanım, 8 deneme limiti, sabit zamanlı karşılaştırma |
| WebSocket | Token zorunluluğu, çoklu istemci, kapanış temizliği |
| AI | `/health` model durumu, eşzamanlı OCR/çeviri, timeout |
| TV | HDMI kaynağı, yeniden bağlanma, maske, config yükleme |
| Uçtan uca | PS5 → PC → TV, 30 dakika kararlılık, bellek sızıntısı |

---

## 13. Yol Haritası ve Öneriler

### 13.1 P0 — Yayın öncesi zorunlu

1. **TV-PC mimarisini netleştir.**
   - Seçenek A: TV HLS oynatıcısı + pairing/token akışı.
   - Seçenek B: HDMI modelini resmîleştir; HLS/pairing kodunu kaldır veya "deneysel" olarak işaretle.
2. **Modelleri ve Python bağımlılıklarını paketle.**
   - `models/**` kopyala; `requirements.txt` ve kurulum betiği ekle; mutlak yolları kaldır.
3. **Captions WebSocket'ini koru.**
   - Token zorunlu, pairing akışı, origin kontrolü, WSS.
4. **Lisansları tamamla.**
   - Üst düzey `LICENSE`, AGPL kaynak sunumu, NLLB/Opus/OCR/DLL bildirimleri.
5. **DeepL ve ayar sıfırlama hatalarını düzelt.**

### 13.2 P1 — Kararlılık ve performans

6. Python sunucusunu çok iş parçacıklı/asenkron yap; model yüklemesini tembel ve seçilebilir hale getir.
7. `/health` yanıtını gerçek model hazırlığıyla ilişkilendir; C# tarafında kontrol et.
8. Çeviri/OCR için tutarlı timeout ve üstel geri çekilme uygula.
9. `preview.log`u LocalAppData'ya taşı, rotation ve metin maskeleme ekle.
10. Native kapatma yolunu iptal edilebilir hale getir; `chiaki_session_join` için ayrı süreç/iş parçacığı düşün.
11. Tek örnek koruması ve port çakışması yönetimi ekle.
12. TV'de IP/ayar ekranı veya mDNS keşfi ekle.

### 13.3 P2 — Ürünleşme

13. `PsnRemotePlayAuthService`i ana akışa taşı; refresh token ve katı redirect doğrulaması kullan.
14. `p.csproj` ve `electron-react-ts` gibi ölü/yarım bileşenleri temizle.
15. Kırpma alanına X/genişlik kontrolü ekle; varsayılanları tek kaynağa indir.
16. Combo metinlerini sabit listelerden üret; C#/XAML/Python dil listelerini eşitle.
17. Gerçek dil algılama (opsiyonel) veya "İngilizce" etiketi.
18. Oyun sözlüğünü genişlet; kullanıcı düzenleme arayüzü ekle.
19. Ses aktarımı için yol haritası belirle (şu an HDMI ile TV'ye gidiyor).
20. Otomatik testler ve CI ekle.

### 13.4 Kısa vadeli hızlı kazanımlar

- `RestartSetup_Click` düzeltmesi (5 dakika).
- `DeepLTranslateAsync` hata dönüşü (5 dakika).
- `/api/captions` token kontrolü (15 dakika; TV tarafında token'sız geçici uyumluluk için feature flag).
- `NoxirPlay.PC.csproj`e `models/**` kopyalama (5 dakika).
- `server.py` mutlak yollarını kaldırma (10 dakika).
- `preview.log` yolunu LocalAppData'ya alma (10 dakika).
- README'yi kodla eşleme (20 dakika).

---

## 14. Ek: Tam Kaynak Kodlar

Aşağıda, projedeki metin tabanlı kaynak ve yapılandırma dosyalarının tamamı yer alır. Hariç tutulanlar:

- `bin/`, `obj/`, `.tools/` (derleme çıktıları ve üçüncü taraf kaynak ağacı),
- model ikilileri (`model.bin`, `tokenizer.json`, `shared_vocabulary.*`, `.spm`),
- DLL'ler, IPK'lar, PNG/JPG/MJPEG,
- `native/licenses/Chiaki-NG-AGPL-3.0-only-OpenSSL.txt` (uzun lisans metni; dosya olarak depoda mevcut),
- Hugging Face `.cache` meta verileri.

Kod blokları, dosya yolları başlıklarıyla birlikte verilmiştir.


---

### 14.1 Ek Dosya Dizini

Aşağıdaki tablo, bu ekte tam metni verilen dosyaları ve satır sayılarını listeler.

| # | Dosya | Satır |
|---:|---|---:|
| 1 | `Başlat.bat` | 34 |
| 2 | `NOXIRPlay.slnx` | 6 |
| 3 | `README.md` | 40 |
| 4 | `pc/NoxirPlay.PC/AiBridgeService.cs` | 368 |
| 5 | `pc/NoxirPlay.PC/App.xaml` | 10 |
| 6 | `pc/NoxirPlay.PC/App.xaml.cs` | 35 |
| 7 | `pc/NoxirPlay.PC/AssemblyInfo.cs` | 11 |
| 8 | `pc/NoxirPlay.PC/ChiakiPs5RegistrationService.cs` | 186 |
| 9 | `pc/NoxirPlay.PC/FfmpegStreamService.cs` | 127 |
| 10 | `pc/NoxirPlay.PC/GoogleTranslateService.cs` | 194 |
| 11 | `pc/NoxirPlay.PC/LocalLanServer.cs` | 204 |
| 12 | `pc/NoxirPlay.PC/MainWindow.xaml` | 413 |
| 13 | `pc/NoxirPlay.PC/MainWindow.xaml.cs` | 1130 |
| 14 | `pc/NoxirPlay.PC/OcrService.cs` | 100 |
| 15 | `pc/NoxirPlay.PC/PreviewFrameService.cs` | 218 |
| 16 | `pc/NoxirPlay.PC/PsnRemotePlayAuthService.cs` | 227 |
| 17 | `pc/NoxirPlay.PC/RemotePlayService.cs` | 310 |
| 18 | `pc/NoxirPlay.PC/TextQualityPipeline.cs` | 283 |
| 19 | `pc/NoxirPlay.PC/TranslationSettingsService.cs` | 71 |
| 20 | `pc/NoxirPlay.PC/NoxirPlay.PC.csproj` | 24 |
| 21 | `pc/NoxirPlay.PC/p.csproj` | 21 |
| 22 | `pc/NoxirPlay.PC/ai_bridge/server.py` | 822 |
| 23 | `pc/NoxirPlay.PC/ai_bridge/test_server.py` | 103 |
| 24 | `pc/NoxirPlay.PC/ai_bridge/word_segmenter.py` | 102 |
| 25 | `pc/NoxirPlay.PC/models/game_dictionary.json` | 52 |
| 26 | `pc/NoxirPlay.PC/models/opus-mt-en-tr/config.json` | 11 |
| 27 | `pc/NoxirPlay.PC/models/opus-mt-en-tr/manifest.json` | 40 |
| 28 | `pc/NoxirPlay.PC/models/opus-mt-en-tr/MODEL_LICENSE.txt` | 23 |
| 29 | `pc/NoxirPlay.PC/models/nllb-200-ct2-int8/config.json` | 9 |
| 30 | `pc/NoxirPlay.PC/models/nllb-200-ct2-int8/special_tokens_map.json` | 220 |
| 31 | `pc/NoxirPlay.PC/models/nllb-200-ct2-int8/tokenizer_config.json` | 25 |
| 32 | `pc/NoxirPlay.PC/native/chiaki-bridge/CMakeLists.txt` | 40 |
| 33 | `pc/NoxirPlay.PC/native/chiaki-bridge/noxir_chiaki_bridge.c` | 449 |
| 34 | `pc/NoxirPlay.PC/native/licenses/NOTICE.md` | 9 |
| 35 | `tv/noxirplay-tv/app.js` | 170 |
| 36 | `tv/noxirplay-tv/appinfo.json` | 18 |
| 37 | `tv/noxirplay-tv/config.json` | 10 |
| 38 | `tv/noxirplay-tv/index.html` | 26 |
| 39 | `tv/noxirplay-tv/style.css` | 100 |
| 40 | `tv/Paketle.bat` | 15 |
| 41 | `tv/TV_Baglanti_Ayarla.bat` | 34 |
| 42 | `tv/TVye_Yukle_ve_Baslat.bat` | 46 |
| 43 | `electron-react-ts/package.json` | 29 |

### 14.2 Dosya İçerikleri

#### 1. `Başlat.bat`

```bat
@echo off
setlocal
cd /d "%~dp0"

set "PROJECT=pc\NoxirPlay.PC\NoxirPlay.PC.csproj"
set "APP_PATH=pc\NoxirPlay.PC\bin\Debug\net8.0-windows10.0.19041.0\NoxirPlay.PC.exe"

dotnet build "%PROJECT%"
if errorlevel 1 (
    echo.
    echo Derleme basarisiz oldu. Uygulama baslatilmadi.
    pause
    exit /b 1
)

if not exist "%APP_PATH%" (
    echo Derleme tamamlandi ancak uygulama dosyasi bulunamadi: %APP_PATH%
    pause
    exit /b 1
)

"%APP_PATH%"
set "APP_EXIT=%ERRORLEVEL%"
if not "%APP_EXIT%"=="0" (
    echo.
    echo NOXIR Play kapandi. Cikis kodu: %APP_EXIT%
    if exist "%LOCALAPPDATA%\NOXIR Play\native-crash.log" (
        echo Yerel hata ayrintisi:
        type "%LOCALAPPDATA%\NOXIR Play\native-crash.log"
    )
    pause
)
exit /b %APP_EXIT%
```

#### 2. `NOXIRPlay.slnx`

```xml
<Solution>
  <Folder Name="/pc/">
    <Project Path="pc/NoxirPlay.PC/NoxirPlay.PC.csproj" />
  </Folder>
</Solution>
```

#### 3. `README.md`

````markdown
# NOXIR Play

NOXIR Play, capture card kullanmadan PS5 görüntüsünü yerel ağ üzerinden LG webOS TV'ye aktarmayı hedefler.

## Akış

`PS5 → NOXIR Play PC → yerel HLS akışı → LG webOS uygulaması`

Windows uygulaması PSN Remote Play girişini uygulama içindeki WebView'da açar. Girişten alınan `user_id`, 8 bayt little-endian biçiminde AccountID'ye çevrilir. PSN parolası NOXIR tarafından okunmaz veya kaydedilmez. Giriş tamamlanınca uygulama doğrudan PS5 eşleştirme ekranına geçer; yalnızca PS5 IP adresi ve 8 haneli cihaz bağlama kodu istenir.

PS5 kayıt isteği, Chiaki-NG'nin C kayıt motoru üzerinden uygulama içinden gönderilir. Başarılı cihaz kaydı DPAPI ile bu Windows hesabına özel şifrelenir. Bu adım PS5'i Remote Play için eşleştirir; video oturumu ve altyazı çevirisi henüz uygulanmadı. Kullanılan Chiaki-NG bileşeni AGPL-3.0-only-OpenSSL lisanslıdır; lisans dosyası `pc/NoxirPlay.PC/native/licenses` içindedir. Chiaki-NG Sony tarafından onaylanmış veya sertifikalandırılmış değildir.

## Bileşenler

- `pc/NoxirPlay.PC`: Windows WPF arayüzü; uygulama içi PSN girişi ve Chiaki tabanlı PS5 eşleştirmesi, PC ekranını FFmpeg ile HLS'ye dönüştürme ve eşleştirilmiş TV'ye sunma.
- `tv/noxirplay-tv`: PC adresi ve TV kodu ile eşleşen webOS uygulaması; HLS görüntüsünü tam ekran açar ve altyazı katmanını görüntüler.

## Henüz tamamlanmayan işler

- PS5'le gerçek cihaz eşleştirmesini doğrulama ve Remote Play video oturumunu NOXIR penceresinde başlatma.
- Altyazı alanı seçimi, OCR, Türkçe çeviri, sözlük ve altyazı zamanlaması.
- Oyun sesinin PC'den TV'ye aktarımı.
- Gerçek PS5 ve LG TV üzerinde bağlantı doğrulaması.

## Geliştirme

Windows uygulaması için .NET 8 Desktop Runtime ve `ddagrab`, `h264_mf` ile HLS destekli FFmpeg gerekir. PS5 kayıt motoru ve çalışma zamanı kitaplıkları uygulamanın yanında taşınır.

```powershell
dotnet build NOXIRPlay.slnx
```

webOS paketi:

```powershell
ares-package -o tv\dist tv\noxirplay-tv
```

TV ve PC aynı yerel ağda olmalıdır. TV eşleştirme kodu tek kullanımlıktır ve 10 dakika geçerlidir. PC tarafındaki sunucu `8765` numaralı bağlantı noktasını kullanır.
````

#### 4. `pc/NoxirPlay.PC/AiBridgeService.cs`

```csharp
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Windows.Media.Imaging;

namespace NoxirPlay.PC;

internal static class AiBridgeService
{
    private static readonly HttpClient _httpClient = new() { Timeout = TimeSpan.FromSeconds(15) };
    private static Process? _pythonProcess;
    private static readonly SemaphoreSlim _initSemaphore = new(1, 1);
    private const int Port = 18765;
    private static readonly string BaseUrl = $"http://127.0.0.1:{Port}";

    public static async Task<bool> EnsureBridgeRunningAsync()
    {
        if (await IsHealthyAsync())
        {
            return true;
        }

        await _initSemaphore.WaitAsync();
        try
        {
            if (await IsHealthyAsync())
            {
                return true;
            }

            StartPythonServer();

            // AI sunucusunun ayağa kalkmasını 25 saniyeye kadar bekle
            for (int i = 0; i < 50; i++)
            {
                await Task.Delay(500);
                if (await IsHealthyAsync())
                {
                    PreviewFrameService.Log("NOXIR Play AI Servisi (RapidOCR & Opus-MT) hazır.");
                    return true;
                }
            }

            PreviewFrameService.Log("AI Servisi başlatılamadı veya zaman aşımına uğradı.");
            return false;
        }
        catch (Exception ex)
        {
            PreviewFrameService.Log("AI Servisi başlatma istisnası: " + ex.Message);
            return false;
        }
        finally
        {
            _initSemaphore.Release();
        }
    }

    private static async Task<bool> IsHealthyAsync()
    {
        try
        {
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(2));
            var resp = await _httpClient.GetAsync($"{BaseUrl}/health", cts.Token);
            return resp.IsSuccessStatusCode;
        }
        catch
        {
            return false;
        }
    }

    private static void StartPythonServer()
    {
        if (_pythonProcess is not null && !_pythonProcess.HasExited)
        {
            return;
        }

        var serverScript = FindServerScript();
        if (string.IsNullOrEmpty(serverScript) || !File.Exists(serverScript))
        {
            PreviewFrameService.Log("AI Köprü betiği server.py bulunamadı!");
            return;
        }

        var pythonExe = FindPythonExe();
        var startInfo = new ProcessStartInfo
        {
            FileName = pythonExe,
            Arguments = $"\"{serverScript}\" {Port}",
            UseShellExecute = false,
            CreateNoWindow = true,
            WindowStyle = ProcessWindowStyle.Hidden,
            WorkingDirectory = Path.GetDirectoryName(serverScript)!,
            RedirectStandardError = true,
            RedirectStandardOutput = true
        };

        try
        {
            _pythonProcess = Process.Start(startInfo);
            if (_pythonProcess is not null)
            {
                AppDomain.CurrentDomain.ProcessExit += (_, _) => KillServer();
                _ = Task.Run(async () =>
                {
                    try
                    {
                        while (!_pythonProcess.HasExited)
                        {
                            var line = await _pythonProcess.StandardError.ReadLineAsync();
                            if (!string.IsNullOrWhiteSpace(line))
                            {
                                PreviewFrameService.Log("AI Python stderr: " + line);
                            }
                        }
                    }
                    catch { }
                });
            }
        }
        catch (Exception ex)
        {
            PreviewFrameService.Log("Python işlemi başlatılamadı: " + ex.Message);
        }
    }

    private static string FindPythonExe()
    {
        // Önce bilinen Python sürümlerini tercih sırasıyla dene (en yeni → en eski)
        var appDataLocal = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var pyVersions = new[] { "Python313", "Python312", "Python311", "Python310", "Python39" };
        foreach (var ver in pyVersions)
        {
            var candidate = Path.Combine(appDataLocal, "Programs", "Python", ver, "python.exe");
            if (File.Exists(candidate)) return candidate;
        }

        // Klasördeki ilk python.exe'yi bul
        var localPythonGen = Path.Combine(appDataLocal, "Programs", "Python");
        if (Directory.Exists(localPythonGen))
        {
            var match = Directory.GetFiles(localPythonGen, "python.exe", SearchOption.AllDirectories)
                .OrderByDescending(p => p) // en yeni sürüm önce
                .FirstOrDefault();
            if (match is not null) return match;
        }

        // PATH'teki python veya py launcher
        foreach (var name in new[] { "python", "python3", "py" })
        {
            try
            {
                var result = System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
                {
                    FileName = "where",
                    Arguments = name,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    CreateNoWindow = true
                });
                var line = result?.StandardOutput.ReadLine()?.Trim();
                if (!string.IsNullOrEmpty(line) && File.Exists(line)) return line;
            }
            catch { }
        }

        return "python";
    }

    private static string? FindServerScript()
    {
        var candidates = new[]
        {
            Path.Combine(AppContext.BaseDirectory, "ai_bridge", "server.py"),
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "ai_bridge", "server.py"),
            Path.Combine(AppContext.BaseDirectory, "..", "..", "..", "..", "pc", "NoxirPlay.PC", "ai_bridge", "server.py"),
            Path.Combine(Environment.CurrentDirectory, "pc", "NoxirPlay.PC", "ai_bridge", "server.py"),
            Path.Combine(Environment.CurrentDirectory, "ai_bridge", "server.py")
        };

        foreach (var c in candidates)
        {
            var full = Path.GetFullPath(c);
            if (File.Exists(full))
                return full;
        }

        return null;
    }

    public static void KillServer()
    {
        try
        {
            if (_pythonProcess is not null && !_pythonProcess.HasExited)
            {
                _pythonProcess.Kill(entireProcessTree: true);
                _pythonProcess.Dispose();
                _pythonProcess = null;
            }
        }
        catch { }
    }

    public static async Task<OcrDetailedResult> RecognizeRapidOcrDetailedAsync(byte[] imageBytes, string engine = "rapid")
    {
        if (imageBytes.Length == 0) return new OcrDetailedResult(string.Empty, string.Empty, 0.0, string.Empty, string.Empty, string.Empty);

        var ready = await EnsureBridgeRunningAsync();
        if (!ready)
        {
            PreviewFrameService.Log("AI OCR servisine ulaşılamadı (AI sunucusu hazır değil).");
            return new OcrDetailedResult(string.Empty, string.Empty, 0.0, string.Empty, string.Empty, string.Empty);
        }

        try
        {
            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(4));
            using var content = new ByteArrayContent(imageBytes);
            content.Headers.ContentType = new System.Net.Http.Headers.MediaTypeHeaderValue("image/png");

            var endpoint = engine.Contains("easy", StringComparison.OrdinalIgnoreCase) ? "/ocr?engine=easyocr" : "/ocr";
            var response = await _httpClient.PostAsync($"{BaseUrl}{endpoint}", content, cts.Token);
            if (!response.IsSuccessStatusCode)
            {
                PreviewFrameService.Log($"OCR HTTP hatası: {response.StatusCode}");
                return new OcrDetailedResult(string.Empty, string.Empty, 0.0, string.Empty, string.Empty, string.Empty);
            }

            var jsonStr = await response.Content.ReadAsStringAsync(cts.Token);
            using var doc = JsonDocument.Parse(jsonStr);
            var root = doc.RootElement;

            string text = root.TryGetProperty("text", out var tProp) ? tProp.GetString()?.Trim() ?? string.Empty : string.Empty;
            string rawText = root.TryGetProperty("raw_text", out var rProp) ? rProp.GetString()?.Trim() ?? string.Empty : text;
            double conf = root.TryGetProperty("confidence", out var cProp) ? cProp.GetDouble() : 0.0;
            string speaker = root.TryGetProperty("speaker", out var sProp) ? sProp.GetString()?.Trim() ?? string.Empty : string.Empty;
            string dialog = root.TryGetProperty("dialog", out var dProp) ? dProp.GetString()?.Trim() ?? string.Empty : text;
            string b64 = root.TryGetProperty("processed_image_base64", out var imgProp) ? imgProp.GetString() ?? string.Empty : string.Empty;

            return new OcrDetailedResult(text, rawText, conf, speaker, dialog, b64);
        }
        catch (Exception ex)
        {
            PreviewFrameService.Log("RapidOCR HTTP isteği başarısız: " + ex.Message);
            return new OcrDetailedResult(string.Empty, string.Empty, 0.0, string.Empty, string.Empty, string.Empty);
        }
    }

    public static async Task<string> RecognizeRapidOcrBytesAsync(byte[] imageBytes)
    {
        var result = await RecognizeRapidOcrDetailedAsync(imageBytes);
        return result.Text;
    }

    public static Task<string> RecognizeRapidOcrAsync(BitmapSource source)
    {
        byte[] bytes = [];
        var dispatcher = System.Windows.Application.Current?.Dispatcher;
        if (dispatcher is not null && !dispatcher.CheckAccess())
        {
            bytes = dispatcher.Invoke(() => EncodeSourceToPng(source));
        }
        else
        {
            bytes = EncodeSourceToPng(source);
        }
        return RecognizeRapidOcrBytesAsync(bytes);
    }

    private static byte[] EncodeSourceToPng(BitmapSource source)
    {
        try
        {
            using var ms = new MemoryStream();
            var encoder = new PngBitmapEncoder();
            encoder.Frames.Add(BitmapFrame.Create(source));
            encoder.Save(ms);
            return ms.ToArray();
        }
        catch { return []; }
    }

    public static Task<string> TranslateNllbAsync(string text, string sourceLanguage, string targetLanguage) =>
        TranslateAiAsync(text, sourceLanguage, targetLanguage);

    /// <summary>
    /// Python AI Bridge üzerinden çeviri yapar.
    /// sourceLanguage / targetLanguage → Türkçe UI adı (örn. "Türkçe"), ISO kodu ("tr") veya NLLB kodu ("tur_Latn") gönderebilir.
    /// Python map_lang() fonksiyonu her formatı doğru şekilde çözer.
    /// </summary>
    public static async Task<string> TranslateAiAsync(string text, string sourceLanguage, string targetLanguage, string engine = "")
    {
        if (string.IsNullOrWhiteSpace(text)) return string.Empty;

        var ready = await EnsureBridgeRunningAsync();
        if (!ready)
        {
            PreviewFrameService.Log("AI çeviri servisine ulaşılamadı.");
            return string.Empty;
        }

        try
        {
            var payload = new
            {
                text     = text,
                src_lang = sourceLanguage,
                tgt_lang = targetLanguage,
                engine   = engine
            };

            var json = JsonSerializer.Serialize(payload);
            using var content = new StringContent(json, Encoding.UTF8, "application/json");

            using var cts = new CancellationTokenSource(TimeSpan.FromSeconds(30));
            var response = await _httpClient.PostAsync($"{BaseUrl}/translate", content, cts.Token);
            if (!response.IsSuccessStatusCode)
            {
                var body = await response.Content.ReadAsStringAsync(cts.Token);
                PreviewFrameService.Log($"AI çeviri HTTP hatası: {response.StatusCode} — {body}");
                return string.Empty;
            }

            var respJson = await response.Content.ReadAsStringAsync(cts.Token);
            using var doc = JsonDocument.Parse(respJson);
            var root = doc.RootElement;

            // Hata bildirimi varsa logla
            if (root.TryGetProperty("error", out var errProp))
                PreviewFrameService.Log($"AI çeviri hatası: {errProp.GetString()}");

            if (root.TryGetProperty("translation", out var transProp))
            {
                var result = transProp.GetString()?.Trim() ?? string.Empty;
                if (!string.IsNullOrWhiteSpace(result))
                    PreviewFrameService.Log($"AI çeviri başarılı ({engine}): {result.Length} karakter");
                return result;
            }

            return string.Empty;
        }
        catch (OperationCanceledException)
        {
            PreviewFrameService.Log("AI çeviri isteği zaman aşımına uğradı (30s).");
            return string.Empty;
        }
        catch (Exception ex)
        {
            PreviewFrameService.Log("AI çeviri isteği başarısız: " + ex.Message);
            return string.Empty;
        }
    }
}

public sealed record OcrDetailedResult(
    string Text,
    string RawText,
    double Confidence,
    string Speaker,
    string Dialog,
    string ProcessedImageBase64);


```

#### 5. `pc/NoxirPlay.PC/App.xaml`

```xml
<Application x:Class="NoxirPlay.PC.App"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             xmlns:local="clr-namespace:NoxirPlay.PC"
             StartupUri="MainWindow.xaml">
    <Application.Resources>
         
    </Application.Resources>
</Application>
```

#### 6. `pc/NoxirPlay.PC/App.xaml.cs`

```csharp
using System.Windows;

namespace NoxirPlay.PC;

/// <summary>
/// Interaction logic for App.xaml
/// </summary>
public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        AppDomain.CurrentDomain.UnhandledException += (s, ev) =>
        {
            var ex = ev.ExceptionObject as Exception;
            PreviewFrameService.Log($"FATAL AppDomain UnhandledException: {ex}");
            MessageBox.Show($"Kritik Hata: {ex?.Message}\n\nDetay: {ex?.StackTrace}", "NOXIR Play", MessageBoxButton.OK, MessageBoxImage.Error);
        };

        DispatcherUnhandledException += (s, ev) =>
        {
            PreviewFrameService.Log($"FATAL DispatcherUnhandledException: {ev.Exception}");
            MessageBox.Show($"Arayüz Hatası: {ev.Exception.Message}\n\nDetay: {ev.Exception.StackTrace}", "NOXIR Play", MessageBoxButton.OK, MessageBoxImage.Error);
            ev.Handled = true;
        };

        TaskScheduler.UnobservedTaskException += (s, ev) =>
        {
            PreviewFrameService.Log($"UnobservedTaskException: {ev.Exception}");
            ev.SetObserved();
        };
    }
}
```

#### 7. `pc/NoxirPlay.PC/AssemblyInfo.cs`

```csharp
using System.Windows;

[assembly:ThemeInfo(
    ResourceDictionaryLocation.None,            //where theme specific resource dictionaries are located
                                                //(used if a resource is not found in the page,
                                                // or application resource dictionaries)
    ResourceDictionaryLocation.SourceAssembly   //where the generic resource dictionary is located
                                                //(used if a resource is not found in the page,
                                                // app, or any theme specific resource dictionaries)
)]
```

#### 8. `pc/NoxirPlay.PC/ChiakiPs5RegistrationService.cs`

```csharp
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace NoxirPlay.PC;

internal sealed record RegisteredPs5(
    string IpAddress,
    string Nickname,
    string ServerMac,
    string RegistrationKey,
    uint RpKeyType,
    string RpKey,
    DateTimeOffset RegisteredAt);

internal sealed class ChiakiPs5RegistrationService
{
    private const int AccountIdSize = 8;
    private const int KeySize = 16;
    private const int ServerMacSize = 6;
    private const int NicknameSize = 32;
    private const int ErrorCapacity = 512;

    private readonly string _registrationPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NOXIR Play",
        "ps5-registration.dat");

    public async Task<RegisteredPs5> RegisterPs5Async(string host, string linkCode, string accountIdBase64, CancellationToken cancellationToken = default)
    {
        if (!IPAddress.TryParse(host.Trim(), out var address) || address.AddressFamily != AddressFamily.InterNetwork)
            throw new InvalidOperationException("PS5'in IPv4 adresini gir. Örnek: 192.168.1.25");

        var code = linkCode.Trim();
        if (code.Length != 8 || code.Any(character => character is < '0' or > '9'))
            throw new InvalidOperationException("PS5 ekranındaki cihaz bağlama kodu 8 rakamdan oluşmalı.");

        byte[] accountId;
        try
        {
            accountId = Convert.FromBase64String(accountIdBase64);
        }
        catch (FormatException)
        {
            throw new InvalidOperationException("Kayıtlı PSN AccountID geçersiz. PSN hesabını yeniden bağla.");
        }

        if (accountId.Length != AccountIdSize)
        {
            CryptographicOperations.ZeroMemory(accountId);
            throw new InvalidOperationException("Kayıtlı PSN AccountID geçersiz. PSN hesabını yeniden bağla.");
        }

        var serverMac = new byte[ServerMacSize];
        var serverNickname = new StringBuilder(NicknameSize);
        var registrationKey = new byte[KeySize];
        var rpKey = new byte[KeySize];
        var error = new StringBuilder(ErrorCapacity);
        uint rpKeyType = 0;

        try
        {
            int result;
            try
            {
                result = await Task.Run(() => NativeMethods.RegisterPs5(
                    address.ToString(),
                    accountId,
                    uint.Parse(code, System.Globalization.CultureInfo.InvariantCulture),
                    serverMac,
                    serverNickname,
                    (nuint)NicknameSize,
                    registrationKey,
                    out rpKeyType,
                    rpKey,
                    error,
                    (nuint)ErrorCapacity), cancellationToken);
            }
            catch (DllNotFoundException ex)
            {
                throw new InvalidOperationException("PS5 kayıt motoru yüklenemedi. Uygulama dosyalarını onar.", ex);
            }
            catch (BadImageFormatException ex)
            {
                throw new InvalidOperationException("PS5 kayıt motorunun mimarisi bu uygulamayla uyumlu değil.", ex);
            }

            if (result != 0)
                throw new InvalidOperationException(string.IsNullOrWhiteSpace(error.ToString())
                    ? $"PS5 eşleştirmesi başarısız oldu ({result}). IP adresini, kodu ve ağ bağlantısını kontrol et."
                    : error.ToString());

            var registration = new RegisteredPs5(
                address.ToString(),
                serverNickname.ToString().TrimEnd('\0'),
                Convert.ToHexString(serverMac),
                Convert.ToBase64String(registrationKey),
                rpKeyType,
                Convert.ToBase64String(rpKey),
                DateTimeOffset.UtcNow);

            SaveRegistration(registration);
            return registration;
        }
        finally
        {
            CryptographicOperations.ZeroMemory(accountId);
            CryptographicOperations.ZeroMemory(registrationKey);
            CryptographicOperations.ZeroMemory(rpKey);
        }
    }

    public RegisteredPs5? LoadRegistration()
    {
        if (!File.Exists(_registrationPath)) return null;

        byte[]? encrypted = null;
        byte[]? clear = null;
        try
        {
            encrypted = File.ReadAllBytes(_registrationPath);
            clear = ProtectedData.Unprotect(encrypted, optionalEntropy: null, DataProtectionScope.CurrentUser);
            return JsonSerializer.Deserialize<RegisteredPs5>(clear);
        }
        catch (CryptographicException)
        {
            return null;
        }
        catch (JsonException)
        {
            return null;
        }
        finally
        {
            if (encrypted is not null) CryptographicOperations.ZeroMemory(encrypted);
            if (clear is not null) CryptographicOperations.ZeroMemory(clear);
        }
    }

    public void ClearRegistration()
    {
        if (File.Exists(_registrationPath))
            File.Delete(_registrationPath);
    }

    private void SaveRegistration(RegisteredPs5 registration)
    {
        var folder = Path.GetDirectoryName(_registrationPath)!;
        Directory.CreateDirectory(folder);
        var clear = JsonSerializer.SerializeToUtf8Bytes(registration);
        try
        {
            var encrypted = ProtectedData.Protect(clear, optionalEntropy: null, DataProtectionScope.CurrentUser);
            var temporaryPath = _registrationPath + ".new";
            File.WriteAllBytes(temporaryPath, encrypted);
            File.Move(temporaryPath, _registrationPath, overwrite: true);
        }
        finally
        {
            CryptographicOperations.ZeroMemory(clear);
        }
    }

    private static class NativeMethods
    {
        [DllImport("libnoxir-chiaki-bridge.dll", EntryPoint = "noxir_register_ps5", ExactSpelling = true,
            CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        internal static extern int RegisterPs5(
            [MarshalAs(UnmanagedType.LPUTF8Str)] string host,
            [In] byte[] accountId,
            uint deviceLinkCode,
            [Out] byte[] serverMac,
            [Out] StringBuilder serverNickname,
            nuint serverNicknameCapacity,
            [Out] byte[] registrationKey,
            out uint rpKeyType,
            [Out] byte[] rpKey,
            [Out] StringBuilder errorMessage,
            nuint errorMessageCapacity);
    }
}
```

#### 9. `pc/NoxirPlay.PC/FfmpegStreamService.cs`

```csharp
using System.Diagnostics;
using System.IO;

namespace NoxirPlay.PC;

internal sealed class FfmpegStreamService : IAsyncDisposable
{
    private Process? _process;
    private string _lastError = string.Empty;
    public bool IsRunning => _process is { HasExited: false };
    public event Action<string>? Faulted;

    public async Task<Stream> StartH264InputAsync(string ffmpegPath, string streamFolder)
    {
        await StopAsync();
        PrepareStreamFolder(streamFolder);
        var playlistPath = Path.Combine(streamFolder, "index.m3u8");
        var segmentPattern = Path.Combine(streamFolder, "segment_%05d.ts");
        var startInfo = new ProcessStartInfo(ffmpegPath)
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardInput = true,
            RedirectStandardError = true,
            RedirectStandardOutput = true
        };
        foreach (var argument in new[]
        {
            "-hide_banner", "-loglevel", "warning", "-fflags", "+genpts", "-f", "h264", "-i", "pipe:0",
            "-an", "-c:v", "copy", "-f", "hls", "-hls_time", "1", "-hls_list_size", "4",
            "-hls_flags", "delete_segments+append_list+omit_endlist",
            "-hls_segment_filename", segmentPattern, playlistPath
        }) startInfo.ArgumentList.Add(argument);

        var process = new Process { StartInfo = startInfo, EnableRaisingEvents = true };
        process.ErrorDataReceived += (_, e) =>
        {
            if (!string.IsNullOrWhiteSpace(e.Data)) _lastError = e.Data;
        };
        process.Exited += (_, _) =>
        {
            if (_process == process && process.ExitCode != 0)
                Faulted?.Invoke(string.IsNullOrWhiteSpace(_lastError) ? $"FFmpeg kapandı (kod {process.ExitCode})." : _lastError);
        };

        if (!process.Start()) throw new InvalidOperationException("FFmpeg başlatılamadı.");
        _process = process;
        _lastError = string.Empty;
        process.BeginErrorReadLine();
        _ = process.StandardOutput.ReadToEndAsync();
        return process.StandardInput.BaseStream;
    }

    private static void PrepareStreamFolder(string streamFolder)
    {
        Directory.CreateDirectory(streamFolder);
        foreach (var file in Directory.EnumerateFiles(streamFolder))
            try { File.Delete(file); } catch { }
    }

    public async Task StartAsync(string ffmpegPath, string streamFolder, int displayIndex = 0, CancellationToken cancellationToken = default)
    {
        await StopAsync();
        PrepareStreamFolder(streamFolder);

        var playlistPath = Path.Combine(streamFolder, "index.m3u8");
        var segmentPattern = Path.Combine(streamFolder, "segment_%05d.ts");
        var startInfo = new ProcessStartInfo(ffmpegPath)
        {
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardError = true,
            RedirectStandardOutput = true
        };
        foreach (var argument in new[]
        {
            "-hide_banner", "-loglevel", "warning",
            "-filter_complex", $"ddagrab=output_idx={displayIndex}:framerate=60:draw_mouse=0,hwdownload,format=bgra,format=nv12",
            "-c:v", "h264_mf", "-scenario", "live_streaming", "-rate_control", "cbr", "-b:v", "10000k", "-g", "60", "-bf", "0",
            "-an", "-f", "hls", "-hls_time", "1", "-hls_list_size", "4",
            "-hls_flags", "delete_segments+append_list+omit_endlist",
            "-hls_segment_filename", segmentPattern, playlistPath
        }) startInfo.ArgumentList.Add(argument);

        var process = new Process { StartInfo = startInfo, EnableRaisingEvents = true };
        process.ErrorDataReceived += (_, e) =>
        {
            if (!string.IsNullOrWhiteSpace(e.Data)) _lastError = e.Data;
        };
        process.Exited += (_, _) =>
        {
            if (_process == process && process.ExitCode != 0)
                Faulted?.Invoke(string.IsNullOrWhiteSpace(_lastError) ? $"FFmpeg kapandı (kod {process.ExitCode})." : _lastError);
        };

        if (!process.Start()) throw new InvalidOperationException("FFmpeg başlatılamadı.");
        _process = process;
        _lastError = string.Empty;
        process.BeginErrorReadLine();
        _ = process.StandardOutput.ReadToEndAsync(cancellationToken);
        await Task.Delay(900, cancellationToken);
        if (process.HasExited)
        {
            var detail = string.IsNullOrWhiteSpace(_lastError) ? $"FFmpeg kapandı (kod {process.ExitCode})." : _lastError;
            _process = null;
            process.Dispose();
            throw new InvalidOperationException(detail);
        }
    }

    public async Task StopAsync()
    {
        var process = _process;
        _process = null;
        if (process is null) return;
        try
        {
            if (!process.HasExited) process.Kill(entireProcessTree: true);
            await process.WaitForExitAsync();
        }
        catch { }
        process.Dispose();
    }

    public async ValueTask DisposeAsync() => await StopAsync();
}
```

#### 10. `pc/NoxirPlay.PC/GoogleTranslateService.cs`

```csharp
using System.Net.Http;
using System.Text;
using System.Text.Json;

namespace NoxirPlay.PC;

internal static class GoogleTranslateService
{
    private static readonly HttpClient Http = CreateHttpClient();

    // Desteklenen dil kodları
    private static readonly Dictionary<string, string> LangMap = new(StringComparer.OrdinalIgnoreCase)
    {
        ["İngilizce"]        = "en",
        ["Ingilizce"]        = "en",
        ["Japonca"]          = "ja",
        ["Korece"]           = "ko",
        ["Çince"]            = "zh-CN",
        ["Cince"]            = "zh-CN",
        ["Almanca"]          = "de",
        ["Fransızca"]        = "fr",
        ["Fransizca"]        = "fr",
        ["İspanyolca"]       = "es",
        ["Ispanyolca"]       = "es",
        ["Rusça"]            = "ru",
        ["Rusca"]            = "ru",
        ["Italyanca"]        = "it",
        ["İtalyanca"]        = "it",
        ["Türkçe"]           = "tr",
        ["Turkce"]           = "tr",
        ["Türkce"]           = "tr",
        ["Otomatik algıla"]  = "auto",
        ["Otomatik algi̇la"] = "auto",
        ["auto"]             = "auto",
    };

    private static HttpClient CreateHttpClient()
    {
        var handler = new HttpClientHandler
        {
            AutomaticDecompression = System.Net.DecompressionMethods.GZip
                                   | System.Net.DecompressionMethods.Deflate
                                   | System.Net.DecompressionMethods.Brotli,
        };
        var client = new HttpClient(handler) { Timeout = TimeSpan.FromSeconds(12) };
        client.DefaultRequestHeaders.UserAgent.ParseAdd(
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
            + "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36");
        client.DefaultRequestHeaders.AcceptEncoding.ParseAdd("gzip, deflate, br");
        client.DefaultRequestHeaders.Accept.ParseAdd("application/json, text/plain, */*");
        return client;
    }

    private static string ResolveCode(string lang, string defaultCode)
    {
        if (string.IsNullOrWhiteSpace(lang)) return defaultCode;
        return LangMap.TryGetValue(lang.Trim(), out var code) ? code : defaultCode;
    }

    public static async Task<string> TranslateAsync(
        string text,
        string sourceLanguage = "Otomatik algıla",
        string targetLanguage = "Türkçe",
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(text)) return string.Empty;

        var sl = ResolveCode(sourceLanguage, "auto");
        var tl = ResolveCode(targetLanguage, "tr");
        if (tl == "auto") tl = "tr"; // hedef asla auto olamaz

        // gtx client ile dene
        var result = await TryTranslateAsync(text, sl, tl, "gtx", cancellationToken);
        if (!string.IsNullOrWhiteSpace(result)) return result;

        // gt4 client yedek
        PreviewFrameService.Log("Google Translate gtx başarısız, gt4 deneniyor...");
        result = await TryTranslateAsync(text, sl, tl, "gt4", cancellationToken);
        if (!string.IsNullOrWhiteSpace(result)) return result;

        // Alternatif: translate.google.com endpoint (Brotli desteği olmadan)
        PreviewFrameService.Log("Google Translate gt4 başarısız, alternatif endpoint deneniyor...");
        result = await TryTranslateAlternativeAsync(text, sl, tl, cancellationToken);
        return result;
    }

    private static async Task<string> TryTranslateAsync(
        string text, string sl, string tl, string client,
        CancellationToken cancellationToken)
    {
        try
        {
            var encoded = Uri.EscapeDataString(text);
            var url = $"https://translate.googleapis.com/translate_a/single"
                    + $"?client={client}&sl={sl}&tl={tl}&dt=t&q={encoded}";

            using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            cts.CancelAfter(TimeSpan.FromSeconds(10));

            using var response = await Http.GetAsync(url, cts.Token);

            if (!response.IsSuccessStatusCode)
            {
                PreviewFrameService.Log($"Google Translate HTTP {(int)response.StatusCode} ({client})");
                return string.Empty;
            }

            var bytes = await response.Content.ReadAsByteArrayAsync(cts.Token);
            var json  = Encoding.UTF8.GetString(bytes);

            return ParseTranslationJson(json);
        }
        catch (OperationCanceledException)
        {
            PreviewFrameService.Log("Google Translate zaman aşımı.");
            return string.Empty;
        }
        catch (Exception ex)
        {
            PreviewFrameService.Log($"Google Translate istisnası ({client}): {ex.Message}");
            return string.Empty;
        }
    }

    private static async Task<string> TryTranslateAlternativeAsync(
        string text, string sl, string tl,
        CancellationToken cancellationToken)
    {
        try
        {
            // Farklı UserAgent ile translate.google.com
            var encoded = Uri.EscapeDataString(text);
            var url = $"https://translate.google.com/translate_a/single"
                    + $"?client=gtx&sl={sl}&tl={tl}&dt=t&q={encoded}";

            var request = new HttpRequestMessage(HttpMethod.Get, url);
            request.Headers.UserAgent.Clear();
            request.Headers.UserAgent.ParseAdd(
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
                + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1");

            using var cts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            cts.CancelAfter(TimeSpan.FromSeconds(10));

            using var response = await Http.SendAsync(request, cts.Token);
            if (!response.IsSuccessStatusCode)
            {
                PreviewFrameService.Log($"Google Translate alt. HTTP {(int)response.StatusCode}");
                return string.Empty;
            }

            var bytes = await response.Content.ReadAsByteArrayAsync(cts.Token);
            var json  = Encoding.UTF8.GetString(bytes);
            return ParseTranslationJson(json);
        }
        catch (Exception ex)
        {
            PreviewFrameService.Log($"Google Translate alt. endpoint istisnası: {ex.Message}");
            return string.Empty;
        }
    }

    private static string ParseTranslationJson(string json)
    {
        try
        {
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            if (root.ValueKind != JsonValueKind.Array || root.GetArrayLength() == 0)
                return string.Empty;

            var sentences = root[0];
            var sb = new StringBuilder();
            foreach (var sentence in sentences.EnumerateArray())
            {
                if (sentence.ValueKind == JsonValueKind.Array
                    && sentence.GetArrayLength() > 0
                    && sentence[0].ValueKind == JsonValueKind.String)
                {
                    sb.Append(sentence[0].GetString());
                }
            }

            return sb.ToString().Trim();
        }
        catch (Exception ex)
        {
            PreviewFrameService.Log($"Google Translate JSON ayrıştırma hatası: {ex.Message}");
            return string.Empty;
        }
    }
}
```

#### 11. `pc/NoxirPlay.PC/LocalLanServer.cs`

```csharp
using System.Collections.Concurrent;
using System.IO;
using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Net.WebSockets;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace NoxirPlay.PC;

internal sealed class LocalLanServer : IAsyncDisposable
{
    public const int Port = 8765;
    private readonly string _streamFolder;
    private readonly string _pairCode = RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");
    private readonly DateTimeOffset _pairCodeExpiresAt = DateTimeOffset.UtcNow.AddMinutes(10);
    private readonly ConcurrentDictionary<string, byte> _tokens = new(StringComparer.Ordinal);
    private readonly ConcurrentDictionary<string, WebSocket> _sockets = new(StringComparer.Ordinal);
    private readonly ConcurrentDictionary<string, (DateTimeOffset WindowStarted, int Count)> _pairFailures = new(StringComparer.Ordinal);
    private WebApplication? _app;
    private int _pairCodeUsed;

    public LocalLanServer(string streamFolder) => _streamFolder = streamFolder;
    public string PairCode => _pairCode;
    public string LocalAddress => FindLocalIpv4() ?? "Bu PC'de yerel IPv4 bulunamadı";
    public event Action? TvPaired;

    public async Task StartAsync(CancellationToken cancellationToken = default)
    {
        Directory.CreateDirectory(_streamFolder);
        var builder = WebApplication.CreateSlimBuilder();
        builder.Logging.ClearProviders();
        builder.WebHost.UseUrls($"http://0.0.0.0:{Port}");
        builder.Services.AddRouting();
        var app = builder.Build();

        app.Use(async (context, next) =>
        {
            context.Response.Headers.AccessControlAllowOrigin = "*";
            context.Response.Headers.AccessControlAllowMethods = "GET,POST,OPTIONS";
            context.Response.Headers.AccessControlAllowHeaders = "Content-Type";
            if (HttpMethods.IsOptions(context.Request.Method))
            {
                context.Response.StatusCode = StatusCodes.Status204NoContent;
                return;
            }
            await next();
        });
        app.UseWebSockets();

        app.MapGet("/api/health", () => Results.Json(new { service = "NOXIR Play", ready = true, streamReady = File.Exists(Path.Combine(_streamFolder, "index.m3u8")) }));
        app.MapPost("/api/pair", async (HttpContext context) =>
        {
            PairRequest? request;
            try { request = await context.Request.ReadFromJsonAsync<PairRequest>(); }
            catch { request = null; }
            var clientIp = context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
            if (_pairCodeUsed != 0)
            {
                context.Response.StatusCode = StatusCodes.Status409Conflict;
                return Results.Json(new { message = "Bu kod kullanıldı. PC uygulamasını yeniden başlatıp yeni kodu gir." });
            }
            if (DateTimeOffset.UtcNow > _pairCodeExpiresAt)
            {
                context.Response.StatusCode = StatusCodes.Status410Gone;
                return Results.Json(new { message = "Bağlantı kodunun süresi doldu. PC uygulamasını yeniden başlat." });
            }
            var now = DateTimeOffset.UtcNow;
            if (_pairFailures.TryGetValue(clientIp, out var priorAttempts) &&
                now - priorAttempts.WindowStarted <= TimeSpan.FromMinutes(1) && priorAttempts.Count >= 8)
            {
                context.Response.StatusCode = StatusCodes.Status429TooManyRequests;
                return Results.Json(new { message = "Çok fazla deneme yapıldı. Bir dakika sonra yeniden dene." });
            }
            if (request?.Code is null || request.Code.Length != 6 ||
                !CryptographicOperations.FixedTimeEquals(Encoding.ASCII.GetBytes(request.Code), Encoding.ASCII.GetBytes(_pairCode)))
            {
                var attempts = _pairFailures.AddOrUpdate(clientIp, _ => (now, 1), (_, existing) =>
                    now - existing.WindowStarted > TimeSpan.FromMinutes(1) ? (now, 1) : (existing.WindowStarted, existing.Count + 1));
                context.Response.StatusCode = attempts.Count >= 8 ? StatusCodes.Status429TooManyRequests : StatusCodes.Status401Unauthorized;
                return Results.Json(new { message = attempts.Count >= 8 ? "Çok fazla deneme yapıldı. Bir dakika sonra yeniden dene." : "Bağlantı kodu hatalı." });
            }

            if (Interlocked.Exchange(ref _pairCodeUsed, 1) != 0)
            {
                context.Response.StatusCode = StatusCodes.Status409Conflict;
                return Results.Json(new { message = "Kod başka bir TV'de kullanıldı." });
            }
            var token = Convert.ToHexString(RandomNumberGenerator.GetBytes(32)).ToLowerInvariant();
            _tokens.TryAdd(token, 0);
            TvPaired?.Invoke();
            return Results.Json(new { token, address = LocalAddress, port = Port });
        });
        app.MapGet("/api/stream/{fileName}", async (HttpContext context, string fileName) =>
        {
            if (!IsPaired(context.Request.Query["token"])) return Results.Unauthorized();
            if (Path.GetFileName(fileName) != fileName || !(fileName.EndsWith(".m3u8", StringComparison.OrdinalIgnoreCase) || fileName.EndsWith(".ts", StringComparison.OrdinalIgnoreCase)))
                return Results.BadRequest();
            var path = Path.Combine(_streamFolder, fileName);
            if (!File.Exists(path)) return Results.NotFound();
            context.Response.Headers.CacheControl = "no-store, no-cache, must-revalidate";
            context.Response.Headers.Pragma = "no-cache";
            if (fileName.EndsWith(".m3u8", StringComparison.OrdinalIgnoreCase))
            {
                string playlist;
                try { playlist = await File.ReadAllTextAsync(path, context.RequestAborted); }
                catch (IOException) { return Results.StatusCode(StatusCodes.Status503ServiceUnavailable); }
                var safeToken = Uri.EscapeDataString(context.Request.Query["token"].ToString());
                var rewritten = string.Join('\n', playlist.Split('\n').Select(line =>
                {
                    var item = line.Trim();
                    if (item.Length == 0 || item.StartsWith('#') || item.StartsWith("http", StringComparison.OrdinalIgnoreCase)) return line;
                    var segment = Path.GetFileName(item);
                    return $"/api/stream/{Uri.EscapeDataString(segment)}?token={safeToken}";
                }));
                return Results.Content(rewritten, "application/vnd.apple.mpegurl", Encoding.UTF8);
            }
            return Results.File(path, "video/mp2t", enableRangeProcessing: true);
        });
        app.Map("/api/captions", async (HttpContext context) =>
        {
            if (!context.WebSockets.IsWebSocketRequest)
            {
                context.Response.StatusCode = StatusCodes.Status400BadRequest;
                return;
            }
            var token = context.Request.Query["token"].ToString();
            var socketId = !string.IsNullOrWhiteSpace(token) ? token : ("direct_" + Guid.NewGuid().ToString("N"));
            using var socket = await context.WebSockets.AcceptWebSocketAsync();
            _sockets[socketId] = socket;
            var buffer = new byte[256];
            try
            {
                while (socket.State == WebSocketState.Open)
                {
                    var received = await socket.ReceiveAsync(buffer, context.RequestAborted);
                    if (received.MessageType == WebSocketMessageType.Close) break;
                }
            }
            catch (OperationCanceledException) { }
            catch (WebSocketException) { }
            finally { _sockets.TryRemove(socketId, out _); }
        });

        _app = app;
        await app.StartAsync(cancellationToken);
    }

    public async Task BroadcastCaptionAsync(string text, bool hideOriginal = true, CancellationToken cancellationToken = default)
    {
        var payload = JsonSerializer.Serialize(new
        {
            type = string.IsNullOrWhiteSpace(text) ? "clear" : "caption",
            text,
            hideOriginal
        });
        var bytes = Encoding.UTF8.GetBytes(payload);
        foreach (var pair in _sockets.ToArray())
        {
            var socket = pair.Value;
            if (socket is null || socket.State != WebSocketState.Open) continue;
            try { await socket.SendAsync(bytes, WebSocketMessageType.Text, true, cancellationToken); }
            catch (WebSocketException) { _sockets.TryRemove(pair.Key, out _); }
        }
    }

    public bool IsPaired(string? token) => !string.IsNullOrWhiteSpace(token) && _tokens.ContainsKey(token);

    public async Task StopAsync(CancellationToken cancellationToken = default)
    {
        if (_app is null) return;
        await _app.StopAsync(cancellationToken);
        await _app.DisposeAsync();
        _app = null;
    }

    public async ValueTask DisposeAsync() => await StopAsync();

    private static string? FindLocalIpv4()
    {
        foreach (var adapter in NetworkInterface.GetAllNetworkInterfaces()
                     .Where(a => a.OperationalStatus == OperationalStatus.Up &&
                                 a.NetworkInterfaceType is NetworkInterfaceType.Ethernet or NetworkInterfaceType.Wireless80211))
        {
            var hasGateway = adapter.GetIPProperties().GatewayAddresses.Any(g => g.Address.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(g.Address));
            if (!hasGateway) continue;
            var candidate = adapter.GetIPProperties().UnicastAddresses
                .Select(a => a.Address)
                .FirstOrDefault(a => a.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(a) && !a.ToString().StartsWith("169.254.", StringComparison.Ordinal));
            if (candidate is not null) return candidate.ToString();
        }
        return Dns.GetHostAddresses(Dns.GetHostName()).FirstOrDefault(a => a.AddressFamily == AddressFamily.InterNetwork && !IPAddress.IsLoopback(a))?.ToString();
    }

    private sealed record PairRequest(string Code);
}
```

#### 12. `pc/NoxirPlay.PC/MainWindow.xaml`

```xml
<Window x:Class="NoxirPlay.PC.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:wv2="clr-namespace:Microsoft.Web.WebView2.Wpf;assembly=Microsoft.Web.WebView2.Wpf"
        Title="NOXIR Play" Width="1100" Height="760" MinWidth="940" MinHeight="680"
        WindowStartupLocation="CenterScreen" Background="#090B11" Foreground="#F5F6FA"
        FontFamily="Segoe UI" Loaded="Window_Loaded" Closing="Window_Closing">
    <Window.Resources>
        <SolidColorBrush x:Key="PanelBrush" Color="#141822"/>
        <SolidColorBrush x:Key="MutedBrush" Color="#9299AA"/>
        <Style x:Key="PrimaryButton" TargetType="Button">
            <Setter Property="Background" Value="#8567F5"/><Setter Property="Foreground" Value="White"/>
            <Setter Property="BorderThickness" Value="0"/><Setter Property="Padding" Value="20,14"/>
            <Setter Property="FontSize" Value="15"/><Setter Property="FontWeight" Value="SemiBold"/><Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button"><Border x:Name="back" Background="{TemplateBinding Background}" CornerRadius="12" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border><ControlTemplate.Triggers><Trigger Property="IsMouseOver" Value="True"><Setter TargetName="back" Property="Background" Value="#9B83FF"/></Trigger><Trigger Property="IsEnabled" Value="False"><Setter TargetName="back" Property="Opacity" Value=".45"/></Trigger></ControlTemplate.Triggers></ControlTemplate></Setter.Value></Setter>
        </Style>
        <Style x:Key="SecondaryButton" TargetType="Button" BasedOn="{StaticResource PrimaryButton}">
            <Setter Property="Background" Value="#202534"/><Setter Property="Foreground" Value="#E7E9F0"/>
        </Style>
            <Style x:Key="FieldLabel" TargetType="TextBlock">
            <Setter Property="FontSize" Value="12"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Foreground" Value="#C4C9D5"/>
            <Setter Property="Margin" Value="0,0,0,8"/>
        </Style>
        <Style x:Key="FieldHelp" TargetType="TextBlock">
            <Setter Property="FontSize" Value="11"/>
            <Setter Property="Foreground" Value="#707B8D"/>
            <Setter Property="TextWrapping" Value="Wrap"/>
            <Setter Property="Margin" Value="0,7,0,18"/>
        </Style>
        <Style x:Key="FieldBox" TargetType="TextBox">
            <Setter Property="Foreground" Value="#F5F6FA"/>
            <Setter Property="CaretBrush" Value="#F5F6FA"/>
            <Setter Property="SelectionBrush" Value="#8567F5"/>
            <Setter Property="FontSize" Value="15"/>
            <Setter Property="Padding" Value="14,11"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="TextBox">
                        <Border x:Name="bd" Background="#0D1018" BorderBrush="#2C3548" BorderThickness="1" CornerRadius="10">
                            <Grid>
                                <ScrollViewer x:Name="PART_ContentHost" Margin="{TemplateBinding Padding}" VerticalAlignment="Center"/>
                                <TextBlock x:Name="hint" Text="{TemplateBinding Tag}" Foreground="#5B6477" FontSize="{TemplateBinding FontSize}" IsHitTestVisible="False" Visibility="Collapsed" Margin="16,0,14,0" VerticalAlignment="Center"/>
                            </Grid>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="Text" Value="">
                                <Setter TargetName="hint" Property="Visibility" Value="Visible"/>
                            </Trigger>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="BorderBrush" Value="#3D4966"/>
                            </Trigger>
                            <Trigger Property="IsKeyboardFocused" Value="True">
                                <Setter TargetName="bd" Property="BorderBrush" Value="#8567F5"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="SegmentButton" TargetType="RadioButton">
            <Setter Property="Foreground" Value="#9299AA"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="RadioButton">
                        <Border x:Name="bd" Background="Transparent" BorderBrush="#2C3548" BorderThickness="1" CornerRadius="10" Padding="18,11">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="bd" Property="BorderBrush" Value="#3D4966"/>
                            </Trigger>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="bd" Property="Background" Value="#211C36"/>
                                <Setter TargetName="bd" Property="BorderBrush" Value="#8567F5"/>
                                <Setter Property="Foreground" Value="#E3DDFF"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>
    <Grid>
        <Grid x:Name="MainContent" Margin="48,38">
            <Grid x:Name="HomeView">
                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                <Grid>
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <Border Width="40" Height="40" CornerRadius="13" Background="#8567F5"><TextBlock Text="N" FontSize="22" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                        <TextBlock Text="NOXIR" FontSize="20" FontWeight="Bold" Margin="12,0,0,0" VerticalAlignment="Center"/><TextBlock Text="Play" FontSize="20" Foreground="#B4A8FF" Margin="6,0,0,0" VerticalAlignment="Center"/>
                    </StackPanel>
                    <Button Content="Çeviri ayarları" Style="{StaticResource SecondaryButton}" Click="OpenTranslationSettings_Click" HorizontalAlignment="Right" VerticalAlignment="Center" Padding="16,10"/>
                </Grid>
                <StackPanel Grid.Row="1" VerticalAlignment="Center" HorizontalAlignment="Center" Width="520">
                    <Button x:Name="TranslateButton" Content="PS5 görüntüsünü başlat" Style="{StaticResource PrimaryButton}" Click="TranslateButton_Click" FontSize="18" Padding="26,17" HorizontalAlignment="Center"/>
                    <Border Background="#111722" BorderBrush="#28344A" BorderThickness="1" CornerRadius="14" Padding="16,13" Margin="0,16,0,0">
                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                            <Ellipse x:Name="HomePs5StatusDot" Width="8" Height="8" Fill="#E0B341" VerticalAlignment="Center" Margin="0,0,10,0"/>
                            <TextBlock x:Name="HomePs5StatusText" Text="PS5 bağlantısı kontrol ediliyor…" Foreground="#C4C9D5" FontSize="13" VerticalAlignment="Center" TextWrapping="Wrap" MaxWidth="450"/>
                        </StackPanel>
                    </Border>
                </StackPanel>
            </Grid>

            <Grid x:Name="TranslationSettingsView" Visibility="Collapsed">
                <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/></Grid.RowDefinitions>
                <Grid>
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                        <Border Width="40" Height="40" CornerRadius="13" Background="#8567F5"><TextBlock Text="N" FontSize="22" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
                        <TextBlock Text="NOXIR" FontSize="20" FontWeight="Bold" Margin="12,0,0,0" VerticalAlignment="Center"/><TextBlock Text="Play" FontSize="20" Foreground="#B4A8FF" Margin="6,0,0,0" VerticalAlignment="Center"/>
                    </StackPanel>
                    <Button Content="Geri" Style="{StaticResource SecondaryButton}" Click="CloseTranslationSettings_Click" HorizontalAlignment="Right" VerticalAlignment="Center" Padding="18,10"/>
                </Grid>
                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,28,0,0">
                    <StackPanel MaxWidth="760" HorizontalAlignment="Center">
                        <TextBlock Text="Çeviri ayarları" FontSize="30" FontWeight="SemiBold"/>
                        <TextBlock Text="Altyazıyı okuma ve çevirme motorlarını buradan seç." TextWrapping="Wrap" Foreground="{StaticResource MutedBrush}" FontSize="14" Margin="0,7,0,20"/>

                        <Border Background="{StaticResource PanelBrush}" BorderBrush="#272D3A" BorderThickness="1" CornerRadius="16" Padding="20" Margin="0,0,0,14">
                            <StackPanel>
                                <TextBlock Text="Altyazı okuma · OCR" FontSize="16" FontWeight="SemiBold"/>
                                <TextBlock Text="Ekrandaki yazıyı okuyacak motor" FontSize="12" Foreground="{StaticResource MutedBrush}" Margin="0,5,0,10"/>
                                <ComboBox x:Name="OcrEngineBox" SelectedIndex="0" Padding="10,8" FontSize="14">
                                    <ComboBoxItem Content="RapidOCR PP-OCRv6 Tiny (Çok Hızlı / Önerilen)"/>
                                    <ComboBoxItem Content="EasyOCR (Orta / Hassas)"/>
                                </ComboBox>
                                <TextBlock Text="Seçim kaydedilir; OCR, PS5 canlı görüntü bağlantısı kurulduğunda çalışır." FontSize="11" Foreground="#707B8D" Margin="0,8,0,0"/>
                            </StackPanel>
                        </Border>

                        <Border Background="{StaticResource PanelBrush}" BorderBrush="#272D3A" BorderThickness="1" CornerRadius="16" Padding="20" Margin="0,0,0,14">
                            <StackPanel>
                                <TextBlock Text="Çeviri servisi" FontSize="16" FontWeight="SemiBold"/>
                                <ComboBox x:Name="TranslationServiceBox" SelectedIndex="0" Padding="10,8" FontSize="14" Margin="0,10,0,12" SelectionChanged="TranslationServiceBox_SelectionChanged">
                                    <ComboBoxItem Content="NOXIR Opus-MT (Oyun Çevirisi - En Hızlı)"/>
                                    <ComboBoxItem Content="NLLB-200 distilled 600M (Yedek Çevrimdışı)"/>
                                    <ComboBoxItem Content="Google Translate (Çevrimiçi)"/>
                                    <ComboBoxItem Content="DeepL API (Anahtar Gerekli)"/>
                                </ComboBox>
                                <StackPanel x:Name="ApiKeyContainer" Visibility="Collapsed">
                                    <TextBlock Text="DeepL API anahtarı" FontSize="12" Foreground="{StaticResource MutedBrush}" Margin="0,0,0,7"/>
                                    <PasswordBox x:Name="TranslationApiKeyBox" Padding="12,10" FontSize="14"/>
                                    <TextBlock Text="Anahtar bu Windows hesabında şifreli saklanır." FontSize="11" Foreground="#707B8D" Margin="0,7,0,0"/>
                                </StackPanel>
                            </StackPanel>
                        </Border>

                        <Border Background="{StaticResource PanelBrush}" BorderBrush="#272D3A" BorderThickness="1" CornerRadius="16" Padding="20" Margin="0,0,0,14">
                            <StackPanel>
                                <TextBlock Text="Dil yönü" FontSize="16" FontWeight="SemiBold" Margin="0,0,0,12"/>
                                <Grid>
                                    <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="16"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
                                    <StackPanel>
                                        <TextBlock Text="Altyazı dili" FontSize="12" Foreground="{StaticResource MutedBrush}" Margin="0,0,0,7"/>
                                        <ComboBox x:Name="SourceLanguageBox" SelectedIndex="0" Padding="10,8">
                                            <ComboBoxItem Content="Otomatik algıla"/><ComboBoxItem Content="İngilizce"/><ComboBoxItem Content="Japonca"/><ComboBoxItem Content="Korece"/><ComboBoxItem Content="Çince"/>
                                        </ComboBox>
                                    </StackPanel>
                                    <StackPanel Grid.Column="2">
                                        <TextBlock Text="Çeviri dili" FontSize="12" Foreground="{StaticResource MutedBrush}" Margin="0,0,0,7"/>
                                        <ComboBox x:Name="TargetLanguageBox" SelectedIndex="0" Padding="10,8">
                                            <ComboBoxItem Content="Türkçe"/><ComboBoxItem Content="İngilizce"/><ComboBoxItem Content="Almanca"/><ComboBoxItem Content="Fransızca"/><ComboBoxItem Content="İspanyolca"/>
                                        </ComboBox>
                                    </StackPanel>
                                </Grid>
                            </StackPanel>
                        </Border>

                        <Border Background="#111722" BorderBrush="#28344A" BorderThickness="1" CornerRadius="16" Padding="18">
                            <StackPanel>
                                <TextBlock Text="Altyazı bölgesi" FontSize="16" FontWeight="SemiBold"/>
                                <TextBlock Text="PS5 görüntüsündeki altyazı alanını aşağıdaki çerçeve ile hizala (Varsayılan %70 - %95 altyazı alanı seçilidir)." Foreground="{StaticResource MutedBrush}" FontSize="12" Margin="0,4,0,10"/>
                                
                                <Border x:Name="PreviewContainerBorder" Height="300" Background="#090B11" BorderBrush="#30394A" BorderThickness="1" CornerRadius="10" ClipToBounds="True" SizeChanged="PreviewContainerBorder_SizeChanged">
                                    <Grid>
                                        <Image x:Name="SubtitleRegionPreviewImage" Stretch="Uniform" Visibility="Collapsed" RenderOptions.BitmapScalingMode="HighQuality"/>
                                        <Canvas x:Name="CropCanvas" Visibility="Collapsed">
                                            <Border x:Name="CropBox"
                                                    BorderBrush="#00E5FF" BorderThickness="2"
                                                    Background="#2200E5FF" CornerRadius="4"
                                                    Cursor="SizeAll"
                                                    ToolTip="Altyazı Alanı (Sürükleyerek konumlandırabilirsin)"
                                                    MouseLeftButtonDown="CropBox_MouseDown"
                                                    MouseLeftButtonUp="CropBox_MouseUp"
                                                    MouseMove="CropBox_MouseMove"/>
                                        </Canvas>
                                        <!-- Boş durum: stream yok ya da bağlanıyor -->
                                        <StackPanel x:Name="PreviewIdlePanel" VerticalAlignment="Center" HorizontalAlignment="Center">
                                            <TextBlock x:Name="SubtitleRegionStatusText" Text="PS5 canlı görüntüsü bağlanınca altyazı bölgesini seçebilirsin." TextWrapping="Wrap" Foreground="#858FA2" FontSize="13" HorizontalAlignment="Center" VerticalAlignment="Center" Margin="18" TextAlignment="Center"/>
                                        </StackPanel>
                                    </Grid>
                                </Border>

                                <Grid Margin="0,12,0,0">
                                    <Grid.ColumnDefinitions>
                                        <ColumnDefinition Width="*"/>
                                        <ColumnDefinition Width="16"/>
                                        <ColumnDefinition Width="*"/>
                                    </Grid.ColumnDefinitions>
                                    <StackPanel>
                                        <Grid Margin="0,0,0,4">
                                            <TextBlock Text="Altyazı Konumu (Dikey)" FontSize="12" Foreground="{StaticResource MutedBrush}"/>
                                            <TextBlock x:Name="CropYLabel" Text="%75" FontSize="12" Foreground="#AFC3FF" FontWeight="SemiBold" HorizontalAlignment="Right"/>
                                        </Grid>
                                        <Slider x:Name="CropYSlider" Minimum="0" Maximum="85" Value="75" ValueChanged="CropYSlider_ValueChanged"/>
                                    </StackPanel>
                                    <StackPanel Grid.Column="2">
                                        <Grid Margin="0,0,0,4">
                                            <TextBlock Text="Altyazı Alanı Yüksekliği" FontSize="12" Foreground="{StaticResource MutedBrush}"/>
                                            <TextBlock x:Name="CropHeightLabel" Text="%20" FontSize="12" Foreground="#AFC3FF" FontWeight="SemiBold" HorizontalAlignment="Right"/>
                                        </Grid>
                                        <Slider x:Name="CropHeightSlider" Minimum="10" Maximum="50" Value="20" ValueChanged="CropHeightSlider_ValueChanged"/>
                                    </StackPanel>
                                </Grid>

                                <CheckBox x:Name="HideOriginalCheckBox"
                                          Content="Orijinal İngilizce altyazıyı gizle (Opak Siyah Bant Maskesi)"
                                          IsChecked="True"
                                          Foreground="#AFC3FF"
                                          FontSize="12"
                                          FontWeight="SemiBold"
                                          Margin="0,14,0,2"
                                          ToolTip="Arkadaki orijinal İngilizce yazının üzerine kapatıcı siyah bant çeker; yalnızca Türkçe çeviri görünür."/>

                                <Border Background="#0D1018" BorderBrush="#242C3D" BorderThickness="1" CornerRadius="10" Padding="14,12" Margin="0,12,0,0">
                                    <Grid>
                                        <Grid.RowDefinitions>
                                            <RowDefinition Height="Auto"/>
                                            <RowDefinition Height="Auto"/>
                                        </Grid.RowDefinitions>
                                        <Grid Grid.Row="0">
                                            <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                                                <Ellipse x:Name="LiveTranslationDot" Width="8" Height="8" Fill="#707B8D" VerticalAlignment="Center" Margin="0,0,8,0"/>
                                                <TextBlock x:Name="LiveTranslationStateText" Text="Çeviri kapalı" FontSize="12" FontWeight="SemiBold" Foreground="#858FA2"/>
                                            </StackPanel>
                                            <Border Background="#1C2436" CornerRadius="4" Padding="6,2" HorizontalAlignment="Right">
                                                <TextBlock x:Name="SettingsEngineBadgeText" Text="Opus-MT" FontSize="11" Foreground="#AFC3FF" FontWeight="SemiBold"/>
                                            </Border>
                                        </Grid>
                                        <TextBlock x:Name="LiveSubtitleText" Grid.Row="1" Text="Altyazı çevirisi burada canlı görünecek ve TV'ye aktarılacaktır." FontSize="15" FontWeight="SemiBold" Foreground="#3FCF8E" TextWrapping="Wrap" Margin="0,6,0,0"/>
                                    </Grid>
                                </Border>
                            </StackPanel>
                        </Border>

                        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,18,0,24">
                            <TextBlock x:Name="TranslationSettingsStatusText" Text="" Foreground="#5BDCA0" VerticalAlignment="Center" Margin="0,0,14,0"/>
                            <Button x:Name="ToggleLiveTranslationButton" Content="Çeviriyi Başlat" Style="{StaticResource PrimaryButton}" Background="#3FCF8E" Click="ToggleLiveTranslation_Click" Padding="20,11" Margin="0,0,12,0"/>
                            <Button Content="Ayarları kaydet" Style="{StaticResource SecondaryButton}" Click="SaveTranslationSettings_Click" Padding="18,11"/>
                        </StackPanel>
                        <Border Background="#111722" BorderBrush="#28344A" BorderThickness="1" CornerRadius="16" Padding="18" Margin="0,0,0,24">
                            <Grid>
                                <StackPanel VerticalAlignment="Center" Margin="0,0,180,0">
                                    <TextBlock Text="Kurulumu yeniden yap" FontSize="15" FontWeight="SemiBold"/>
                                    <TextBlock Text="PS5 eşleştirmesini sıfırlar ve ilk kurulum ekranına döner. Çeviri tercihleri korunur." TextWrapping="Wrap" Foreground="{StaticResource MutedBrush}" FontSize="12" Margin="0,5,0,0"/>
                                </StackPanel>
                                <Button Content="Kurulumu baştan yap" Style="{StaticResource SecondaryButton}" Click="RestartSetup_Click" HorizontalAlignment="Right" VerticalAlignment="Center" Padding="16,10"/>
                            </Grid>
                        </Border>
                    </StackPanel>
                </ScrollViewer>
            </Grid>
        </Grid>

        <Grid x:Name="WelcomeView" Grid.RowSpan="4" Panel.ZIndex="10" Background="#090B11">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <StackPanel Orientation="Horizontal" Margin="56,42,0,0" VerticalAlignment="Top">
                <Border Width="42" Height="42" CornerRadius="13" Background="#4267E8">
                    <TextBlock Text="N" FontSize="22" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
                <TextBlock Text="NOXIR" FontSize="20" FontWeight="Bold" Margin="12,0,0,0" VerticalAlignment="Center"/>
                <TextBlock Text="Play" FontSize="20" Foreground="#AFC3FF" Margin="6,0,0,0" VerticalAlignment="Center"/>
            </StackPanel>

            <StackPanel Grid.Row="1" Margin="72,24,72,32" VerticalAlignment="Center" HorizontalAlignment="Center" MaxWidth="620">
                <TextBlock Text="PS5 Translate" FontSize="14" FontWeight="SemiBold" Foreground="#AFC3FF"/>
                <TextBlock Text="Hoş geldin" FontSize="42" FontWeight="SemiBold" Margin="0,16,0,0"/>
                <TextBlock Text="PS5 oyunundaki altyazıları Türkçeye çevir ve oyunun keyfini kendi dilinde sürdür." TextWrapping="Wrap" FontSize="18" Foreground="#B5BDCC" LineHeight="29" Margin="0,14,0,0"/>
                <TextBlock Text="Önce PlayStation hesabınla güvenli şekilde bağlanacağız." TextWrapping="Wrap" FontSize="14" Foreground="#858FA2" Margin="0,22,0,0"/>
                <Button Content="İleri" Style="{StaticResource PrimaryButton}" Click="WelcomeNext_Click" HorizontalAlignment="Left" Margin="0,30,0,0" MinWidth="150"/>
            </StackPanel>

            <TextBlock Grid.Row="2" Text="NOXIR Play" FontSize="12" Foreground="#707B8D" HorizontalAlignment="Center" Margin="0,0,0,28"/>
        </Grid>

        <Grid x:Name="PsnConnectView" Grid.RowSpan="4" Panel.ZIndex="11" Background="#090B11" Visibility="Collapsed">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <StackPanel Orientation="Horizontal" Margin="56,42,0,0" VerticalAlignment="Top">
                <Border Width="42" Height="42" CornerRadius="13" Background="#4267E8">
                    <TextBlock Text="N" FontSize="22" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
                <TextBlock Text="NOXIR" FontSize="20" FontWeight="Bold" Margin="12,0,0,0" VerticalAlignment="Center"/>
                <TextBlock Text="Play" FontSize="20" Foreground="#AFC3FF" Margin="6,0,0,0" VerticalAlignment="Center"/>
            </StackPanel>

            <Grid Grid.Row="1" Margin="40,0">
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="360"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0" VerticalAlignment="Center" Margin="0,0,24,0">
                    <TextBlock Text="1 / 2 · PlayStation hesabı" FontSize="14" FontWeight="SemiBold" Foreground="#AFC3FF"/>
                    <TextBlock Text="PlayStation hesabına bağlan" FontSize="28" FontWeight="SemiBold" Margin="0,16,0,0"/>
                    <TextBlock Text="PlayStation'ın kendi giriş sayfası aşağıda NOXIR Play penceresi içinde açılır. Parolanı NOXIR Play'e yazma; giriş bilgilerin PlayStation'da kalır." TextWrapping="Wrap" FontSize="14" Foreground="#B5BDCC" LineHeight="23" Margin="0,14,0,0"/>
                    <Border Background="#111722" BorderBrush="#28344A" BorderThickness="1" CornerRadius="16" Padding="18" Margin="0,24,0,0">
                        <StackPanel>
                            <TextBlock Text="Durum" FontSize="13" FontWeight="SemiBold" Foreground="#E8ECF5"/>
                            <TextBlock x:Name="PsnConnectionStatusText" Text="PlayStation giriş sayfası henüz açılmadı." TextWrapping="Wrap" FontSize="13" Foreground="#858FA2" Margin="0,7,0,0"/>
                        </StackPanel>
                    </Border>
                    <StackPanel Orientation="Horizontal" Margin="0,20,0,0">
                        <Button Content="İleri" Style="{StaticResource PrimaryButton}" Click="PsnNext_Click" Padding="14,10"/>
                        <Button Content="Sayfayı yenile" Style="{StaticResource SecondaryButton}" Click="ReloadPsnPage_Click" Margin="12,0,0,0" Padding="14,10"/>
                        <Button Content="Geri" Style="{StaticResource SecondaryButton}" Click="PsnBack_Click" Margin="12,0,0,0" Padding="14,10"/>
                    </StackPanel>
                    <TextBlock Text="Giriş tamamlandığında durum burada güncellenir. NOXIR Play parolanı okumaz veya kaydetmez." TextWrapping="Wrap" FontSize="11" Foreground="#707B8D" Margin="0,16,0,0"/>
                </StackPanel>
                <Border Grid.Column="1" Background="#0D1018" BorderBrush="#272D3A" BorderThickness="1" CornerRadius="18" Padding="4">
                    <wv2:WebView2 x:Name="PsnWebView"/>
                </Border>
            </Grid>

            <TextBlock Grid.Row="2" Text="NOXIR Play" FontSize="12" Foreground="#707B8D" HorizontalAlignment="Center" Margin="0,0,0,28"/>
        </Grid>

        <Grid x:Name="Ps5ConnectView" Grid.RowSpan="4" Panel.ZIndex="12" Background="#090B11" Visibility="Collapsed">
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <StackPanel Orientation="Horizontal" Margin="56,42,0,0" VerticalAlignment="Top">
                <Border Width="42" Height="42" CornerRadius="13" Background="#4267E8">
                    <TextBlock Text="N" FontSize="22" FontWeight="Bold" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
                <TextBlock Text="NOXIR" FontSize="20" FontWeight="Bold" Margin="12,0,0,0" VerticalAlignment="Center"/>
                <TextBlock Text="Play" FontSize="20" Foreground="#AFC3FF" Margin="6,0,0,0" VerticalAlignment="Center"/>
            </StackPanel>
            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                <StackPanel Margin="72,24,72,32" HorizontalAlignment="Center" MaxWidth="620">
                    <StackPanel Orientation="Horizontal">
                        <Border x:Name="StepPsnPill" Background="#141822" BorderBrush="#2C3548" BorderThickness="1" CornerRadius="14" Padding="12,5">
                            <TextBlock x:Name="StepPsnText" Text="1  PlayStation hesabı" FontSize="12" FontWeight="SemiBold" Foreground="#9299AA"/>
                        </Border>
                        <Border Width="22" Height="2" Background="#2C3548" VerticalAlignment="Center" Margin="8,0"/>
                        <Border Background="#211C36" BorderBrush="#8567F5" BorderThickness="1" CornerRadius="14" Padding="12,5">
                            <TextBlock Text="2  PS5 bağlantısı" FontSize="12" FontWeight="SemiBold" Foreground="#CFC4FF"/>
                        </Border>
                    </StackPanel>
                    <TextBlock Text="PS5'i ekle" FontSize="34" FontWeight="SemiBold" Margin="0,20,0,0"/>
                    <TextBlock Text="Aynı yerel ağdaki PS5'in IP adresini ve Remote Play eşleştirme kodunu gir. PS5'te: Ayarlar → Sistem → Uzaktan Oynatma → Cihazı Bağla." TextWrapping="Wrap" FontSize="15" Foreground="#B5BDCC" LineHeight="25" Margin="0,12,0,0"/>

                    <Border Background="#111722" BorderBrush="#28344A" BorderThickness="1" CornerRadius="18" Padding="24" Margin="0,24,0,0">
                        <StackPanel>
                            <Grid>
                                <Grid.ColumnDefinitions>
                                    <ColumnDefinition Width="1.15*"/>
                                    <ColumnDefinition Width="16"/>
                                    <ColumnDefinition Width="*"/>
                                </Grid.ColumnDefinitions>
                                <StackPanel Grid.Column="0">
                                    <TextBlock Text="PS5 IP adresi" Style="{StaticResource FieldLabel}"/>
                                    <TextBox x:Name="Ps5IpBox" Style="{StaticResource FieldBox}" Tag="192.168.1.50"/>
                                    <TextBlock Text="PS5'te Ayarlar → Ağ → Bağlantı Durumu'nda yazar." Style="{StaticResource FieldHelp}"/>
                                </StackPanel>
                                <StackPanel Grid.Column="2">
                                    <TextBlock Text="Eşleştirme kodu (8 hane)" Style="{StaticResource FieldLabel}"/>
                                    <TextBox x:Name="Ps5PinBox" Style="{StaticResource FieldBox}" Tag="12345678" MaxLength="8" FontFamily="Consolas" FontSize="17"/>
                                    <TextBlock Text="Kod birkaç dakika geçerli, dolarsa yenisini al." Style="{StaticResource FieldHelp}"/>
                                </StackPanel>
                            </Grid>

                        </StackPanel>
                    </Border>

                    <Border Background="#111722" BorderBrush="#28344A" BorderThickness="1" CornerRadius="16" Padding="20,16" Margin="0,18,0,0">
                        <StackPanel>
                            <StackPanel Orientation="Horizontal">
                                <Ellipse x:Name="Ps5StatusDot" Width="8" Height="8" Fill="#8567F5" VerticalAlignment="Center" Margin="0,0,9,0"/>
                                <TextBlock Text="Durum" FontSize="13" FontWeight="SemiBold" Foreground="#E8ECF5"/>
                            </StackPanel>
                            <TextBlock x:Name="Ps5StatusText" Text="PS5 bilgileri bekleniyor." TextWrapping="Wrap" FontSize="13" Foreground="#B5BDCC" Margin="17,8,0,0"/>
                        </StackPanel>
                    </Border>

                    <StackPanel Orientation="Horizontal" Margin="0,24,0,0">
                        <Button x:Name="VerifyPs5Button" Content="PS5'i eşleştir" Style="{StaticResource PrimaryButton}" Click="VerifyPs5_Click"/>
                        <Button x:Name="ContinueAfterPairingButton" Content="İleri" Style="{StaticResource PrimaryButton}" Click="ContinueAfterPairing_Click" Margin="12,0,0,0" Visibility="Collapsed"/>
                        <Button Content="Geri" Style="{StaticResource SecondaryButton}" Click="Ps5Back_Click" Margin="12,0,0,0"/>
                    </StackPanel>
                    <TextBlock Text="PSN hesabı girişinden alınan AccountID ve bu kod PS5'in Remote Play kaydında kullanılır." TextWrapping="Wrap" FontSize="11" Foreground="#707B8D" Margin="0,16,0,0"/>
                </StackPanel>
            </ScrollViewer>
            <TextBlock Grid.Row="2" Text="NOXIR Play" FontSize="12" Foreground="#707B8D" HorizontalAlignment="Center" Margin="0,0,0,28"/>
        </Grid>
    </Grid>
</Window>
```

#### 13. `pc/NoxirPlay.PC/MainWindow.xaml.cs`

```csharp
using Microsoft.Web.WebView2.Core;
using Microsoft.Web.WebView2.Wpf;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Web;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace NoxirPlay.PC;

public partial class MainWindow : Window
{
    private readonly ChiakiPs5RegistrationService _ps5Registration = new();
    private readonly TranslationSettingsService _translationSettingsService = new();
    private readonly RemotePlayService _remotePlay = new();
    private RegisteredPs5? _registeredPs5;
    private TranslationSettings? _translationSettings;
    private bool _psnWebViewInitialized;
    // _previewActive kaldırıldı — preview mantığı artık sadece _remotePlay.IsRunning + panel visibility'ye bağlı
    private volatile BitmapSource? _latestFrame;
    private CancellationTokenSource? _liveTranslationCts;
    private bool _isLiveTranslating;

    private double _cropYPercent = 0.70;
    private double _cropHeightPercent = 0.25;
    private double _cropXPercent = 0.05;
    private double _cropWidthPercent = 0.90;
    private bool _isDraggingCrop;
    private bool _isUpdatingCropUI;
    private Point _dragStartPoint;
    private double _dragStartYPercent;

    private string _cachedSourceLang = "Otomatik algıla";
    private string _cachedTargetLang = "Türkçe";
    private string _cachedService = "NOXIR Opus-MT (Oyun Çevirisi)";
    private string _cachedOcrEngine = "RapidOCR PP-OCRv6 Tiny (Çok Hızlı)";
    private string _cachedApiKey = string.Empty;
    private bool _cachedHideOriginal = true;

    // --- PSN OAuth (Remote Play Windows istemcisinin herkese açık değerleri, Chiaki ile aynı) ---
    private const string PsnClientId = "ba495a24-818c-472b-b12d-ff231c1b5745";
    private const string PsnClientSecret = "mvaiZkRsAsI1IBkY";
    private const string PsnRedirectPrefix = "https://remoteplay.dl.playstation.net/remoteplay/redirect";
    private const string PsnTokenUrl = "https://auth.api.sonyentertainmentnetwork.com/2.0/oauth/token";
    private const string PsnLoginUrl =
        "https://auth.api.sonyentertainmentnetwork.com/2.0/oauth/authorize?service_entity=urn:service-entity:psn&response_type=code&client_id="
        + PsnClientId + "&redirect_uri=" + PsnRedirectPrefix
        + "&scope=psn:clientapp&request_locale=en_US&ui=pr&service_logo=ps&layout_type=popup&smcid=remoteplay&prompt=always&PlatformPrivacyWs1=minimal&";

    private string? _psnAccountId;
    private bool _psnLoginInProgress;

    public MainWindow()
    {
        InitializeComponent();
        _remotePlay.PreviewFrame += UpdateSubtitleRegionPreview;
        _remotePlay.VideoStreamStarted += () =>
        {
            Dispatcher.BeginInvoke(() =>
            {
                HomePs5StatusText.Text = $"PS5 canlı görüntüsü aktarılıyor. TV'de {_remotePlay.TvAddress}:8765 ve kod {_remotePlay.TvPairCode} ile bağlan.";
                HomePs5StatusDot.Fill = MakeBrush("#3FCF8E");
            });
        };
        _remotePlay.StreamFaulted += err =>
        {
            Dispatcher.BeginInvoke(() =>
            {
                HomePs5StatusText.Text = "Yayın uyarısı: " + err;
                HomePs5StatusDot.Fill = MakeBrush("#F0566A");
            });
        };
        _translationSettings = _translationSettingsService.Load();
        SelectComboItem(OcrEngineBox, _translationSettings.OcrEngine);
        SelectComboItem(TranslationServiceBox, _translationSettings.TranslationService);
        SelectComboItem(SourceLanguageBox, _translationSettings.SourceLanguage);
        SelectComboItem(TargetLanguageBox, _translationSettings.TargetLanguage);
        TranslationApiKeyBox.Password = _translationSettings.ApiKey;
        UpdateApiKeyVisibility();

        _cropYPercent = _translationSettings.CropYPercent;
        _cropHeightPercent = _translationSettings.CropHeightPercent;
        _cropXPercent = _translationSettings.CropXPercent;
        _cropWidthPercent = _translationSettings.CropWidthPercent;
        if (HideOriginalCheckBox is not null) HideOriginalCheckBox.IsChecked = _translationSettings.HideOriginalText;
        _cachedHideOriginal = _translationSettings.HideOriginalText;
        if (CropYSlider is not null) CropYSlider.Value = _cropYPercent * 100;
        if (CropHeightSlider is not null) CropHeightSlider.Value = _cropHeightPercent * 100;
        UpdateCropBoxUI();
    }

    private void TranslationServiceBox_SelectionChanged(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
    {
        UpdateApiKeyVisibility();
    }

    private void UpdateApiKeyVisibility()
    {
        if (ApiKeyContainer is null || TranslationServiceBox is null) return;
        var selected = SelectedComboText(TranslationServiceBox);
        ApiKeyContainer.Visibility = string.Equals(selected, "DeepL API", StringComparison.OrdinalIgnoreCase)
            ? Visibility.Visible
            : Visibility.Collapsed;
    }

    private async void Window_Loaded(object sender, RoutedEventArgs e)
    {
        // AI ve OCR motorlarını uygulama açılır açılmaz arka planda ısıt (ilk karede anında çeviri)
        _ = Task.Run(AiBridgeService.EnsureBridgeRunningAsync);

        _registeredPs5 = _ps5Registration.LoadRegistration();
        if (_registeredPs5 is not null)
        {
            WelcomeView.Visibility = Visibility.Collapsed;
            MainContent.Visibility = Visibility.Visible;
            SetHomePs5Status(_registeredPs5);
        }
        else
        {
            MainContent.Visibility = Visibility.Collapsed;
        }
    }

    private async Task InitializePsnWebViewAsync()
    {
        if (_psnWebViewInitialized) return;
        try
        {
            PsnConnectionStatusText.Text = "PSN giriş sayfası yükleniyor…";
            var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
            if (string.IsNullOrWhiteSpace(localAppData))
                throw new InvalidOperationException("Windows kullanıcı profili bulunamadı; WebView2 profil klasörü oluşturulamadı.");

            var webViewProfile = Path.Combine(localAppData, "NOXIR Play", "WebView2");
            Directory.CreateDirectory(webViewProfile);
            var env = await CoreWebView2Environment.CreateAsync(userDataFolder: webViewProfile);
            await PsnWebView.EnsureCoreWebView2Async(env);

            PsnWebView.CoreWebView2.NavigationStarting += async (_, args) =>
            {
                // Giriş bitince Sony, remoteplay redirect adresine yönlendirir; code parametresi burada gelir.
                if (args.Uri.StartsWith(PsnRedirectPrefix, StringComparison.OrdinalIgnoreCase))
                {
                    args.Cancel = true; // Bu sayfayı gösterme, sadece code'u al
                    var code = HttpUtility.ParseQueryString(new Uri(args.Uri).Query)["code"];
                    if (string.IsNullOrEmpty(code))
                    {
                        PsnConnectionStatusText.Text = "Giriş tamamlanamadı: code gelmedi.";
                        return;
                    }
                    await CompletePsnLoginAsync(code);
                    return;
                }

                if (!_psnLoginInProgress && _psnAccountId is null)
                    PsnConnectionStatusText.Text = "PSN sayfası açılıyor…";
            };

            PsnWebView.CoreWebView2.NavigationCompleted += (_, args) =>
            {
                // Redirect'i kendimiz iptal ettiğimiz için buraya OperationCanceled düşer, durum yazısını bozma.
                if (_psnLoginInProgress || _psnAccountId is not null) return;
                if (args.WebErrorStatus == CoreWebView2WebErrorStatus.OperationCanceled) return;

                PsnConnectionStatusText.Text = args.IsSuccess
                    ? "PSN giriş sayfası yüklendi. Giriş bekleniyor…"
                    : "PSN sayfası yüklenemedi (" + args.WebErrorStatus + "). İnternet bağlantısını kontrol et.";
            };

            PsnWebView.CoreWebView2.WebMessageReceived += (_, _) => { };
            PsnWebView.Source = new Uri(PsnLoginUrl);
            _psnWebViewInitialized = true;
        }
        catch (Exception ex)
        {
            PsnConnectionStatusText.Text = "Gömülü tarayıcı başlatılamadı: " + ex.Message;
        }
    }

    private async Task CompletePsnLoginAsync(string code)
    {
        if (_psnLoginInProgress) return;
        _psnLoginInProgress = true;
        try
        {
            PsnConnectionStatusText.Text = "Giriş alındı, hesap doğrulanıyor…";
            _psnAccountId = await GetPsnAccountIdAsync(code);

            ApplyAccountIdToForm();
            PsnConnectionStatusText.Text = "PSN hesabı doğrulandı. PS5 eşleştirme adımına geçiliyor…";
            PsnConnectView.Visibility = Visibility.Collapsed;
            Ps5ConnectView.Visibility = Visibility.Visible;
            SetPs5Status("PSN hesabı doğrulandı. PS5 IP adresini ve 8 haneli cihaz bağlama kodunu gir.");
        }
        catch (Exception ex)
        {
            PsnConnectionStatusText.Text = "PSN girişi başarısız: " + ex.Message;
        }
        finally
        {
            _psnLoginInProgress = false;
        }
    }

    private static async Task<string> GetPsnAccountIdAsync(string code)
    {
        using var http = new HttpClient();
        var basic = Convert.ToBase64String(Encoding.ASCII.GetBytes($"{PsnClientId}:{PsnClientSecret}"));
        http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Basic", basic);

        // 1) code -> access_token
        var tokenResp = await http.PostAsync(PsnTokenUrl, new FormUrlEncodedContent(new Dictionary<string, string>
        {
            ["grant_type"] = "authorization_code",
            ["code"] = code,
            ["redirect_uri"] = PsnRedirectPrefix
        }));
        if (!tokenResp.IsSuccessStatusCode)
            throw new Exception($"Token isteği reddedildi ({(int)tokenResp.StatusCode})");

        using var tokenJson = JsonDocument.Parse(await tokenResp.Content.ReadAsStringAsync());
        if (!tokenJson.RootElement.TryGetProperty("access_token", out var tokenEl) || tokenEl.GetString() is not { Length: > 0 } accessToken)
            throw new Exception("Cevapta access_token yok");

        // 2) access_token -> hesap bilgisi (user_id)
        var infoResp = await http.GetAsync($"{PsnTokenUrl}/{Uri.EscapeDataString(accessToken)}");
        if (!infoResp.IsSuccessStatusCode)
            throw new Exception($"Hesap bilgisi alınamadı ({(int)infoResp.StatusCode})");

        using var info = JsonDocument.Parse(await infoResp.Content.ReadAsStringAsync());
        if (!info.RootElement.TryGetProperty("user_id", out var idEl))
            throw new Exception("Cevapta user_id yok");

        ulong userId = ulong.Parse(idEl.ValueKind == JsonValueKind.String ? idEl.GetString()! : idEl.GetRawText(), System.Globalization.CultureInfo.InvariantCulture);

        // 3) AccountID = user_id'nin 8 bayt little-endian hali, base64
        var bytes = new byte[sizeof(ulong)];
        System.Buffers.Binary.BinaryPrimitives.WriteUInt64LittleEndian(bytes, userId);
        return Convert.ToBase64String(bytes);
    }

    private void ReloadPsnPage_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            // Yeniden yüklemede giriş sayfasına dön (redirect sayfasında kalmış olabilir)
            _psnAccountId = null;
            if (PsnWebView?.CoreWebView2 is not null)
                PsnWebView.CoreWebView2.Navigate(PsnLoginUrl);
            else
                PsnWebView?.Reload();
            PsnConnectionStatusText.Text = "PSN sayfası yeniden yükleniyor…";
        }
        catch (Exception ex)
        {
            PsnConnectionStatusText.Text = "Sayfa yenilenemedi: " + ex.Message;
        }
    }

    private void OpenPlayStationLogin_Click(object sender, RoutedEventArgs e)
    {
        // Backwards compatible: focus embedded view instead of external browser
        try
        {
            PsnWebView?.Focus();
            PsnConnectionStatusText.Text = "PSN giriş sayfası NOXIR Play içinde açıldı.";
        }
        catch (Exception ex)
        {
            PsnConnectionStatusText.Text = "Gömülü tarayıcıya geçilemedi: " + ex.Message;
        }
    }

    private async void WelcomeNext_Click(object sender, RoutedEventArgs e)
    {
        WelcomeView.Visibility = Visibility.Collapsed;
        PsnConnectView.Visibility = Visibility.Visible;
        await InitializePsnWebViewAsync();
    }

    private void PsnNext_Click(object sender, RoutedEventArgs e)
    {
        if (string.IsNullOrWhiteSpace(_psnAccountId))
        {
            PsnConnectionStatusText.Text = "Önce bu penceredeki PSN girişini tamamla.";
            return;
        }

        PsnConnectView.Visibility = Visibility.Collapsed;
        Ps5ConnectView.Visibility = Visibility.Visible;
        ApplyAccountIdToForm();
        SetPs5Status("PS5 IP adresini ve 8 haneli cihaz bağlama kodunu gir.");
    }

    private static SolidColorBrush MakeBrush(string hex) =>
        new SolidColorBrush((Color)ColorConverter.ConvertFromString(hex));

    // Durum kartındaki yazıyı ve yanındaki renkli noktayı günceller.
    // kind: "info" (mor), "work" (sarı), "ok" (yeşil), "error" (kırmızı)
    private void SetPs5Status(string text, string kind = "info")
    {
        Ps5StatusText.Text = text;
        Ps5StatusDot.Fill = MakeBrush(kind switch
        {
            "ok" => "#3FCF8E",
            "error" => "#F0566A",
            "work" => "#E0B341",
            _ => "#8567F5"
        });
    }

    // PSN girişinin tamamlandığını adım göstergesinde belirtir.
    private void ApplyAccountIdToForm()
    {
        var loggedIn = !string.IsNullOrEmpty(_psnAccountId);
        StepPsnText.Text = loggedIn ? "✓  PlayStation hesabı" : "1  PlayStation hesabı";
        StepPsnText.Foreground = MakeBrush(loggedIn ? "#5BDCA0" : "#9299AA");
        StepPsnPill.Background = MakeBrush(loggedIn ? "#12281F" : "#141822");
        StepPsnPill.BorderBrush = MakeBrush(loggedIn ? "#245A3E" : "#2C3548");
    }

    private void PsnBack_Click(object sender, RoutedEventArgs e)
    {
        PsnConnectView.Visibility = Visibility.Collapsed;
        WelcomeView.Visibility = Visibility.Visible;
    }

    private void Ps5Back_Click(object sender, RoutedEventArgs e)
    {
        Ps5ConnectView.Visibility = Visibility.Collapsed;
        PsnConnectView.Visibility = Visibility.Visible;
    }

    private async void VerifyPs5_Click(object sender, RoutedEventArgs e)
    {
        var ip = Ps5IpBox.Text.Trim();
        var pin = Ps5PinBox.Text.Trim();

        if (!System.Net.IPAddress.TryParse(ip, out var address) || address.AddressFamily != System.Net.Sockets.AddressFamily.InterNetwork)
        {
            SetPs5Status("Geçersiz IP adresi. Örnek: 192.168.1.50", "error");
            return;
        }
        if (pin.Length != 8 || !pin.All(char.IsDigit))
        {
            SetPs5Status("Eşleştirme kodu 8 haneli sayı olmalı (PS5: Ayarlar → Sistem → Uzaktan Oynatma → Cihazı Bağla).", "error");
            return;
        }
        if (string.IsNullOrWhiteSpace(_psnAccountId))
        {
            SetPs5Status("PSN AccountID alınamadı. PSN girişini tamamlayıp yeniden dene.", "error");
            return;
        }

        VerifyPs5Button.IsEnabled = false;
        SetPs5Status("PS5 Remote Play kaydı yapılıyor…", "work");
        try
        {
            var registration = await _ps5Registration.RegisterPs5Async(address.ToString(), pin, _psnAccountId);
            _registeredPs5 = registration;
            SetPs5Status(string.IsNullOrWhiteSpace(registration.Nickname)
                ? $"PS5, {registration.IpAddress} adresinde Remote Play için eşleştirildi. Kayıt bilgileri güvenli şekilde saklandı."
                : $"{registration.Nickname} adlı PS5 Remote Play için eşleştirildi. Kayıt bilgileri güvenli şekilde saklandı.", "ok");
            VerifyPs5Button.Content = "Yeniden eşleştir";
            ContinueAfterPairingButton.Visibility = Visibility.Visible;
        }
        catch (Exception ex)
        {
            SetPs5Status("PS5 eşleştirilemedi: " + ex.Message, "error");
        }
        finally
        {
            VerifyPs5Button.IsEnabled = true;
        }
    }

    private void ContinueAfterPairing_Click(object sender, RoutedEventArgs e)
    {
        if (_registeredPs5 is null) return;
        Ps5ConnectView.Visibility = Visibility.Collapsed;
        MainContent.Visibility = Visibility.Visible;
        HomeView.Visibility = Visibility.Visible;
        TranslationSettingsView.Visibility = Visibility.Collapsed;
        SetHomePs5Status(_registeredPs5);
    }

    private void SetHomePs5Status(RegisteredPs5 registration)
    {
        var consoleName = string.IsNullOrWhiteSpace(registration.Nickname) ? "PS5" : registration.Nickname;
        HomePs5StatusText.Text = $"PS5 bağlantısı: {consoleName} eşleştirildi";
        HomePs5StatusDot.Fill = MakeBrush("#3FCF8E");
        if (!_remotePlay.IsRunning) TranslateButton.Content = "PS5 görüntüsünü başlat";
    }

    private void OpenTranslationSettings_Click(object sender, RoutedEventArgs e)
    {
        HomeView.Visibility = Visibility.Collapsed;
        TranslationSettingsView.Visibility = Visibility.Visible;
        UpdateCropBoxUI();

        if (_latestFrame is not null)
        {
            ShowLatestFrameInPreview();
        }
        else if (_remotePlay.IsRunning)
        {
            SubtitleRegionStatusText.Text = "PS5 oturumu açık. Video akışı bekleniyor — birkaç saniye sonra görüntü gelecek…";
            SubtitleRegionStatusText.Visibility = Visibility.Visible;
            if (PreviewIdlePanel is not null) PreviewIdlePanel.Visibility = Visibility.Visible;
            SubtitleRegionPreviewImage.Visibility = Visibility.Collapsed;
            CropCanvas.Visibility = Visibility.Collapsed;
        }
        else
        {
            SubtitleRegionStatusText.Text = SubtitleRegionIdleText;
            SubtitleRegionStatusText.Visibility = Visibility.Visible;
            if (PreviewIdlePanel is not null) PreviewIdlePanel.Visibility = Visibility.Visible;
            SubtitleRegionPreviewImage.Visibility = Visibility.Collapsed;
            CropCanvas.Visibility = Visibility.Collapsed;
        }
    }

    private void CloseTranslationSettings_Click(object sender, RoutedEventArgs e)
    {
        TranslationSettingsView.Visibility = Visibility.Collapsed;
        HomeView.Visibility = Visibility.Visible;
    }

    private void SaveTranslationSettings_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var settings = new TranslationSettings(
                OcrEngine: SelectedComboText(OcrEngineBox),
                TranslationService: SelectedComboText(TranslationServiceBox),
                SourceLanguage: SelectedComboText(SourceLanguageBox),
                TargetLanguage: SelectedComboText(TargetLanguageBox),
                ApiKey: TranslationApiKeyBox.Password.Trim(),
                CropYPercent: _cropYPercent,
                CropHeightPercent: _cropHeightPercent,
                CropXPercent: _cropXPercent,
                CropWidthPercent: _cropWidthPercent,
                HideOriginalText: HideOriginalCheckBox?.IsChecked ?? true);
            _cachedHideOriginal = settings.HideOriginalText;
            _translationSettingsService.Save(settings);
            _translationSettings = settings;
            TranslationSettingsStatusText.Text = "Ayarlar şifreli olarak kaydedildi.";
        }
        catch (Exception ex)
        {
            TranslationSettingsStatusText.Text = "Kaydedilemedi: " + ex.Message;
            TranslationSettingsStatusText.Foreground = MakeBrush("#F0566A");
        }
    }

    private async void RestartSetup_Click(object sender, RoutedEventArgs e)
    {
        var answer = MessageBox.Show(
            "PS5 eşleştirme kaydı silinecek ve ilk kurulum ekranına dönülecek. Çeviri ayarların korunacak. Devam edilsin mi?",
            "Kurulumu yeniden yap",
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);
        if (answer != MessageBoxResult.Yes) return;

        try
        {
            await _remotePlay.StopAsync();
            _translationSettingsService.Save(new TranslationSettings(
                OcrEngine: SelectedComboText(OcrEngineBox),
                TranslationService: SelectedComboText(TranslationServiceBox),
                SourceLanguage: SelectedComboText(SourceLanguageBox),
                TargetLanguage: SelectedComboText(TargetLanguageBox),
                ApiKey: TranslationApiKeyBox.Password.Trim()));
            _ps5Registration.ClearRegistration();
            _registeredPs5 = null;
            _psnAccountId = null;
            Ps5IpBox.Clear();
            Ps5PinBox.Clear();
            VerifyPs5Button.Content = "PS5'i eşleştir";
            ContinueAfterPairingButton.Visibility = Visibility.Collapsed;
            SetPs5Status("PS5 bilgileri bekleniyor.");

            MainContent.Visibility = Visibility.Collapsed;
            PsnConnectView.Visibility = Visibility.Collapsed;
            Ps5ConnectView.Visibility = Visibility.Collapsed;
            WelcomeView.Visibility = Visibility.Visible;

            if (_psnWebViewInitialized && PsnWebView.CoreWebView2 is not null)
            {
                PsnWebView.CoreWebView2.Navigate(PsnLoginUrl);
                PsnConnectionStatusText.Text = "Kurulum yeniden başlatıldı. PlayStation hesabına bağlan.";
            }
        }
        catch (Exception ex)
        {
            MessageBox.Show("Kurulum yeniden başlatılamadı: " + ex.Message, "NOXIR Play", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private static string SelectedComboText(System.Windows.Controls.ComboBox combo)
    {
        return combo.SelectedItem is System.Windows.Controls.ComboBoxItem item
            ? item.Content?.ToString() ?? string.Empty
            : string.Empty;
    }

    private static void SelectComboItem(System.Windows.Controls.ComboBox combo, string value)
    {
        foreach (var item in combo.Items)
        {
            if (item is System.Windows.Controls.ComboBoxItem option &&
                string.Equals(option.Content?.ToString(), value, StringComparison.OrdinalIgnoreCase))
            {
                combo.SelectedItem = item;
                return;
            }
        }
        if (combo.Items.Count > 0 && combo.SelectedIndex < 0)
        {
            combo.SelectedIndex = 0;
        }
    }

    private void TranslateButton_Click(object sender, RoutedEventArgs e)
    {
        if (_registeredPs5 is null)
        {
            HomePs5StatusText.Text = "PS5 eşleştirmesi gerekli";
            HomePs5StatusDot.Fill = MakeBrush("#E0B341");
            return;
        }
        _ = ToggleRemotePlayAsync();
    }

    private async Task ToggleRemotePlayAsync()
    {
        TranslateButton.IsEnabled = false;
        try
        {
            if (_remotePlay.IsRunning)
            {
                await _remotePlay.StopAsync();
                TranslateButton.Content = "PS5 görüntüsünü başlat";
                ClearSubtitleRegionPreview();
                SetHomePs5Status(_registeredPs5!);
                return;
            }

            HomePs5StatusText.Text = "PS5 Remote Play oturumu başlatılıyor…";
            HomePs5StatusDot.Fill = MakeBrush("#E0B341");
            await _remotePlay.StartAsync(_registeredPs5!);
            TranslateButton.Content = "Görüntü aktarımını durdur";
            HomePs5StatusText.Text = $"PS5 görüntüsü aktarılıyor. TV'de { _remotePlay.TvAddress }:8765 ve kod {_remotePlay.TvPairCode} ile bağlan.";
            HomePs5StatusDot.Fill = MakeBrush("#3FCF8E");
            SubtitleRegionStatusText.Text = "PS5 oturumu açık. Video akışı bekleniyor — birkaç saniye sonra görüntü gelecek…";
        }
        catch (Exception ex)
        {
            HomePs5StatusText.Text = "PS5 görüntüsü başlatılamadı: " + ex.Message;
            HomePs5StatusDot.Fill = MakeBrush("#F0566A");
        }
        finally
        {
            TranslateButton.IsEnabled = true;
        }
    }

    private const string SubtitleRegionIdleText = "PS5 canlı görüntüsü bağlanınca altyazı bölgesini seçebilirsin.";
    private long _lastPreviewUiTicks;

    /// <summary>
    /// Ayarlar ekranındaki altyazı bölgesi kutusuna bir PS5 karesi çizer.
    /// RemotePlayService kare ürettiğinde bu metodu çağırması yeterli; hangi thread'den çağrılırsa çağrılsın güvenlidir.
    /// PS5 stream aktif olduğu sürece frame'leri her zaman kaydeder;
    /// ayarlar paneli açık değilse UI güncellemesi yapmaz ama frame arabelleğe alınır.
    /// </summary>
    public void UpdateSubtitleRegionPreview(BitmapSource frame)
    {
        // Frame'i her zaman kaydet (stream aktif olduğu sürece)
        if (!frame.IsFrozen && frame.CanFreeze) frame.Freeze();
        _latestFrame = frame;

        // UI önizlemesini ~24 FPS (~42ms) ile sınırla (UI kilitlenmelerini önler)
        var nowTicks = Environment.TickCount64;
        var previousTicks = Interlocked.Read(ref _lastPreviewUiTicks);
        if (nowTicks - previousTicks < 42) return;
        Interlocked.Exchange(ref _lastPreviewUiTicks, nowTicks);

        var captured = frame;
        if (Dispatcher.CheckAccess()) RenderPreviewFrame(captured);
        else Dispatcher.BeginInvoke(() => RenderPreviewFrame(captured));
    }

    private void RenderPreviewFrame(BitmapSource frame)
    {
        // Ayarlar paneli açık değilse gösterme
        var isSettingsOpen = TranslationSettingsView.Visibility == Visibility.Visible;
        if (!isSettingsOpen) return;

        SubtitleRegionPreviewImage.Source = frame;
        SubtitleRegionPreviewImage.Stretch = Stretch.Uniform;
        SubtitleRegionPreviewImage.Visibility = Visibility.Visible;
        // "Bağlanıyor" yazısını ve boş durum panelini kapat
        SubtitleRegionStatusText.Visibility = Visibility.Collapsed;
        if (PreviewIdlePanel is not null) PreviewIdlePanel.Visibility = Visibility.Collapsed;
        CropCanvas.Visibility = Visibility.Visible;
        UpdateCropBoxUI();
    }

    /// <summary>
    /// Ayarlar paneli açıldığında son alınan PS5 frame'ini hemen gösterir.
    /// </summary>
    private void ShowLatestFrameInPreview()
    {
        var frame = _latestFrame;
        if (frame is null) return;
        RenderPreviewFrame(frame);
    }

    private void ClearSubtitleRegionPreview()
    {
        _latestFrame = null;
        Interlocked.Exchange(ref _lastPreviewUiTicks, 0);
        StopLiveTranslation();
        SubtitleRegionPreviewImage.Source = null;
        SubtitleRegionPreviewImage.Visibility = Visibility.Collapsed;
        CropCanvas.Visibility = Visibility.Collapsed;
        SubtitleRegionStatusText.Text = SubtitleRegionIdleText;
        SubtitleRegionStatusText.Visibility = Visibility.Visible;
        // Boş durum panelini göster
        if (PreviewIdlePanel is not null) PreviewIdlePanel.Visibility = Visibility.Visible;
    }

    private void PreviewContainerBorder_SizeChanged(object sender, SizeChangedEventArgs e)
    {
        UpdateCropBoxUI();
    }

    private void CropYSlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (_isDraggingCrop) return;
        _cropYPercent = e.NewValue / 100.0;
        if (_cropYPercent + _cropHeightPercent > 1.0)
            _cropYPercent = Math.Max(0, 1.0 - _cropHeightPercent);
        UpdateCropBoxUI();
    }

    private void CropHeightSlider_ValueChanged(object sender, RoutedPropertyChangedEventArgs<double> e)
    {
        if (_isDraggingCrop) return;
        _cropHeightPercent = e.NewValue / 100.0;
        if (_cropYPercent + _cropHeightPercent > 1.0)
            _cropYPercent = Math.Max(0, 1.0 - _cropHeightPercent);
        UpdateCropBoxUI();
    }

    private void CropBox_MouseDown(object sender, MouseButtonEventArgs e)
    {
        _isDraggingCrop = true;
        _dragStartPoint = e.GetPosition(PreviewContainerBorder);
        _dragStartYPercent = _cropYPercent;
        CropBox.CaptureMouse();
    }

    private void CropBox_MouseMove(object sender, MouseEventArgs e)
    {
        if (!_isDraggingCrop) return;
        var currentPoint = e.GetPosition(PreviewContainerBorder);
        var deltaY = currentPoint.Y - _dragStartPoint.Y;
        var containerHeight = PreviewContainerBorder.ActualHeight;
        if (containerHeight <= 0) containerHeight = 240;

        var deltaPercent = deltaY / containerHeight;
        var newY = Math.Clamp(_dragStartYPercent + deltaPercent, 0.0, 1.0 - _cropHeightPercent);
        _cropYPercent = newY;
        UpdateCropBoxUI();
    }

    private void CropBox_MouseUp(object sender, MouseButtonEventArgs e)
    {
        if (_isDraggingCrop)
        {
            _isDraggingCrop = false;
            CropBox.ReleaseMouseCapture();
        }
    }

    private void UpdateCropBoxUI()
    {
        if (_isUpdatingCropUI) return;
        if (CropBox is null || PreviewContainerBorder is null || CropCanvas is null) return;

        try
        {
            _isUpdatingCropUI = true;
            var containerWidth = PreviewContainerBorder.ActualWidth;
            var containerHeight = PreviewContainerBorder.ActualHeight;
            if (containerHeight <= 0) containerHeight = 240;
            if (containerWidth <= 0) containerWidth = 600;

            var boxWidth = containerWidth * _cropWidthPercent;
            var boxHeight = containerHeight * _cropHeightPercent;
            var boxLeft = containerWidth * _cropXPercent;
            var boxTop = containerHeight * _cropYPercent;

            CropBox.Width = boxWidth;
            CropBox.Height = boxHeight;
            Canvas.SetLeft(CropBox, boxLeft);
            Canvas.SetTop(CropBox, boxTop);

            if (CropYLabel is not null) CropYLabel.Text = $"%{Math.Round(_cropYPercent * 100)}";
            if (CropHeightLabel is not null) CropHeightLabel.Text = $"%{Math.Round(_cropHeightPercent * 100)}";
            if (CropYSlider is not null && Math.Abs(CropYSlider.Value - _cropYPercent * 100) > 0.5)
                CropYSlider.Value = _cropYPercent * 100;
            if (CropHeightSlider is not null && Math.Abs(CropHeightSlider.Value - _cropHeightPercent * 100) > 0.5)
                CropHeightSlider.Value = _cropHeightPercent * 100;
        }
        finally
        {
            _isUpdatingCropUI = false;
        }
    }

    private void ToggleLiveTranslation_Click(object sender, RoutedEventArgs e)
    {
        if (_isLiveTranslating)
        {
            StopLiveTranslation();
            return;
        }

        if (!_remotePlay.IsRunning)
        {
            MessageBox.Show("Canlı çeviriyi başlatmak için önce ana sayfadan PS5 görüntüsünü başlatmalısın.", "NOXIR Play", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        StartLiveTranslation();
    }

    private void StartLiveTranslation()
    {
        _isLiveTranslating = true;
        _liveTranslationCts?.Cancel();
        _liveTranslationCts = new CancellationTokenSource();
        ToggleLiveTranslationButton.Content = "Çeviriyi Durdur";
        ToggleLiveTranslationButton.Background = MakeBrush("#F0566A");
        LiveTranslationDot.Fill = MakeBrush("#3FCF8E");
        LiveTranslationStateText.Text = "Canlı çeviri aktif · Altyazı taranıyor...";
        LiveSubtitleText.Text = "(Altyazı bekleniyor...)";

        _cachedSourceLang = SelectedComboText(SourceLanguageBox);
        _cachedTargetLang = SelectedComboText(TargetLanguageBox);
        _cachedService = SelectedComboText(TranslationServiceBox);
        _cachedOcrEngine = SelectedComboText(OcrEngineBox);
        _cachedApiKey = TranslationApiKeyBox.Password.Trim();

        // OCR ve AI servislerini önceden ısıt
        _ = Task.Run(AiBridgeService.EnsureBridgeRunningAsync);

        var ct = _liveTranslationCts.Token;
        _ = Task.Run(() => RunLiveTranslationLoopAsync(ct), ct);
    }

    private void StopLiveTranslation()
    {
        _isLiveTranslating = false;
        try { _liveTranslationCts?.Cancel(); } catch { }
        _liveTranslationCts = null;

        Dispatcher.BeginInvoke(() =>
        {
            ToggleLiveTranslationButton.Content = "Çeviriyi Başlat";
            ToggleLiveTranslationButton.Background = MakeBrush("#3FCF8E");
            LiveTranslationDot.Fill = MakeBrush("#707B8D");
            LiveTranslationStateText.Text = "Çeviri durduruldu";
        });
    }

    private async Task RunLiveTranslationLoopAsync(CancellationToken ct)
    {
        string lastRecognizedText = string.Empty;
        var consecutiveEmptyCount = 0;

        while (!ct.IsCancellationRequested)
        {
            try
            {
                var frame = _latestFrame;
                // Arka plan thread'den BitmapSource'a erişim için freeze zorunlu;
                // UpdateSubtitleRegionPreview zaten freeze ediyor ama ekstra güvence olsun.
                if (frame is not null && !frame.IsFrozen)
                {
                    if (frame.CanFreeze) { try { frame.Freeze(); } catch { frame = null; } }
                    else frame = null;
                }
                if (frame is not null)
                {
                    // Kullanıcının seçtiği ve ekranda gördüğü altyazı bölgesi
                    var h = (int)(frame.PixelHeight * _cropHeightPercent);
                    var y = (int)(frame.PixelHeight * _cropYPercent);
                    var x = (int)(frame.PixelWidth * _cropXPercent);
                    var w = (int)(frame.PixelWidth * _cropWidthPercent);
                    var crop = new Int32Rect(Math.Max(0, x), Math.Max(0, y), Math.Max(1, w), Math.Max(1, h));

                    string sourceLang = _cachedSourceLang;
                    string targetLang = _cachedTargetLang;
                    string service = _cachedService;
                    string ocrEngine = _cachedOcrEngine;
                    string apiKey = _cachedApiKey;

                    var ocrResult = await OcrService.RecognizeDetailedTextAsync(frame, crop, sourceLang, ocrEngine);

                    if (!string.IsNullOrWhiteSpace(ocrResult.Text) && ocrResult.Text.Length >= 2)
                    {
                        // 1. Güven Skoru Kontrolü: Aşırı düşük kaliteli hayalleri ele
                        if (ocrResult.Confidence > 0 && ocrResult.Confidence < 0.35)
                        {
                            continue;
                        }

                        consecutiveEmptyCount = 0;

                        // NOXIRTranslate Metin Kalite Hattı: Temizleme & Kelime Ayrıştırma
                        string cleanedText = TextQualityPipeline.CleanOcrNoise(ocrResult.Text);
                        cleanedText = TextQualityPipeline.FixOcrMergedWords(cleanedText);

                        if (TextQualityPipeline.ShouldSkipTranslation(cleanedText))
                        {
                            continue;
                        }

                        // Fuzzy Benzerlik Kontrolü: Halihazırda gösterilen metinle %80+ benzerse tekrar çeviri yapma
                        if (CalculateSimilarity(cleanedText, lastRecognizedText) >= 0.80)
                        {
                            continue;
                        }

                        lastRecognizedText = cleanedText;

                        _ = Dispatcher.BeginInvoke(() =>
                        {
                            LiveTranslationStateText.Text = $"Okundu: \"{cleanedText}\" · Çevriliyor...";
                        });

                        // Konuşmacı ("OLD DRIVER:") ve Diyalog ("Yes, sir, no") ayrıştırması
                        string speaker = ocrResult.Speaker;
                        string dialogToTranslate = ocrResult.Dialog;
                        if (string.IsNullOrWhiteSpace(dialogToTranslate))
                        {
                            dialogToTranslate = cleanedText;
                        }

                        // Yer tutucuları ve tuş etiketlerini koruma altına al (Örn: [X], {0})
                        var (shieldedText, placeholders) = TextQualityPipeline.ShieldPlaceholders(dialogToTranslate);

                        string translated = string.Empty;
                        string usedEngine = "Bilinmiyor";
                        string errorReason = string.Empty;

                        // Sıralı Çeviri ve Yedek (Fallback) Zinciri:
                        if (service.Contains("Opus", StringComparison.OrdinalIgnoreCase) || service.Contains("NOXIR", StringComparison.OrdinalIgnoreCase))
                        {
                            try
                            {
                                translated = await AiBridgeService.TranslateAiAsync(shieldedText, sourceLang, targetLang, engine: "opus");
                                if (!string.IsNullOrWhiteSpace(translated)) usedEngine = "Opus-MT";
                            }
                            catch (Exception ex) { errorReason = "Opus-MT: " + ex.Message; }

                            // 1. Yedek: NLLB-200
                            if (string.IsNullOrWhiteSpace(translated))
                            {
                                try
                                {
                                    PreviewFrameService.Log("Opus-MT yanıt vermedi, NLLB-200 deneniyor...");
                                    translated = await AiBridgeService.TranslateAiAsync(shieldedText, sourceLang, targetLang, engine: "nllb");
                                    if (!string.IsNullOrWhiteSpace(translated)) usedEngine = "NLLB-200 (Yedek)";
                                }
                                catch (Exception ex) { errorReason = "NLLB-200: " + ex.Message; }
                            }

                            // 2. Yedek: Google Translate
                            if (string.IsNullOrWhiteSpace(translated))
                            {
                                try
                                {
                                    PreviewFrameService.Log("Yerel modeller yanıt vermedi, Google Translate deneniyor...");
                                    translated = await GoogleTranslateService.TranslateAsync(shieldedText, sourceLang, targetLang, ct);
                                    if (!string.IsNullOrWhiteSpace(translated)) usedEngine = "Google Translate (Yedek)";
                                }
                                catch (Exception ex) { errorReason = "Google Translate: " + ex.Message; }
                            }
                        }
                        else if (service.Contains("NLLB", StringComparison.OrdinalIgnoreCase))
                        {
                            try
                            {
                                translated = await AiBridgeService.TranslateAiAsync(shieldedText, sourceLang, targetLang, engine: "nllb");
                                if (!string.IsNullOrWhiteSpace(translated)) usedEngine = "NLLB-200";
                            }
                            catch (Exception ex) { errorReason = "NLLB-200: " + ex.Message; }

                            if (string.IsNullOrWhiteSpace(translated))
                            {
                                try
                                {
                                    translated = await AiBridgeService.TranslateAiAsync(shieldedText, sourceLang, targetLang, engine: "opus");
                                    if (!string.IsNullOrWhiteSpace(translated)) usedEngine = "Opus-MT (Yedek)";
                                }
                                catch (Exception ex) { errorReason = "Opus-MT: " + ex.Message; }
                            }

                            if (string.IsNullOrWhiteSpace(translated))
                            {
                                try
                                {
                                    translated = await GoogleTranslateService.TranslateAsync(shieldedText, sourceLang, targetLang, ct);
                                    if (!string.IsNullOrWhiteSpace(translated)) usedEngine = "Google Translate (Yedek)";
                                }
                                catch (Exception ex) { errorReason = "Google Translate: " + ex.Message; }
                            }
                        }
                        else if (service.Contains("DeepL", StringComparison.OrdinalIgnoreCase))
                        {
                            if (!string.IsNullOrWhiteSpace(apiKey))
                            {
                                try
                                {
                                    translated = await DeepLTranslateAsync(shieldedText, apiKey, targetLang, ct);
                                    if (!string.IsNullOrWhiteSpace(translated)) usedEngine = "DeepL API";
                                }
                                catch (Exception ex) { errorReason = "DeepL: " + ex.Message; }
                            }
                            else
                            {
                                errorReason = "DeepL API anahtarı boş";
                            }

                            if (string.IsNullOrWhiteSpace(translated))
                            {
                                try
                                {
                                    translated = await AiBridgeService.TranslateAiAsync(shieldedText, sourceLang, targetLang, engine: "opus");
                                    if (!string.IsNullOrWhiteSpace(translated)) usedEngine = "Opus-MT (Yedek)";
                                }
                                catch { }
                            }
                        }
                        else // Google Translate
                        {
                            try
                            {
                                translated = await GoogleTranslateService.TranslateAsync(shieldedText, sourceLang, targetLang, ct);
                                if (!string.IsNullOrWhiteSpace(translated)) usedEngine = "Google Translate";
                            }
                            catch (Exception ex) { errorReason = "Google Translate: " + ex.Message; }

                            if (string.IsNullOrWhiteSpace(translated))
                            {
                                try
                                {
                                    translated = await AiBridgeService.TranslateAiAsync(shieldedText, sourceLang, targetLang, engine: "opus");
                                    if (!string.IsNullOrWhiteSpace(translated)) usedEngine = "Opus-MT (Yedek)";
                                }
                                catch { }
                            }
                        }

                        // Eğer tüm motorlar başarısız olduysa sessiz kalma, PC arayüzünde hata göster
                        if (string.IsNullOrWhiteSpace(translated))
                        {
                            string errMessage = $"Çeviri hatası: {(string.IsNullOrEmpty(errorReason) ? "Motor yanıt vermedi" : errorReason)}";
                            _ = Dispatcher.BeginInvoke(() =>
                            {
                                LiveSubtitleText.Text = errMessage;
                                LiveSubtitleText.Foreground = MakeBrush("#F0566A");
                                LiveTranslationStateText.Text = errMessage;
                            });
                            continue;
                        }

                        // Çeviri modelinin bilinmeyen sembollere ürettiği '??' parazitlerini temizle
                        translated = System.Text.RegularExpressions.Regex.Replace(translated, @"^\?+\s*", "").Trim();
                        if (string.IsNullOrWhiteSpace(translated)) continue;

                        // Yer tutucuları çöz ve Türkçe dilbilgisi son işlemesini uygula
                        translated = TextQualityPipeline.UnshieldPlaceholders(translated, placeholders);
                        translated = TextQualityPipeline.PostProcessTurkish(translated);

                        // Konuşmacı adı varsa başına ekle (örn: "OLD DRIVER: Evet efendim, hayır")
                        string finalCaption = !string.IsNullOrWhiteSpace(speaker)
                            ? $"{speaker}: {translated}"
                            : translated;

                        _ = Dispatcher.BeginInvoke(() =>
                        {
                            // PC Arayüzü: Canlı altyazı kutusu
                            LiveSubtitleText.Text = finalCaption;
                            LiveSubtitleText.Foreground = MakeBrush("#3FCF8E");
                            LiveTranslationStateText.Text = $"Canlı Çevrildi ({DateTime.Now:HH:mm:ss}) — Orijinal: \"{cleanedText}\"";
                            if (SettingsEngineBadgeText is not null) SettingsEngineBadgeText.Text = usedEngine;
                        });

                        // TV Çıkışı: WebSocket üzerinden LG webOS TV'ye gönder (Orijinal gizleme durumuyla)
                        await _remotePlay.BroadcastCaptionAsync(finalCaption, _cachedHideOriginal, ct);
                    }
                    else
                    {
                        consecutiveEmptyCount++;
                        if (consecutiveEmptyCount == 6 && !string.IsNullOrEmpty(lastRecognizedText))
                        {
                            lastRecognizedText = string.Empty;
                            _ = Dispatcher.BeginInvoke(() =>
                            {
                                LiveTranslationStateText.Text = "Altyazı taranıyor...";
                                LiveSubtitleText.Text = "(Altyazı bekleniyor...)";
                                LiveSubtitleText.Foreground = MakeBrush("#3FCF8E");
                            });
                            await _remotePlay.BroadcastCaptionAsync(string.Empty, _cachedHideOriginal, ct);
                        }
                    }
                }
            }
            catch (OperationCanceledException) { break; }
            catch (Exception ex)
            {
                PreviewFrameService.Log("Çeviri döngüsü hatası: " + ex.Message);
            }

            // Hızlı Okuma & Tepki: Altyazı taranırken 100ms tepki süresi (gecikmesiz anında yakalama)
            try { await Task.Delay(100, ct); } catch { break; }
        }
    }

    private static double CalculateSimilarity(string s1, string s2)
    {
        if (string.IsNullOrEmpty(s1) && string.IsNullOrEmpty(s2)) return 1.0;
        if (string.IsNullOrEmpty(s1) || string.IsNullOrEmpty(s2)) return 0.0;
        if (string.Equals(s1, s2, StringComparison.OrdinalIgnoreCase)) return 1.0;

        int n = s1.Length;
        int m = s2.Length;
        var d = new int[n + 1, m + 1];

        for (int i = 0; i <= n; i++) d[i, 0] = i;
        for (int j = 0; j <= m; j++) d[0, j] = j;

        for (int i = 1; i <= n; i++)
        {
            for (int j = 1; j <= m; j++)
            {
                int cost = char.ToLowerInvariant(s1[i - 1]) == char.ToLowerInvariant(s2[j - 1]) ? 0 : 1;
                d[i, j] = Math.Min(
                    Math.Min(d[i - 1, j] + 1, d[i, j - 1] + 1),
                    d[i - 1, j - 1] + cost);
            }
        }

        int maxLen = Math.Max(n, m);
        return 1.0 - ((double)d[n, m] / maxLen);
    }

    private static async Task<string> DeepLTranslateAsync(string text, string authKey, string targetLang, CancellationToken ct)
    {
        try
        {
            using var http = new HttpClient();
            var endpoint = authKey.EndsWith(":fx", StringComparison.OrdinalIgnoreCase)
                ? "https://api-free.deepl.com/v2/translate"
                : "https://api.deepl.com/v2/translate";

            var tl = targetLang switch
            {
                "İngilizce" => "EN",
                "Almanca" => "DE",
                "Fransızca" => "FR",
                "İspanyolca" => "ES",
                _ => "TR"
            };

            var postData = new Dictionary<string, string>
            {
                ["auth_key"] = authKey,
                ["text"] = text,
                ["target_lang"] = tl
            };

            var resp = await http.PostAsync(endpoint, new FormUrlEncodedContent(postData), ct);
            if (!resp.IsSuccessStatusCode) return text;
            using var doc = JsonDocument.Parse(await resp.Content.ReadAsStringAsync(ct));
            if (doc.RootElement.TryGetProperty("translations", out var translations) && translations.GetArrayLength() > 0)
            {
                return translations[0].GetProperty("text").GetString() ?? text;
            }
        }
        catch { }
        return text;
    }

    private bool _isDisposedOrExiting;

    private async void Window_Closing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        if (_isDisposedOrExiting) return;

        // Kapanmayı geçici olarak durdur ve tüm arka plan unmanaged thread / süreçleri temizle
        e.Cancel = true;
        _isDisposedOrExiting = true;

        try
        {
            StopLiveTranslation();
            await _remotePlay.DisposeAsync();
            AiBridgeService.KillServer();
        }
        catch { }
        finally
        {
            Dispatcher.Invoke(Close);
        }
    }
}
```

#### 14. `pc/NoxirPlay.PC/OcrService.cs`

```csharp
using System.IO;
using System.Windows;
using System.Windows.Media.Imaging;

namespace NoxirPlay.PC;

internal static class OcrService
{
    private static byte[] ExtractJpegBytes(BitmapSource source, Int32Rect cropRect)
    {
        try
        {
            var x      = Math.Max(0, Math.Min(cropRect.X, source.PixelWidth - 1));
            var y      = Math.Max(0, Math.Min(cropRect.Y, source.PixelHeight - 1));
            var width  = Math.Max(1, Math.Min(cropRect.Width,  source.PixelWidth  - x));
            var height = Math.Max(1, Math.Min(cropRect.Height, source.PixelHeight - y));

            var cropped = new CroppedBitmap(source, new Int32Rect(x, y, width, height));
            using var ms = new MemoryStream();
            var encoder = new JpegBitmapEncoder { QualityLevel = 90 };
            encoder.Frames.Add(BitmapFrame.Create(cropped));
            encoder.Save(ms);
            return ms.ToArray();
        }
        catch (Exception ex)
        {
            PreviewFrameService.Log("Kırpma/JPEG kodlama hatası: " + ex.Message);
            return [];
        }
    }

    /// <summary>
    /// Bitmap kaynağının belirli bir bölgesini optimize JPEG baytına dönüştürür (Ultra Hızlı Donanım Kodlaması).
    /// Thread-safe: frozen bitmap doğrudan işlenir, frozen değilse UI thread'de çalıştırılır.
    /// </summary>
    private static byte[] SafeExtractImageBytes(BitmapSource source, Int32Rect cropRect)
    {
        if (source.IsFrozen)
            return ExtractJpegBytes(source, cropRect);

        var dispatcher = Application.Current?.Dispatcher;
        if (dispatcher is null || dispatcher.CheckAccess())
            return ExtractJpegBytes(source, cropRect);

        try
        {
            if (source.CanFreeze)
            {
                source.Freeze();
                return ExtractJpegBytes(source, cropRect);
            }
        }
        catch { }

        return dispatcher.Invoke(() => ExtractJpegBytes(source, cropRect));
    }

    public static async Task<OcrDetailedResult> RecognizeDetailedTextAsync(
        BitmapSource bitmapSource,
        Int32Rect cropRect,
        string languageHint = "en-US",
        string engineChoice = "RapidOCR PP-OCRv6 Tiny (Çok Hızlı)")
    {
        var empty = new OcrDetailedResult(string.Empty, string.Empty, 0.0, string.Empty, string.Empty, string.Empty);
        try
        {
            byte[] imageBytes = SafeExtractImageBytes(bitmapSource, cropRect);
            if (imageBytes.Length == 0) return empty;

            string engine = engineChoice.Contains("Easy", StringComparison.OrdinalIgnoreCase) ? "easyocr" : "rapid";
            var detailedResult = await AiBridgeService.RecognizeRapidOcrDetailedAsync(imageBytes, engine);

            if (!string.IsNullOrEmpty(detailedResult.Text))
            {
                string sourceName = engine == "easyocr" ? "EasyOCR" : "RapidOCR PP-OCRv6 Tiny";
                PreviewFrameService.Log(
                    $"[{sourceName}] Okundu ({detailedResult.Text.Length} kar, " +
                    $"Güven: %{detailedResult.Confidence * 100:0}): {detailedResult.Text}");
            }

            return detailedResult;
        }
        catch (Exception ex)
        {
            PreviewFrameService.Log("OCR çalışma hatası: " + ex.GetType().Name + ": " + ex.Message);
            return empty;
        }
    }

    public static async Task<string> RecognizeTextAsync(
        BitmapSource bitmapSource,
        Int32Rect cropRect,
        string languageHint = "en-US",
        string engineChoice = "RapidOCR PP-OCRv6 Tiny (Çok Hızlı)")
    {
        var result = await RecognizeDetailedTextAsync(bitmapSource, cropRect, languageHint, engineChoice);
        return result.Text;
    }
}
```

#### 15. `pc/NoxirPlay.PC/PreviewFrameService.cs`

```csharp
using System.Diagnostics;
using System.IO;
using System.Threading.Channels;
using System.Windows.Media.Imaging;

namespace NoxirPlay.PC;

internal sealed class PreviewFrameService : IAsyncDisposable
{
    private const int PreviewFps = 60;
    private const int PreviewWidth = 960;

    private Process? _process;
    private Channel<byte[]>? _queue;
    private CancellationTokenSource? _cts;
    private Task? _writer;
    private Task? _reader;
    private Task? _errorDrain;

    public event Action<BitmapSource>? FrameReady;

    private static readonly object LogLock = new();
    private static readonly string LogPath = Path.Combine(AppContext.BaseDirectory, "preview.log");
    private long _bytesQueued;
    private long _bytesWritten;
    private int _framesDecoded;

    public static void Log(string message)
    {
        try
        {
            lock (LogLock)
            {
                Directory.CreateDirectory(Path.GetDirectoryName(LogPath)!);
                File.AppendAllText(LogPath, $"{DateTime.Now:HH:mm:ss.fff}  {message}{Environment.NewLine}");
            }
        }
        catch { }
    }

    public bool IsRunning => _process is { HasExited: false };

    public void Start(string ffmpegPath)
    {
        if (_process is not null) return;

        var psi = new ProcessStartInfo(ffmpegPath)
        {
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };
        foreach (var arg in new[]
        {
            "-hide_banner", "-loglevel", "warning",
            "-fflags", "+genpts", "-flags", "low_delay",
            "-f", "h264", "-i", "pipe:0",
            "-an",
            "-vf", $"fps={PreviewFps},scale={PreviewWidth}:-2",
            "-pix_fmt", "yuvj420p",
            "-f", "image2pipe", "-c:v", "mjpeg", "-q:v", "5",
            "-flush_packets", "1",
            "pipe:1"
        })
            psi.ArgumentList.Add(arg);

        _bytesQueued = _bytesWritten = 0; _framesDecoded = 0;
        Log($"Önizleme ffmpeg başlatılıyor: {ffmpegPath} {string.Join(' ', psi.ArgumentList)}");
        var process = Process.Start(psi) ?? throw new InvalidOperationException("Önizleme ffmpeg süreci başlatılamadı.");
        _process = process;
        _cts = new CancellationTokenSource();
        _queue = Channel.CreateBounded<byte[]>(new BoundedChannelOptions(256)
        {
            FullMode = BoundedChannelFullMode.DropWrite,
            SingleReader = true,
            SingleWriter = true
        });

        var ct = _cts.Token;
        _writer = Task.Run(() => WriteLoopAsync(process, _queue.Reader, ct));
        _reader = Task.Run(() => ReadLoopAsync(process, ct));
        _errorDrain = Task.Run(async () =>
        {
            try
            {
                using var reader = new StreamReader(process.StandardError.BaseStream);
                string? line;
                while ((line = await reader.ReadLineAsync(ct)) is not null)
                    Log("ffmpeg: " + line);
            }
            catch { }
        });
    }

    public void TryWrite(byte[] buffer, int count)
    {
        var queue = _queue;
        if (queue is null || count <= 0) return;
        _bytesQueued += count;
        var copy = new byte[count];
        Buffer.BlockCopy(buffer, 0, copy, 0, count);
        queue.Writer.TryWrite(copy);
    }

    private async Task WriteLoopAsync(Process process, ChannelReader<byte[]> reader, CancellationToken ct)
    {
        try
        {
            var stdin = process.StandardInput.BaseStream;
            await foreach (var chunk in reader.ReadAllAsync(ct))
            {
                await stdin.WriteAsync(chunk, ct);
                await stdin.FlushAsync(ct);
                _bytesWritten += chunk.Length;
            }
        }
        catch (Exception ex) { Log("Yazma döngüsü bitti: " + ex.GetType().Name + " " + ex.Message); }
    }

    private async Task ReadLoopAsync(Process process, CancellationToken ct)
    {
        try
        {
            var stdout = process.StandardOutput.BaseStream;
            var buffer = new byte[2 * 1024 * 1024];
            var length = 0;
            int read;
            while ((read = await stdout.ReadAsync(buffer.AsMemory(length), ct)) > 0)
            {
                length += read;
                while (true)
                {
                    var start = IndexOf(buffer, length, 0xFF, 0xD8, 0);
                    if (start < 0)
                    {
                        if (length > 0 && buffer[length - 1] == 0xFF) { buffer[0] = 0xFF; length = 1; }
                        else length = 0;
                        break;
                    }
                    var end = IndexOf(buffer, length, 0xFF, 0xD9, start + 2);
                    if (end < 0)
                    {
                        if (start > 0)
                        {
                            Buffer.BlockCopy(buffer, start, buffer, 0, length - start);
                            length -= start;
                        }
                        break;
                    }

                    var frameLength = end + 2 - start;
                    DecodeAndRaise(buffer, start, frameLength);
                    var rest = length - (end + 2);
                    if (rest > 0) Buffer.BlockCopy(buffer, end + 2, buffer, 0, rest);
                    length = rest;
                }
                if (length >= buffer.Length) length = 0;
            }
            Log($"Okuma döngüsü bitti (ffmpeg çıktısı kapandı). Çözülen kare: {_framesDecoded}");
        }
        catch (Exception ex) { Log("Okuma döngüsü hata: " + ex.GetType().Name + " " + ex.Message); }
    }

    private void DecodeAndRaise(byte[] buffer, int offset, int count)
    {
        try
        {
            using var ms = new MemoryStream(buffer, offset, count, writable: false);
            var decoder = new JpegBitmapDecoder(ms, BitmapCreateOptions.PreservePixelFormat, BitmapCacheOption.OnLoad);
            if (decoder.Frames.Count == 0) return;
            var frame = decoder.Frames[0];
            if (!frame.IsFrozen && frame.CanFreeze) frame.Freeze();
            _framesDecoded++;
            if (_framesDecoded == 1 || _framesDecoded % 40 == 0)
                Log($"Kare çözüldü #{_framesDecoded} ({frame.PixelWidth}x{frame.PixelHeight})");
            FrameReady?.Invoke(frame);
        }
        catch (Exception ex) { Log("Kare çözülemedi: " + ex.Message); }
    }

    private static int IndexOf(byte[] data, int length, byte a, byte b, int from)
    {
        for (var i = from; i < length - 1; i++)
            if (data[i] == a && data[i + 1] == b) return i;
        return -1;
    }

    public async Task StopAsync()
    {
        var process = _process;
        if (process is not null)
        {
            int? exit = null;
            try { if (process.HasExited) exit = process.ExitCode; } catch { }
            Log($"Önizleme duruyor. Kuyruğa alınan: {_bytesQueued} B, ffmpeg'e yazılan: {_bytesWritten} B, çözülen kare: {_framesDecoded}, ffmpeg çıkış kodu: {(exit?.ToString() ?? "hâlâ çalışıyor")}");
        }
        _process = null;
        _queue?.Writer.TryComplete();
        _queue = null;
        try { _cts?.Cancel(); } catch { }

        if (process is not null)
        {
            try { if (!process.HasExited) process.Kill(entireProcessTree: true); } catch { }
        }
        foreach (var task in new[] { _writer, _reader, _errorDrain })
            if (task is not null) try { await task; } catch { }
        _writer = _reader = _errorDrain = null;
        process?.Dispose();
        _cts?.Dispose();
        _cts = null;
    }

    public async ValueTask DisposeAsync() => await StopAsync();
}
```

#### 16. `pc/NoxirPlay.PC/PsnRemotePlayAuthService.cs`

```csharp
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace NoxirPlay.PC;

internal sealed record PsnRemotePlayCredentials(
    string AccessToken,
    string RefreshToken,
    DateTimeOffset ExpiresAt,
    string AccountId,
    string DeviceUid);

internal sealed class PsnRemotePlayAuthService : IDisposable
{
    private const string ClientId = "ba495a24-818c-472b-b12d-ff231c1b5745";
    // This client secret is present in the public Chiaki-NG source and is not a user password.
    private const string ClientSecret = "mvaiZkRsAsI1IBkY";
    private const string TokenUrl = "https://auth.api.sonyentertainmentnetwork.com/2.0/oauth/token";
    private const string RedirectUrl = "https://remoteplay.dl.playstation.net/remoteplay/redirect";
    private const string Scope = "psn:clientapp";

    private readonly HttpClient _http = new() { Timeout = TimeSpan.FromSeconds(20) };
    private readonly string _credentialPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NOXIR Play",
        "psn-remote-play.dat");

    public static string CreateDeviceUid()
    {
        var random = Convert.ToHexString(RandomNumberGenerator.GetBytes(16)).ToLowerInvariant();
        return "0000000700410080" + random;
    }

    public static Uri CreateAuthorizationUri()
    {
        var query = new Dictionary<string, string>
        {
            ["service_entity"] = "urn:service-entity:psn",
            ["response_type"] = "code",
            ["client_id"] = ClientId,
            ["redirect_uri"] = RedirectUrl,
            ["scope"] = Scope,
            ["request_locale"] = "en_US",
            ["ui"] = "pr",
            ["service_logo"] = "ps",
            ["layout_type"] = "popup",
            ["smcid"] = "remoteplay",
            ["prompt"] = "always",
            ["PlatformPrivacyWs1"] = "minimal"
        };
        var encodedQuery = string.Join("&", query.Select(item =>
            $"{Uri.EscapeDataString(item.Key)}={Uri.EscapeDataString(item.Value)}"));
        return new Uri($"https://auth.api.sonyentertainmentnetwork.com/2.0/oauth/authorize?{encodedQuery}");
    }

    public async Task<PsnRemotePlayCredentials> CompleteLoginAsync(Uri redirectUri, string deviceUid, CancellationToken cancellationToken = default)
    {
        if (!IsRemotePlayRedirect(redirectUri))
            throw new InvalidOperationException("PlayStation dönüş adresi doğrulanamadı.");

        var query = ParseQuery(redirectUri.Query);
        if (query.TryGetValue("error", out var error) && !string.IsNullOrWhiteSpace(error))
            throw new InvalidOperationException("PlayStation oturumu tamamlanmadı. Giriş sayfasında tekrar deneyebilirsin.");
        if (!query.TryGetValue("code", out var code) || string.IsNullOrWhiteSpace(code))
            throw new InvalidOperationException("PlayStation dönüş adresinde yetkilendirme kodu yok.");

        var token = await ExchangeCodeAsync(code, cancellationToken);
        var accountId = await GetAccountIdAsync(token.AccessToken, cancellationToken);
        var credentials = new PsnRemotePlayCredentials(token.AccessToken, token.RefreshToken, token.ExpiresAt, accountId, deviceUid);
        Save(credentials);
        return credentials;
    }

    public PsnRemotePlayCredentials? Load()
    {
        if (!File.Exists(_credentialPath))
            return null;

        try
        {
            var encrypted = File.ReadAllBytes(_credentialPath);
            var clear = ProtectedData.Unprotect(encrypted, optionalEntropy: null, DataProtectionScope.CurrentUser);
            return JsonSerializer.Deserialize<PsnRemotePlayCredentials>(clear);
        }
        catch (CryptographicException)
        {
            return null;
        }
        catch (JsonException)
        {
            return null;
        }
    }

    public async Task<PsnRemotePlayCredentials> RefreshAsync(PsnRemotePlayCredentials credentials, CancellationToken cancellationToken = default)
    {
        using var response = await PostTokenRequestAsync(new Dictionary<string, string>
        {
            ["grant_type"] = "refresh_token",
            ["refresh_token"] = credentials.RefreshToken,
            ["scope"] = Scope,
            ["redirect_uri"] = RedirectUrl
        }, cancellationToken);
        var token = await ReadTokenResponseAsync(response, cancellationToken);
        var refreshed = credentials with
        {
            AccessToken = token.AccessToken,
            RefreshToken = token.RefreshToken,
            ExpiresAt = token.ExpiresAt
        };
        Save(refreshed);
        return refreshed;
    }

    public static bool IsRemotePlayRedirect(Uri uri) =>
        uri.IsAbsoluteUri &&
        string.Equals(uri.Scheme, Uri.UriSchemeHttps, StringComparison.OrdinalIgnoreCase) &&
        string.Equals(uri.Host, "remoteplay.dl.playstation.net", StringComparison.OrdinalIgnoreCase) &&
        string.Equals(uri.AbsolutePath.TrimEnd('/'), "/remoteplay/redirect", StringComparison.Ordinal);

    private async Task<TokenResult> ExchangeCodeAsync(string code, CancellationToken cancellationToken)
    {
        using var response = await PostTokenRequestAsync(new Dictionary<string, string>
        {
            ["grant_type"] = "authorization_code",
            ["code"] = code,
            ["redirect_uri"] = RedirectUrl
        }, cancellationToken);
        return await ReadTokenResponseAsync(response, cancellationToken);
    }

    private async Task<HttpResponseMessage> PostTokenRequestAsync(Dictionary<string, string> values, CancellationToken cancellationToken)
    {
        using var request = new HttpRequestMessage(HttpMethod.Post, TokenUrl)
        {
            Content = new FormUrlEncodedContent(values)
        };
        request.Headers.Authorization = new AuthenticationHeaderValue(
            "Basic",
            Convert.ToBase64String(Encoding.UTF8.GetBytes($"{ClientId}:{ClientSecret}")));

        var response = await _http.SendAsync(request, cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            var status = (int)response.StatusCode;
            response.Dispose();
            throw new HttpRequestException(status == 503
                ? "PlayStation giriş hizmeti geçici olarak kullanılamıyor (503). Biraz sonra yeniden dene."
                : $"PlayStation token işlemi başarısız oldu (HTTP {status}).");
        }
        return response;
    }

    private async Task<TokenResult> ReadTokenResponseAsync(HttpResponseMessage response, CancellationToken cancellationToken)
    {
        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
        var root = document.RootElement;
        var access = root.GetProperty("access_token").GetString();
        var refresh = root.GetProperty("refresh_token").GetString();
        var expirySeconds = root.GetProperty("expires_in").GetInt32();
        if (string.IsNullOrWhiteSpace(access) || string.IsNullOrWhiteSpace(refresh) || expirySeconds <= 0)
            throw new InvalidOperationException("PlayStation token yanıtı eksik bilgi içeriyor.");
        return new TokenResult(access, refresh, DateTimeOffset.UtcNow.AddSeconds(expirySeconds));
    }

    private async Task<string> GetAccountIdAsync(string accessToken, CancellationToken cancellationToken)
    {
        var accountInfoUrl = $"{TokenUrl}/{Uri.EscapeDataString(accessToken)}";
        using var request = new HttpRequestMessage(HttpMethod.Get, accountInfoUrl);
        request.Headers.Authorization = new AuthenticationHeaderValue(
            "Basic",
            Convert.ToBase64String(Encoding.UTF8.GetBytes($"{ClientId}:{ClientSecret}")));
        using var response = await _http.SendAsync(request, cancellationToken);
        if (!response.IsSuccessStatusCode)
            throw new HttpRequestException($"PlayStation hesap kimliği doğrulanamadı (HTTP {(int)response.StatusCode}).");

        await using var stream = await response.Content.ReadAsStreamAsync(cancellationToken);
        using var document = await JsonDocument.ParseAsync(stream, cancellationToken: cancellationToken);
        var idText = document.RootElement.GetProperty("user_id").GetString();
        if (!ulong.TryParse(idText, out var userId))
            throw new InvalidOperationException("PlayStation hesap kimliği yanıtı geçersiz.");
        var littleEndianId = new byte[sizeof(ulong)];
        System.Buffers.Binary.BinaryPrimitives.WriteUInt64LittleEndian(littleEndianId, userId);
        return Convert.ToBase64String(littleEndianId);
    }

    private void Save(PsnRemotePlayCredentials credentials)
    {
        var directory = Path.GetDirectoryName(_credentialPath)!;
        Directory.CreateDirectory(directory);
        var clear = JsonSerializer.SerializeToUtf8Bytes(credentials);
        try
        {
            var encrypted = ProtectedData.Protect(clear, optionalEntropy: null, DataProtectionScope.CurrentUser);
            var temporaryPath = _credentialPath + ".new";
            File.WriteAllBytes(temporaryPath, encrypted);
            File.Move(temporaryPath, _credentialPath, overwrite: true);
        }
        finally
        {
            CryptographicOperations.ZeroMemory(clear);
        }
    }

    private static Dictionary<string, string> ParseQuery(string query)
    {
        var result = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var item in query.TrimStart('?').Split('&', StringSplitOptions.RemoveEmptyEntries))
        {
            var parts = item.Split('=', 2);
            var key = Uri.UnescapeDataString(parts[0].Replace('+', ' '));
            var value = parts.Length == 2 ? Uri.UnescapeDataString(parts[1].Replace('+', ' ')) : string.Empty;
            result[key] = value;
        }
        return result;
    }

    public void Dispose() => _http.Dispose();

    private sealed record TokenResult(string AccessToken, string RefreshToken, DateTimeOffset ExpiresAt);
}
```

#### 17. `pc/NoxirPlay.PC/RemotePlayService.cs`

```csharp
using System.IO;
using System.IO.Pipes;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Windows.Media.Imaging;

namespace NoxirPlay.PC;

internal sealed class RemotePlayService : IAsyncDisposable
{
    private const string PipeName = "noxirplay-remote-h264";
    private readonly FfmpegStreamService _ffmpeg = new();
    private readonly PreviewFrameService _preview = new();
    private LocalLanServer? _lanServer;
    private NamedPipeServerStream? _pipe;
    private Stream? _ffmpegInput;
    private Task? _pipePump;
    private CancellationTokenSource? _nativeMonitorCts;
    private Task? _nativeMonitor;
    private int _videoDataReceived;
    private bool _nativeStarted;

    public RemotePlayService()
    {
        _preview.FrameReady += frame => PreviewFrame?.Invoke(frame);
        _ffmpeg.Faulted += err =>
        {
            PreviewFrameService.Log("FFmpeg yayın akışı hatası: " + err);
            StreamFaulted?.Invoke(err);
        };
    }

    public event Action<BitmapSource>? PreviewFrame;
    public event Action? VideoStreamStarted;
    public event Action<string>? StreamFaulted;

    public bool IsRunning => _lanServer is not null && _ffmpeg.IsRunning;
    public string TvAddress => _lanServer?.LocalAddress ?? string.Empty;
    public string TvPairCode => _lanServer?.PairCode ?? string.Empty;

    public async Task BroadcastCaptionAsync(string text, bool hideOriginal = true, CancellationToken cancellationToken = default)
    {
        if (_lanServer is not null)
        {
            await _lanServer.BroadcastCaptionAsync(text, hideOriginal, cancellationToken);
        }
    }

    public async Task StartAsync(RegisteredPs5 registration, CancellationToken cancellationToken = default)
    {
        if (IsRunning) return;
        var ffmpegPath = FindFfmpeg();
        if (ffmpegPath is null)
            throw new InvalidOperationException("FFmpeg bulunamadı. FFmpeg'in Windows sürümünü kur veya ffmpeg.exe dosyasını NOXIR Play.exe yanına koy.");

        var registrationKey = Convert.FromBase64String(registration.RegistrationKey);
        var morning = Convert.FromBase64String(registration.RpKey);
        if (registrationKey.Length != 16 || morning.Length != 16)
            throw new InvalidOperationException("PS5 kayıt anahtarları geçersiz. Kurulumdan PS5'i yeniden eşleştir.");

        var streamFolder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "NOXIR Play", "stream");
        var pipe = new NamedPipeServerStream(PipeName, PipeDirection.In, 1, PipeTransmissionMode.Byte, PipeOptions.Asynchronous);
        LocalLanServer? server = null;
        try
        {
            server = new LocalLanServer(streamFolder);
            await server.StartAsync(cancellationToken);
            var input = await _ffmpeg.StartH264InputAsync(ffmpegPath, streamFolder);
            var connected = pipe.WaitForConnectionAsync(cancellationToken);

            var error = new StringBuilder(512);
            int result;
            try
            {
                result = await Task.Run(() => NativeMethods.StartPs5Stream(registration.IpAddress, registrationKey, morning, error, (nuint)error.Capacity), cancellationToken);
            }
            catch (EntryPointNotFoundException ex)
            {
                throw new InvalidOperationException("PS5 bağlantı bileşeni eski. libnoxir-chiaki-bridge.dll dosyasını yeni sürümle derleyip uygulamanın yanına koy.", ex);
            }
            if (result != 0)
                throw new InvalidOperationException(string.IsNullOrWhiteSpace(error.ToString()) ? $"PS5 oturumu başlatılamadı ({result})." : error.ToString());

            _nativeStarted = true;
            Interlocked.Exchange(ref _videoDataReceived, 0);
            _nativeMonitorCts = new CancellationTokenSource();
            _nativeMonitor = MonitorNativeSessionAsync(_nativeMonitorCts.Token);
            _lanServer = server;
            _pipe = pipe;
            _ffmpegInput = input;
            _pipePump = PumpPipeAsync(pipe, connected, input, cancellationToken);
            try { _preview.Start(ffmpegPath); }
            catch (Exception ex) { PreviewFrameService.Log("Önizleme başlatılamadı: " + ex.Message); }
            pipe = null!;
        }
        catch
        {
            _nativeMonitorCts?.Cancel();
            _nativeMonitorCts?.Dispose();
            _nativeMonitorCts = null;
            _nativeMonitor = null;
            if (_nativeStarted)
            {
                try { await Task.Run(NativeMethods.StopPs5Stream); } catch { }
                _nativeStarted = false;
            }
            pipe.Dispose();
            await _ffmpeg.StopAsync();
            if (server is not null) await server.DisposeAsync();
            throw;
        }
        finally
        {
            CryptographicOperations.ZeroMemory(registrationKey);
            CryptographicOperations.ZeroMemory(morning);
        }
    }

    private async Task MonitorNativeSessionAsync(CancellationToken cancellationToken)
    {
        var startedAt = DateTime.UtcNow;
        while (!cancellationToken.IsCancellationRequested)
        {
            try { await Task.Delay(750, cancellationToken); }
            catch (OperationCanceledException) { return; }

            var error = new StringBuilder(512);
            int hasError;
            try
            {
                hasError = NativeMethods.GetStreamError(error, (nuint)error.Capacity);
            }
            catch (Exception ex)
            {
                PreviewFrameService.Log("PS5 oturum durumu okunamadı: " + ex.Message);
                StreamFaulted?.Invoke("PS5 bağlantı durumu okunamadı. Uygulamayı yeniden başlatıp tekrar dene.");
                return;
            }

            if (Interlocked.CompareExchange(ref _videoDataReceived, 0, 0) == 0 &&
                DateTime.UtcNow - startedAt >= TimeSpan.FromSeconds(30))
            {
                const string noVideoMessage = "PS5 oturumu açıldı ama 30 saniyede görüntü verisi gelmedi. PS5'in açık olduğunu, Uzaktan Oynatma'nın etkin olduğunu ve başka bir cihazın oturumu kullanmadığını kontrol et.";
                PreviewFrameService.Log(noVideoMessage);
                StreamFaulted?.Invoke(noVideoMessage);
                return;
            }

            if (hasError == 0)
                continue;

            var message = string.IsNullOrWhiteSpace(error.ToString())
                ? "PS5 Remote Play oturumu kapandı. Konsolun açık ve Remote Play bağlantısına hazır olduğunu kontrol et."
                : "PS5 Remote Play bağlantısı kesildi: " + error;
            PreviewFrameService.Log(message);
            StreamFaulted?.Invoke(message);
            return;
        }
    }

    private async Task PumpPipeAsync(NamedPipeServerStream pipe, Task connection, Stream ffmpegInput, CancellationToken cancellationToken)
    {
        PreviewFrameService.Log("Pipe bağlantısı bekleniyor…");
        try
        {
            await connection;
        }
        catch (Exception ex)
        {
            PreviewFrameService.Log("Pipe bağlantı bekleme hatası: " + ex.Message);
            return;
        }

        PreviewFrameService.Log("Pipe bağlandı (köprü DLL'si veri yazmaya başladı).");
        var buffer = new byte[64 * 1024];
        int read;
        long total = 0;
        long packetCount = 0;
        var first = true;
        long lastLogTicks = Environment.TickCount64;

        try
        {
            while ((read = await pipe.ReadAsync(buffer.AsMemory(), cancellationToken)) > 0)
            {
                total += read;
                packetCount++;

                if (first)
                {
                    first = false;
                    Interlocked.Exchange(ref _videoDataReceived, 1);
                    var hexSample = Convert.ToHexString(buffer, 0, Math.Min(read, 24));
                    PreviewFrameService.Log($"İlk video verisi: {read} B, ilk baytlar: {hexSample}. PS5 yayını aktif!");
                    VideoStreamStarted?.Invoke();
                    // Akış başladığında temiz bir anahtar kare (IDR) talep et
                    try { _ = Task.Run(() => NativeMethods.RequestIdr()); } catch { }
                }
                else if (packetCount <= 10)
                {
                    // İlk 10 paketin boyut ve NAL başlığını tanı için detaylı logla
                    var hexSample = Convert.ToHexString(buffer, 0, Math.Min(read, 16));
                    PreviewFrameService.Log($"Video paketi #{packetCount}: {read} B, NAL: {hexSample}, Toplam: {total} B");
                }
                else
                {
                    // Normal akışta saniyede 1 kez periyodik durum özeti logla
                    var now = Environment.TickCount64;
                    if (now - lastLogTicks >= 1000)
                    {
                        lastLogTicks = now;
                        PreviewFrameService.Log($"Video akışı aktif: Paket #{packetCount}, Son okuma: {read} B, Toplam: {total:N0} B");
                    }
                }

                await ffmpegInput.WriteAsync(buffer.AsMemory(0, read), cancellationToken);
                _preview.TryWrite(buffer, read);
            }
        }
        catch (OperationCanceledException) { }
        catch (Exception ex)
        {
            PreviewFrameService.Log("Pipe veri aktarım hatası: " + ex.Message);
        }
        PreviewFrameService.Log($"Pipe kapandı. Paket: {packetCount}, Toplam veri: {total} B");
    }

    public async Task StopAsync()
    {
        _nativeMonitorCts?.Cancel();
        var nativeMonitor = _nativeMonitor;
        _nativeMonitor = null;
        if (_nativeStarted)
        {
            // chiaki_session_join bloklanabilir; 8 saniye timeout ile koru
            using var stopCts = new CancellationTokenSource(TimeSpan.FromSeconds(8));
            try { await Task.Run(NativeMethods.StopPs5Stream, stopCts.Token); } catch { }
            _nativeStarted = false;
        }
        if (nativeMonitor is not null)
            try { await nativeMonitor; } catch { }
        _nativeMonitorCts?.Dispose();
        _nativeMonitorCts = null;

        var pipe = _pipe;
        _pipe = null;
        if (pipe is not null)
        {
            try { pipe.Dispose(); } catch { }
        }
        var pump = _pipePump;
        _pipePump = null;
        if (pump is not null)
            try { await pump; } catch { }
        _ffmpegInput = null;

        await _preview.StopAsync();
        await _ffmpeg.StopAsync();
        if (_lanServer is not null)
        {
            await _lanServer.DisposeAsync();
            _lanServer = null;
        }

        // PS5 oturum soketinin konsol tarafında kapanması için kısa tolerans beklemesi
        // ("already in use" hatasını önler)
        await Task.Delay(350);
    }

    private static string? FindFfmpeg()
    {
        var appPath = Path.Combine(AppContext.BaseDirectory, "ffmpeg.exe");
        if (File.Exists(appPath)) return appPath;
        var path = Environment.GetEnvironmentVariable("PATH") ?? string.Empty;
        foreach (var folder in path.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var candidate = Path.Combine(folder, "ffmpeg.exe");
            if (File.Exists(candidate)) return candidate;
        }
        return null;
    }

    public async ValueTask DisposeAsync() => await StopAsync();

    private static class NativeMethods
    {
        [DllImport("libnoxir-chiaki-bridge.dll", EntryPoint = "noxir_start_ps5_stream", ExactSpelling = true,
            CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        internal static extern int StartPs5Stream(
            [MarshalAs(UnmanagedType.LPUTF8Str)] string host,
            [In] byte[] registrationKey,
            [In] byte[] morning,
            [Out] StringBuilder errorMessage,
            nuint errorMessageCapacity);

        [DllImport("libnoxir-chiaki-bridge.dll", EntryPoint = "noxir_stop_ps5_stream", ExactSpelling = true,
            CallingConvention = CallingConvention.Cdecl)]
        internal static extern void StopPs5Stream();

        [DllImport("libnoxir-chiaki-bridge.dll", EntryPoint = "noxir_get_stream_error", ExactSpelling = true,
            CallingConvention = CallingConvention.Cdecl)]
        internal static extern int GetStreamError([Out] StringBuilder errorMessage, nuint errorMessageCapacity);

        [DllImport("libnoxir-chiaki-bridge.dll", EntryPoint = "noxir_request_idr", ExactSpelling = true,
            CallingConvention = CallingConvention.Cdecl)]
        internal static extern int RequestIdr();
    }
}
```

#### 18. `pc/NoxirPlay.PC/TextQualityPipeline.cs`

```csharp
using System.Text;
using System.Text.RegularExpressions;

namespace NoxirPlay.PC;

/// <summary>
/// NOXIRTranslate Çeviri Öncesi & Sonrası Metin Kalite Hattı.
/// 1. OCR gürültü temizleme (tireli satır bölmeleri, çoklu boşluklar, junk filtreleme).
/// 2. Yaygın OCR kelime yapışmalarını düzeltme ("usa" -> "us a", "ina" -> "in a", "tothe" -> "to the").
/// 3. Yer tutucu koruma (Placeholder Shielding: {0}, %s, <b>, [Button], [X]).
/// 4. Türkçe son işleme (İ/ı büyük/küçük harf, noktalama boşlukları).
/// </summary>
internal static class TextQualityPipeline
{
    private static readonly Regex PlaceholderRegex = new(
        @"(\{\d+\}|%[sdif]|<\/?[\w=#'""]+>|\[[A-Za-z0-9_+\s]{1,10}\])",
        RegexOptions.Compiled);

    private static readonly Regex HyphenWrapRegex = new(
        @"(\w+)-\s*[\r\n]+\s*(\w+)",
        RegexOptions.Compiled);

    private static readonly Regex MidSentenceBreakRegex = new(
        @"(?<=[^\.\?!:;])\s*[\r\n]+\s*(?=[a-zğüşıöç0-9])",
        RegexOptions.Compiled);

    private static readonly Regex MultiSpaceRegex = new(
        @"[ \t\u00A0]+",
        RegexOptions.Compiled);

    private static readonly Regex PunctuationLeadingSpaceRegex = new(
        @"\s+([,;:\.!\?…\)])",
        RegexOptions.Compiled);

    private static readonly Regex PunctuationMissingSpaceRegex = new(
        @"([,;:!\?])(?=[^\s\d,;:!\?\)\]\}])",
        RegexOptions.Compiled);

    private static readonly Regex QuoteSpacingRegex = new(
        @"([“""'])\s*([^“""'`]+?)\s*([”""'])",
        RegexOptions.Compiled);

    private static readonly Regex UnitJunkRegex = new(
        @"^(\d+([.,]\d+)?\s*(fps|hz|ms|k|m|xp|hp|mp|%|\/\s*\d+))$",
        RegexOptions.Compiled | RegexOptions.IgnoreCase);

    private static readonly Regex CjkRegex = new(
        @"[\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af\u25a0-\u25ff\ufffd\u2500-\u257f]+",
        RegexOptions.Compiled);

    private static readonly Regex GluedDotRegex = new(
        @"(?<=[a-zA-Z0-9])[\.](?=[a-zA-Z])",
        RegexOptions.Compiled);

    private static readonly Regex GluedColonRegex = new(
        @"(?<=[a-zA-Z0-9]):(?=[a-zA-Z])",
        RegexOptions.Compiled);

    private static readonly Regex HudPromptRegex = new(
        @"^(DISMOUNT|MOUNT|CANCEL|ACCEPT|BACK|SELECT|PAUSE|SKIP|INTERACT)\s*[O0X\[\]\(\)]?$",
        RegexOptions.Compiled | RegexOptions.IgnoreCase);

    private static readonly (Regex Pattern, string Replacement)[] OcrMergedWordRules = new[]
    {
        (new Regex(@"\b([Uu])sa\b(?=\s+[a-zA-Z]+)", RegexOptions.Compiled), "$1s a"),
        (new Regex(@"\b([Ii])na\b(?=\s+[a-zA-Z]+)", RegexOptions.Compiled), "$1n a"),
        (new Regex(@"\b([Ww])itha\b(?=\s+[a-zA-Z]+)", RegexOptions.Compiled), "$1ith a"),
        (new Regex(@"\b([Ff])ora\b(?=\s+[a-zA-Z]+)", RegexOptions.Compiled), "$1or a"),
        (new Regex(@"\b([Aa])sa\b(?=\s+[a-zA-Z]+)", RegexOptions.Compiled), "$1s a"),
        (new Regex(@"\b([Tt])othe\b", RegexOptions.Compiled), "$1o the"),
        (new Regex(@"\b([Ii])nthe\b", RegexOptions.Compiled), "$1n the"),
        (new Regex(@"\b([Oo])fthe\b", RegexOptions.Compiled), "$1f the"),
        (new Regex(@"\b([Oo])nthe\b", RegexOptions.Compiled), "$1n the"),
        (new Regex(@"\b([Aa])tthe\b", RegexOptions.Compiled), "$1t the"),
        (new Regex(@"\b([Ff])orthe\b", RegexOptions.Compiled), "$1or the"),
        (new Regex(@"\b([Ww])iththe\b", RegexOptions.Compiled), "$1ith the"),
        (new Regex(@"\b([Ff])romthe\b", RegexOptions.Compiled), "$1rom the"),
        (new Regex(@"\b([Aa])ndthe\b", RegexOptions.Compiled), "$1nd the"),
        (new Regex(@"\b([Aa])llthe\b", RegexOptions.Compiled), "$1ll the"),
        (new Regex(@"\b([Ii])sat\b", RegexOptions.Compiled), "$1s at"),
        (new Regex(@"\b([Aa])tall\b", RegexOptions.Compiled), "$1t all"),
        (new Regex(@"\b([Pp])artof\b", RegexOptions.Compiled), "$1art of"),
        (new Regex(@"\b([Kk])indof\b", RegexOptions.Compiled), "$1ind of"),
        (new Regex(@"\b([Oo])utof\b", RegexOptions.Compiled), "$1ut of"),
        (new Regex(@"\b([Hh])aveto\b", RegexOptions.Compiled), "$1ave to"),
        (new Regex(@"\b([Ww])antto\b", RegexOptions.Compiled), "$1ant to"),
        (new Regex(@"\b([Gg])oingto\b", RegexOptions.Compiled), "$1oing to"),
        (new Regex(@"\b([Aa])lot\b(?=\s+[a-zA-Z]+)", RegexOptions.Compiled), "$1 lot"),
        (new Regex(@"\b([Ee])achother\b", RegexOptions.Compiled), "$1ach other"),
        (new Regex(@"\b([Ii])nfront\b", RegexOptions.Compiled), "$1n front"),
        (new Regex(@"\b([Aa])tleast\b", RegexOptions.Compiled), "$1t least"),
        (new Regex(@"\b([Aa])swell\b", RegexOptions.Compiled), "$1s well"),
        (new Regex(@"\b([Tt])oomuch\b", RegexOptions.Compiled), "$1oo much"),
        (new Regex(@"\b([Oo])uthere\b", RegexOptions.Compiled), "$1ut here"),
        (new Regex(@"\b([Ff])reshsnow\b", RegexOptions.Compiled), "$1resh snow"),
        (new Regex(@"\b(amongst|among|with|from|under|after|before|into|about|through)(other|the|a|an|each|this|that|these|those)\b", RegexOptions.Compiled | RegexOptions.IgnoreCase), "$1 $2")
    };

    public static string FixOcrMergedWords(string text)
    {
        if (string.IsNullOrWhiteSpace(text)) return text;
        string result = text;
        foreach (var (pattern, replacement) in OcrMergedWordRules)
        {
            result = pattern.Replace(result, replacement);
        }
        return result;
    }

    public static bool ShouldSkipTranslation(string? text)
    {
        if (string.IsNullOrWhiteSpace(text)) return true;
        var trimmed = text.Trim();
        if (trimmed.Length < 3) return true;
        if (UnitJunkRegex.IsMatch(trimmed)) return true;
        if (HudPromptRegex.IsMatch(trimmed)) return true;

        // 1. Aşırı tekrar eden karakter parazitleri (Örn: ".....", "------", "|||||", "IIII")
        if (Regex.IsMatch(trimmed, @"(.)\1{3,}")) return true;

        int lettersCount = 0;
        int vowelsCount = 0;
        int digitsCount = 0;
        int symbolsCount = 0;

        foreach (char c in trimmed)
        {
            if (char.IsLetter(c))
            {
                lettersCount++;
                if ("aeiouyAEIOUYğüşıöçĞÜŞİÖÇ".Contains(c)) vowelsCount++;
            }
            else if (char.IsDigit(c))
            {
                digitsCount++;
            }
            else if (!char.IsWhiteSpace(c))
            {
                symbolsCount++;
            }
        }

        // 2. En az 3 harf ve en az 1 sesli harf içermeyen parazitleri atla
        if (lettersCount < 3 || vowelsCount == 0) return true;

        // 3. Sembol/Noktalama yoğunluğu: Karakterlerin yarısından fazlası sembolse kesin parazittir (Örn: ". - / \ | . a o i _")
        int nonWhitespaceCount = lettersCount + digitsCount + symbolsCount;
        if (nonWhitespaceCount > 0 && (double)lettersCount / nonWhitespaceCount < 0.50) return true;

        // 4. Rakam yoğunluğu: Metin sadece skor/sayı ve 1-2 harften ibaretse atla (Örn: "100/100 HP", "00:15 sec")
        if (lettersCount < 4 && digitsCount >= lettersCount) return true;

        // 5. Kelime kalitesi kontrolü: Ayrık tek harfli döküntüler (Örn: "I . o _ x v")
        var words = trimmed.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        if (words.Length >= 2)
        {
            int singleLetterWords = 0;
            foreach (var w in words)
            {
                var wLetters = w.Count(char.IsLetter);
                if (wLetters <= 1) singleLetterWords++;
            }
            // Kelimelerin %65'inden fazlası tek harfli/sembollü ise zemin parazitidir
            if ((double)singleLetterWords / words.Length >= 0.65) return true;
        }

        return false;
    }

    public static string CleanOcrNoise(string text, bool fixMergedWords = true)
    {
        if (string.IsNullOrWhiteSpace(text)) return string.Empty;

        // 1. Çince, Japonca, Korece ve geometrik kutu parazitlerini temizle
        string cleaned = CjkRegex.Replace(text, " ");

        // 2. Harf arasına sıkışmış parazit noktaları ve iki noktaları ayır: "word.another" -> "word another", "Luca:Sure" -> "Luca: Sure"
        cleaned = GluedDotRegex.Replace(cleaned, " ");
        cleaned = GluedColonRegex.Replace(cleaned, ": ");

        // 3. Tireli satır birleştirme: "inter-\nnational" -> "international"
        cleaned = HyphenWrapRegex.Replace(cleaned, "$1$2");

        // 4. Cümle ortasındaki kırılımları boşluğa çevir
        cleaned = MidSentenceBreakRegex.Replace(cleaned, " ");

        // 5. Çoklu boşlukları tek boşluğa indir
        cleaned = MultiSpaceRegex.Replace(cleaned, " ").Trim();

        // 6. OCR kelime yapışmalarını düzelt
        if (fixMergedWords)
        {
            cleaned = FixOcrMergedWords(cleaned);
        }

        return cleaned;
    }

    public static (string ShieldedText, List<string> ExtractedPlaceholders) ShieldPlaceholders(string text)
    {
        if (string.IsNullOrEmpty(text)) return (text, []);

        var placeholders = new List<string>();
        string shielded = PlaceholderRegex.Replace(text, m =>
        {
            int index = placeholders.Count;
            placeholders.Add(m.Value);
            return $"__PH_{index}__";
        });

        return (shielded, placeholders);
    }

    public static string UnshieldPlaceholders(string text, IReadOnlyList<string> placeholders)
    {
        if (string.IsNullOrEmpty(text) || placeholders.Count == 0) return text;

        string result = text;
        for (int i = 0; i < placeholders.Count; i++)
        {
            string pattern = $@"__\s*[Pp][Hh]_{i}\s*__";
            result = Regex.Replace(result, pattern, placeholders[i]);
        }

        return result;
    }

    public static string PostProcessTurkish(string text)
    {
        if (string.IsNullOrWhiteSpace(text)) return text;

        // 0. Baştaki ve sondaki kaçak işaret ve sembolleri temizle
        string processed = Regex.Replace(text.Trim(), @"^[\s\\\/\|_~^`'""\(\)\[\]\{\}\<\>#*+=§°¬¦¤¶•»«►◄▲▼■□★☆–—;:,]+", "");
        processed = Regex.Replace(processed, @"[\s\\\/\|_~^`'""\(\)\[\]\{\}\<\>#*+=§°¬¦¤¶•»«►◄▲▼■□★☆–—;:,]+$", "");

        // 1. Noktalama öncesi boşlukları temizle
        processed = PunctuationLeadingSpaceRegex.Replace(processed, "$1");

        // 2. Noktalama sonrası eksik boşlukları ekle
        processed = PunctuationMissingSpaceRegex.Replace(processed, "$1 ");

        // 3. Tırnak işaretleri etrafındaki boşlukları hizala
        processed = QuoteSpacingRegex.Replace(processed, "\"$2\"");

        // 4. Cümle içindeki izole kaçak sembolleri temizle
        processed = Regex.Replace(processed, @"\s+[\\\/\|_~^`#*+=§°¬¦¤¶•»«►◄▲▼■□★☆–—]\s+", " ");
        processed = Regex.Replace(processed, @"[\\|¦¬§¤¶]", "");

        // 5. Türkçe büyük/küçük harf ve cümle başı düzeltmesi
        processed = FixTurkishCasing(processed);

        return MultiSpaceRegex.Replace(processed, " ").Trim();
    }

    public static string FixTurkishCasing(string text)
    {
        if (string.IsNullOrEmpty(text)) return text;

        var chars = text.ToCharArray();
        bool startOfSentence = true;

        for (int i = 0; i < chars.Length; i++)
        {
            char c = chars[i];

            if (startOfSentence && char.IsLetter(c))
            {
                if (c == 'i') chars[i] = 'İ';
                else if (c == 'ı') chars[i] = 'I';
                else chars[i] = char.ToUpper(c, System.Globalization.CultureInfo.GetCultureInfo("tr-TR"));
                startOfSentence = false;
            }
            else if (c == '.' || c == '!' || c == '?' || c == '\n')
            {
                startOfSentence = true;
            }
        }

        return new string(chars);
    }
}

```

#### 19. `pc/NoxirPlay.PC/TranslationSettingsService.cs`

```csharp
using System.IO;
using System.Security.Cryptography;
using System.Text.Json;

namespace NoxirPlay.PC;

internal sealed record TranslationSettings(
    string OcrEngine,
    string TranslationService,
    string SourceLanguage,
    string TargetLanguage,
    string ApiKey,
    double CropYPercent = 0.78,
    double CropHeightPercent = 0.14,
    double CropXPercent = 0.10,
    double CropWidthPercent = 0.80,
    bool HideOriginalText = true);

internal sealed class TranslationSettingsService
{
    private readonly string _settingsPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
        "NOXIR Play",
        "translation-settings.dat");

    public TranslationSettings Load()
    {
        if (!File.Exists(_settingsPath)) return Defaults;

        byte[]? encrypted = null;
        byte[]? clear = null;
        try
        {
            encrypted = File.ReadAllBytes(_settingsPath);
            clear = ProtectedData.Unprotect(encrypted, optionalEntropy: null, DataProtectionScope.CurrentUser);
            return JsonSerializer.Deserialize<TranslationSettings>(clear) ?? Defaults;
        }
        catch (CryptographicException) { return Defaults; }
        catch (JsonException) { return Defaults; }
        finally
        {
            if (encrypted is not null) CryptographicOperations.ZeroMemory(encrypted);
            if (clear is not null) CryptographicOperations.ZeroMemory(clear);
        }
    }

    public void Save(TranslationSettings settings)
    {
        var directory = Path.GetDirectoryName(_settingsPath)!;
        Directory.CreateDirectory(directory);
        var clear = JsonSerializer.SerializeToUtf8Bytes(settings);
        try
        {
            var encrypted = ProtectedData.Protect(clear, optionalEntropy: null, DataProtectionScope.CurrentUser);
            var temporaryPath = _settingsPath + ".new";
            File.WriteAllBytes(temporaryPath, encrypted);
            File.Move(temporaryPath, _settingsPath, overwrite: true);
            CryptographicOperations.ZeroMemory(encrypted);
        }
        finally { CryptographicOperations.ZeroMemory(clear); }
    }

    private static TranslationSettings Defaults => new(
        OcrEngine: "RapidOCR PP-OCRv6 Tiny (Çok Hızlı)",
        TranslationService: "NOXIR Opus-MT (Oyun Çevirisi)",
        SourceLanguage: "Otomatik algıla",
        TargetLanguage: "Türkçe",
        ApiKey: "",
        HideOriginalText: true);
}
```

#### 20. `pc/NoxirPlay.PC/NoxirPlay.PC.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net8.0-windows10.0.19041.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <UseWPF>true</UseWPF>
    <AssemblyName>NoxirPlay.PC</AssemblyName>
  </PropertyGroup>
  <ItemGroup>
    <FrameworkReference Include="Microsoft.AspNetCore.App" />
    <PackageReference Include="Microsoft.Web.WebView2" Version="1.0.3537.50" />
    <PackageReference Include="System.Security.Cryptography.ProtectedData" Version="8.0.0" />
    <Content Include="native\*.dll" TargetPath="%(Filename)%(Extension)" CopyToOutputDirectory="PreserveNewest" CopyToPublishDirectory="PreserveNewest" />
    <Content Include="native\licenses\**\*" CopyToOutputDirectory="PreserveNewest" CopyToPublishDirectory="PreserveNewest" />
    <None Update="ai_bridge\**">
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </None>
  </ItemGroup>

</Project>

```

#### 21. `pc/NoxirPlay.PC/p.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>WinExe</OutputType>
    <TargetFramework>net8.0-windows10.0.19041.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <UseWPF>true</UseWPF>
    <AssemblyName>NoxirPlay.PC</AssemblyName>
  </PropertyGroup>
  <ItemGroup>
    <FrameworkReference Include="Microsoft.AspNetCore.App" />
    <PackageReference Include="Microsoft.Web.WebView2" Version="1.0.3537.50" />
    <PackageReference Include="PaddleOCRSharp" Version="6.2.0" />
    <PackageReference Include="System.Security.Cryptography.ProtectedData" Version="8.0.0" />
    <Content Include="native\*.dll" TargetPath="%(Filename)%(Extension)" CopyToOutputDirectory="PreserveNewest" CopyToPublishDirectory="PreserveNewest" />
    <Content Include="native\licenses\**\*" CopyToOutputDirectory="PreserveNewest" CopyToPublishDirectory="PreserveNewest" />
  </ItemGroup>

</Project>
```

#### 22. `pc/NoxirPlay.PC/ai_bridge/server.py`

```python
"""
NOXIR Play AI Bridge Server
- RapidOCR  : Oyun altyazısı tanıma (çoklu varyant + kalite seçimi)
- Opus-MT   : İngilizce → Türkçe hızlı yerel çeviri
- NLLB-200  : Çok dilli yedek çeviri motoru
- Google    : Son yedek (ağ üzerinden)

Python 3.9+ uyumlu.
"""

import os
import sys
import json
import logging
import base64
import re
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from io import BytesIO

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    from word_segmenter import segment_text
except ImportError:
    def segment_text(t):
        return t

# ── Loglama ──────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stderr)]
)
log = logging.getLogger("noxir-ai")

# ── Global değişkenler ───────────────────────────────────────────────────────
rapid_ocr       = None
opus_translator = None
sp_opus_src     = None
sp_opus_tgt     = None
ct2_translator  = None
nllb_tokenizer  = None

_ocr_lock   = threading.Lock()
_opus_lock  = threading.Lock()
_nllb_lock  = threading.Lock()

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

def _resolve(*parts):
    return os.path.abspath(os.path.join(*parts))

MODEL_DIRS = [
    _resolve(BASE_DIR, "..", "models", "nllb-200-ct2-int8"),
    _resolve(BASE_DIR, "models", "nllb-200-ct2-int8"),
    _resolve(BASE_DIR, "..", "..", "models", "nllb-200-ct2-int8"),
    r"C:\Users\00yus\OneDrive\Desktop\test\pc\NoxirPlay.PC\models\nllb-200-ct2-int8",
]

OPUS_DIRS = [
    _resolve(BASE_DIR, "..", "models", "opus-mt-en-tr"),
    _resolve(BASE_DIR, "models", "opus-mt-en-tr"),
    _resolve(BASE_DIR, "..", "..", "models", "opus-mt-en-tr"),
    r"C:\Users\00yus\OneDrive\Desktop\test\pc\NoxirPlay.PC\models\opus-mt-en-tr",
    r"C:\Users\00yus\OneDrive\Desktop\NOXIRTranslate\resources\models\opus-mt-en-tr",
]

# ── NLLB dil haritası ─────────────────────────────────────────────────────────
LANG_MAP = {
    # Türkçe — tüm yazım varyantları
    "tr": "tur_Latn", "turkish": "tur_Latn",
    "türkçe": "tur_Latn", "turkce": "tur_Latn", "türkce": "tur_Latn",
    "tur": "tur_Latn", "tur_latn": "tur_Latn",
    # İngilizce
    "en": "eng_Latn", "english": "eng_Latn",
    "ingilizce": "eng_Latn", "i̇ngilizce": "eng_Latn",
    "eng": "eng_Latn", "eng_latn": "eng_Latn",
    "otomatik algıla": "eng_Latn", "otomatik algi̇la": "eng_Latn",
    "auto": "eng_Latn", "detect": "eng_Latn",
    # Japonca
    "ja": "jpn_Jpan", "japanese": "jpn_Jpan", "japonca": "jpn_Jpan",
    "jpn": "jpn_Jpan", "jpn_jpan": "jpn_Jpan",
    # Korece
    "ko": "kor_Hang", "korean": "kor_Hang", "korece": "kor_Hang",
    "kor": "kor_Hang", "kor_hang": "kor_Hang",
    # Çince
    "zh": "zho_Hans", "zh-cn": "zho_Hans", "chinese": "zho_Hans",
    "çince": "zho_Hans", "cince": "zho_Hans",
    "zho": "zho_Hans", "zho_hans": "zho_Hans",
    # Almanca
    "de": "deu_Latn", "german": "deu_Latn", "almanca": "deu_Latn",
    "deu": "deu_Latn", "deu_latn": "deu_Latn",
    # Fransızca
    "fr": "fra_Latn", "french": "fra_Latn",
    "fransızca": "fra_Latn", "fransizca": "fra_Latn",
    "fra": "fra_Latn", "fra_latn": "fra_Latn",
    # İspanyolca
    "es": "spa_Latn", "spanish": "spa_Latn",
    "ispanyolca": "spa_Latn", "i̇spanyolca": "spa_Latn",
    "spa": "spa_Latn", "spa_latn": "spa_Latn",
    # İtalyanca
    "it": "ita_Latn", "italian": "ita_Latn", "italyanca": "ita_Latn",
    "ita": "ita_Latn", "ita_latn": "ita_Latn",
    # Rusça
    "ru": "rus_Cyrl", "russian": "rus_Cyrl", "rusca": "rus_Cyrl",
    "rus": "rus_Cyrl", "rus_cyrl": "rus_Cyrl",
}

# ── Yardımcı ─────────────────────────────────────────────────────────────────
CJK_RE    = re.compile(r'[\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af\u25a0-\u25ff\ufffd\u2500-\u257f]+')
MULTI_SP  = re.compile(r'\s+')
COLON_RE  = re.compile(r'([A-Za-z0-9]):([A-Za-z])')
PREPEND_Q = re.compile(r'^\?+\s*')

def _clean_cjk(text: str) -> str:
    return CJK_RE.sub(' ', text).strip()

def fix_ocr_typos(text: str) -> str:
    if not text:
        return ""
    text = re.sub(r'(?<=[A-Za-z])0(?=[A-Za-z])', 'o', text)
    text = re.sub(r'\b0(?=[A-Z])', 'O', text)
    text = re.sub(r'\b1(?=[A-Z])', 'I', text)
    text = re.sub(
        r'\b(amongst|among|with|from|under|after|before|into|about|through)'
        r'(other|the|a|an|each|this|that|these|those)\b',
        r'\1 \2', text, flags=re.IGNORECASE
    )
    text = segment_text(text)
    text = COLON_RE.sub(r'\1: \2', text)
    text = MULTI_SP.sub(' ', text).strip()
    return text

def extract_speaker_and_dialog(text: str):
    if not text:
        return "", ""
    m = re.match(r'^([A-Za-z0-9\s\.\-]{2,30}):\s*(.+)$', text)
    if m:
        return m.group(1).strip(), m.group(2).strip()
    return "", text

def map_lang(lang_str: str, default: str = "eng_Latn") -> str:
    if not lang_str:
        return default
    # Unicode normalize: Türkçe büyük İ / küçük ı gibi karakterleri standartlaştır
    import unicodedata
    k = unicodedata.normalize("NFC", lang_str.strip()).lower()
    if k in LANG_MAP:
        return LANG_MAP[k]
    # "İngilizce" → "i̇ngilizce" normalize olabilir, ASCII fallback
    k_ascii = k.encode("ascii", errors="replace").decode("ascii").replace("?", "")
    if k_ascii in LANG_MAP:
        return LANG_MAP[k_ascii]
    # xxx_Yyyy formatı (örn: eng_Latn)
    parts = k.split("_")
    if len(parts) == 2 and len(parts[0]) == 3 and len(parts[1]) == 4:
        return f"{parts[0]}_{parts[1].capitalize()}"
    return default

# ── RapidOCR ─────────────────────────────────────────────────────────────────
def init_rapid_ocr():
    global rapid_ocr
    if rapid_ocr is not None:
        return True
    with _ocr_lock:
        if rapid_ocr is not None:
            return True
        try:
            from rapidocr_onnxruntime import RapidOCR as _RapidOCR
            rapid_ocr = _RapidOCR(text_score=0.48)
            log.info("RapidOCR PP-OCRv6 Tiny başarıyla yüklendi (text_score=0.48).")
            return True
        except Exception as e:
            log.error(f"RapidOCR yüklenemedi: {e}")
            return False

# ── EasyOCR ──────────────────────────────────────────────────────────────────
easy_ocr = None
_easy_lock = threading.Lock()

def init_easy_ocr():
    global easy_ocr
    if easy_ocr is not None:
        return True
    with _easy_lock:
        if easy_ocr is not None:
            return True
        try:
            import easyocr
            easy_ocr = easyocr.Reader(['en'], gpu=False, verbose=False)
            log.info("EasyOCR başarıyla yüklendi.")
            return True
        except Exception as e:
            log.warning(f"EasyOCR yüklenemedi: {e}")
            return False

def run_easy_ocr(image_bytes: bytes) -> dict:
    """EasyOCR ile metin tanıma yapar; hazır değilse RapidOCR'a düşer."""
    import cv2
    if not init_easy_ocr():
        return run_ocr(image_bytes)

    np_arr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    if img is None:
        return run_ocr(image_bytes)

    try:
        results = easy_ocr.readtext(img)
        if not results:
            return run_ocr(image_bytes)

        texts, confs = [], []
        for bbox, text, score in results:
            cleaned = _clean_cjk(text.strip())
            if cleaned:
                texts.append(cleaned)
                confs.append(float(score))

        if not texts:
            return run_ocr(image_bytes)

        raw_text = " ".join(texts)
        avg_conf = sum(confs) / len(confs) if confs else 0.80
        cleaned = fix_ocr_typos(raw_text)
        speaker, dialog = extract_speaker_and_dialog(cleaned)

        return {
            "success": True,
            "text": cleaned,
            "raw_text": raw_text,
            "confidence": round(avg_conf, 2),
            "speaker": speaker,
            "dialog": dialog,
            "processed_image_base64": "",
        }
    except Exception as ex:
        log.warning(f"EasyOCR çalışma hatası: {ex}, RapidOCR'a dönülüyor.")
        return run_ocr(image_bytes)

def evaluate_variant(img):
    """Tek bir görüntü varyantını RapidOCR ile değerlendirir."""
    if rapid_ocr is None:
        return "", 0.0, 0
    try:
        res, _ = rapid_ocr(img)
        if not res:
            return "", 0.0, 0
        words, confs = [], []
        for item in res:
            if len(item) < 2 or not item[1]:
                continue
            txt = _clean_cjk(str(item[1]).strip())
            if not txt:
                continue
            score = float(item[2]) if len(item) > 2 else 0.5
            words.append(txt)
            confs.append(score)
        if not words:
            return "", 0.0, 0
        raw = " ".join(words)
        avg_conf = sum(confs) / len(confs)
        valid_w = len([w for w in words if re.search(r'[a-zA-Z]', w)])
        return raw, avg_conf, valid_w
    except Exception as e:
        log.warning(f"Varyant değerlendirme hatası: {e}")
        return "", 0.0, 0

def run_ocr(image_bytes: bytes) -> dict:
    """JPEG/PNG baytlarından oyun altyazısı optimize OCR çalıştırır."""
    import cv2

    if not init_rapid_ocr():
        raise RuntimeError("RapidOCR başlatılamadı.")

    np_arr = np.frombuffer(image_bytes, np.uint8)
    img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
    if img is None:
        raise ValueError("Görüntü çözülemedi.")

    # 2.0× akıllı boyutlandırma: Oyun altyazı harflerini optimal 45-55 piksel yüksekliğine getirir
    scaled = cv2.resize(img, (0, 0), fx=2.0, fy=2.0, interpolation=cv2.INTER_LINEAR)

    # 1. Varyant: Ham büyütülmüş görüntü
    raw_text, avg_c, valid_w = evaluate_variant(scaled)
    best_text, best_conf, best_score, best_img = raw_text, avg_c, avg_c * (1.0 + 0.15 * min(valid_w, 6)), scaled

    # Erken Çıkış: İlk varyantta metin net okunduysa (%75+ güven & >=2 kelime)
    if not (avg_c >= 0.75 and valid_w >= 2):
        # 2. Varyant: CLAHE kontrast güçlendirme (karanlık/renkli zeminli altyazılar)
        gray  = cv2.cvtColor(scaled, cv2.COLOR_BGR2GRAY)
        clahe = cv2.createCLAHE(clipLimit=2.5, tileGridSize=(8, 8))
        var_clahe = cv2.cvtColor(clahe.apply(gray), cv2.COLOR_GRAY2BGR)

        raw_c, avg_cc, valid_wc = evaluate_variant(var_clahe)
        qc = avg_cc * (1.0 + 0.15 * min(valid_wc, 6))
        if qc > best_score:
            best_score, best_text, best_conf, best_img = qc, raw_c, avg_cc, var_clahe

        # 3. Varyant: Beyaz ve Sarı Altyazı Renk Maskesi (Oyun zeminini tamamen karartıp sadece yazıları bırakır)
        if best_score < 0.65:
            hsv = cv2.cvtColor(scaled, cv2.COLOR_BGR2HSV)
            mask_w = cv2.inRange(hsv, (0, 0, 140), (180, 75, 255))
            mask_y = cv2.inRange(hsv, (10, 50, 140), (40, 255, 255))
            combined = cv2.bitwise_or(mask_w, mask_y)
            var_mask = cv2.cvtColor(combined, cv2.COLOR_GRAY2BGR)
            raw_m, avg_cm, valid_wm = evaluate_variant(var_mask)
            qm = avg_cm * (1.0 + 0.15 * min(valid_wm, 6))
            if qm > best_score:
                best_score, best_text, best_conf, best_img = qm, raw_m, avg_cm, var_mask

    # Anlamsız zemin parazitlerini ve düşük güvenli hayalleri ele
    latin_count = len(re.findall(r'[a-zA-ZğüşıöçĞÜŞİÖÇ]', best_text))
    cjk_count   = len(re.findall(r'[\u4e00-\u9fff\u3040-\u30ff\uac00-\ud7af]', best_text))
    total_len   = len(best_text.strip())

    if (latin_count < 2 and cjk_count < 1) or best_conf < 0.40:
        best_text, best_conf = "", 0.0
    elif total_len > 0 and (latin_count + cjk_count) / total_len < 0.40:
        # Metnin çoğunluğu sembol/çizgi ise atla
        best_text, best_conf = "", 0.0

    cleaned   = fix_ocr_typos(best_text)
    speaker, dialog = extract_speaker_and_dialog(cleaned)

    _, buf = cv2.imencode('.png', best_img)
    b64 = base64.b64encode(buf).decode('utf-8')

    return {
        "success":                True,
        "text":                   cleaned,
        "raw_text":               best_text,
        "confidence":             round(best_conf, 2),
        "speaker":                speaker,
        "dialog":                 dialog,
        "processed_image_base64": b64,
    }

# ── Oyun Terminolojisi ve Diyalog Eğitimi (Game Domain Adaptation) ────────────
GAME_DICT_PATH = _resolve(BASE_DIR, "..", "models", "game_dictionary.json")

DEFAULT_GAME_PHRASES = {
    # Doğrudan tam kalıp eşleşmeleri (birebir diyalog ve replik yerelleştirmesi)
    "watch out": "Dikkat et!",
    "watch out!": "Dikkat et!",
    "look out": "Dikkat et!",
    "look out!": "Dikkat et!",
    "hold on": "Bekle!",
    "hold on!": "Bekle!",
    "wait for me": "Beni bekle!",
    "let's go": "Hadi gidelim!",
    "lets go": "Hadi gidelim!",
    "let's do this": "Hadi yapalım şunu!",
    "come on": "Hadi ama!",
    "come on!": "Hadi ama!",
    "follow me": "Beni takip et!",
    "take cover": "Siper al!",
    "take cover!": "Siper al!",
    "don't move": "Kımıldama!",
    "dont move": "Kımıldama!",
    "i'm on it": "Hemen hallediyorum!",
    "im on it": "Hemen hallediyorum!",
    "on my way": "Geliyorum!",
    "are you alright": "İyi misin?",
    "are you alright?": "İyi misin?",
    "are you okay": "İyi misin?",
    "are you okay?": "İyi misin?",
    "what's going on": "Neler oluyor?",
    "what's going on?": "Neler oluyor?",
    "it can't be": "Olamaz!",
    "it cant be": "Olamaz!",
    "no way": "İmkânsız!",
    "no way!": "İmkânsız!",
    "never mind": "Boşver.",
    "over here": "Buraya!",
    "over here!": "Buraya!",
    "good luck": "Bol şans!",
    "good job": "İyi iş çıkardın!",
    "press any key": "Herhangi bir tuşa bas",
    "press any button": "Herhangi bir tuşa bas",
}

DEFAULT_GAME_TERMS = {
    # Çevrimdışı modelin oyun bağlamını bilmeyip yanlış çevirdiği kelimeleri düzelten kurallar
    r"\bgöğüs\b": "sandık",
    r"\bgöğsü\b": "sandığı",
    r"\bgöğsünü\b": "sandığını",
    r"\boyuncu kadrosu\b": "büyü yap",
    r"\boyuncuları\b": "büyüleri",
    r"\braylı silah\b": "railgun",
    r"\bsoğuma süresi\b": "bekleme süresi",
    r"\bcan barı\b": "sağlık göstergesi",
    r"\bdüşürmek\b": "yere sermek",
}

_game_phrases = dict(DEFAULT_GAME_PHRASES)
_game_terms = dict(DEFAULT_GAME_TERMS)

def init_game_dictionary():
    global _game_phrases, _game_terms
    try:
        if os.path.exists(GAME_DICT_PATH):
            with open(GAME_DICT_PATH, "r", encoding="utf-8") as f:
                data = json.load(f)
                if "phrases" in data:
                    _game_phrases.update(data["phrases"])
                if "terms" in data:
                    _game_terms.update(data["terms"])
        else:
            # Kullanıcının dilediğinde yeni kelimeler ekleyebileceği sözlük dosyasını oluştur
            os.makedirs(os.path.dirname(GAME_DICT_PATH), exist_ok=True)
            with open(GAME_DICT_PATH, "w", encoding="utf-8") as f:
                json.dump({"phrases": _game_phrases, "terms": _game_terms}, f, ensure_ascii=False, indent=2)
            log.info(f"Oyun sözlüğü dosyası oluşturuldu: {GAME_DICT_PATH}")
    except Exception as e:
        log.warning(f"Oyun sözlüğü yükleme uyarısı: {e}")

init_game_dictionary()

def apply_game_domain_post(text: str) -> str:
    """Çevrimdışı model çıktısını oyun terminolojisi ve kurallarıyla mükemmelleştirir."""
    if not text:
        return text
    result = text
    for pat, rep in _game_terms.items():
        result = re.sub(pat, rep, result, flags=re.IGNORECASE)
    return result

# ── Hızlı LRU Çeviri Önbelleği (0 ms Yanıt) ──────────────────────────────────
_trans_cache = {}
_CACHE_MAX = 5000
_cache_lock = threading.Lock()

def get_cached_translation(key: str):
    with _cache_lock:
        return _trans_cache.get(key)

def set_cached_translation(key: str, val: str):
    with _cache_lock:
        if len(_trans_cache) >= _CACHE_MAX:
            # En eski 1000 elemanı temizle
            for k in list(_trans_cache.keys())[:1000]:
                _trans_cache.pop(k, None)
        _trans_cache[key] = val

def _get_cpu_threads():
    try:
        count = os.cpu_count() or 4
        return min(8, max(4, count))
    except Exception:
        return 4

# ── Opus-MT ───────────────────────────────────────────────────────────────────
def _get_opus_dir():
    for d in OPUS_DIRS:
        bin_p = os.path.join(d, "model.bin")
        if os.path.exists(bin_p) and os.path.getsize(bin_p) > 10_000_000:
            return os.path.abspath(d)
    return None

def init_opus() -> bool:
    global opus_translator, sp_opus_src, sp_opus_tgt
    if opus_translator is not None and sp_opus_src is not None:
        return True
    with _opus_lock:
        if opus_translator is not None and sp_opus_src is not None:
            return True
        d = _get_opus_dir()
        if not d:
            log.warning("Opus-MT model klasörü bulunamadı.")
            return False
        try:
            import ctranslate2
            import sentencepiece as spm

            sp_src = os.path.join(d, "source.spm")
            sp_tgt = os.path.join(d, "target.spm")
            if not (os.path.exists(sp_src) and os.path.exists(sp_tgt)):
                alt = os.path.join(d, "spm.model")
                if os.path.exists(alt):
                    sp_src = sp_tgt = alt
                else:
                    spms = [f for f in os.listdir(d) if f.endswith('.spm') or f.endswith('.model')]
                    if spms:
                        sp_src = sp_tgt = os.path.join(d, spms[0])
                    else:
                        log.error("Opus-MT: source.spm / target.spm bulunamadı.")
                        return False

            sp_opus_src = spm.SentencePieceProcessor(model_file=sp_src)
            sp_opus_tgt = spm.SentencePieceProcessor(model_file=sp_tgt)
            threads = _get_cpu_threads()
            log.info(f"Opus-MT optimize CPU ({threads} thread) ile yükleniyor: {d}")
            opus_translator = ctranslate2.Translator(
                d, device="cpu", compute_type="int8", intra_threads=threads
            )
            log.info("Opus-MT aktif (Turbo Mode)!")
            return True
        except Exception as e:
            log.error(f"Opus-MT başlatma hatası: {e}")
            return False

def translate_opus(text: str) -> str:
    if not init_opus():
        raise RuntimeError("Opus-MT modeli hazır değil.")
    text = _clean_cjk(text.strip())
    if not text:
        return ""
    toks = sp_opus_src.encode(text, out_type=str) + ["</s>"]
    max_dec = max(8, min(int(len(toks) * 1.3 + 6), 96))
    # beam_size=1 (Greedy Search) -> Canlı oyun için 2 kat daha hızlı çeviri
    res = opus_translator.translate_batch(
        [toks], beam_size=1, max_decoding_length=max_dec
    )
    hyp = [t for t in res[0].hypotheses[0] if t != "</s>"]
    out = sp_opus_tgt.decode(hyp).strip()
    out = PREPEND_Q.sub('', out).strip()
    return apply_game_domain_post(out)

# ── NLLB-200 ─────────────────────────────────────────────────────────────────
def _get_nllb_dir():
    for d in MODEL_DIRS:
        bin_p = os.path.join(d, "model.bin")
        if os.path.exists(bin_p) and os.path.getsize(bin_p) > 100_000_000:
            return os.path.abspath(d)
    return None

def init_nllb() -> bool:
    global ct2_translator, nllb_tokenizer
    if ct2_translator is not None and nllb_tokenizer is not None:
        return True
    with _nllb_lock:
        if ct2_translator is not None and nllb_tokenizer is not None:
            return True
        model_dir = _get_nllb_dir()
        if not model_dir:
            log.warning("NLLB model dosyaları bulunamadı.")
            return False
        try:
            from transformers import AutoTokenizer
            import ctranslate2

            log.info(f"NLLB Tokenizer yükleniyor: {model_dir}")
            try:
                tok = AutoTokenizer.from_pretrained(
                    model_dir, src_lang="eng_Latn", fix_mistral_regex=False
                )
            except TypeError:
                tok = AutoTokenizer.from_pretrained(model_dir, src_lang="eng_Latn")

            translator = None
            try:
                if ctranslate2.get_cuda_device_count() > 0:
                    t = ctranslate2.Translator(model_dir, device="cuda", compute_type="int8")
                    t.translate_batch([[" Hello"]], target_prefix=[["tur_Latn"]])
                    translator = t
                    log.info("NLLB CUDA modu aktif!")
            except Exception:
                pass

            if translator is None:
                threads = _get_cpu_threads()
                translator = ctranslate2.Translator(
                    model_dir, device="cpu", compute_type="int8", intra_threads=threads
                )
                log.info(f"NLLB CPU ({threads} thread) modu aktif!")

            ct2_translator = translator
            nllb_tokenizer = tok
            return True
        except Exception as e:
            log.error(f"NLLB başlatma hatası: {e}")
            return False

def translate_nllb(text: str, src_lang: str = "eng_Latn", tgt_lang: str = "tur_Latn") -> str:
    if not init_nllb():
        raise RuntimeError("NLLB-200 modeli hazır değil.")
    text = _clean_cjk(text.strip())
    if not text:
        return ""
    src_code = map_lang(src_lang, "eng_Latn")
    tgt_code = map_lang(tgt_lang, "tur_Latn")
    nllb_tokenizer.src_lang = src_code
    src_tokens = nllb_tokenizer.convert_ids_to_tokens(nllb_tokenizer.encode(text))
    # beam_size=1 (Greedy Search) -> Canlı akış için %50 daha hızlı çeviri
    results = ct2_translator.translate_batch(
        [src_tokens],
        target_prefix=[[tgt_code]],
        beam_size=1,
        max_decoding_length=min(len(src_tokens) * 2 + 10, 160),
    )
    out_ids = nllb_tokenizer.convert_tokens_to_ids(results[0].hypotheses[0])
    out = nllb_tokenizer.decode(out_ids, skip_special_tokens=True).strip()
    return apply_game_domain_post(out)

# ── Google Translate (HTTP yedek) ─────────────────────────────────────────────
# NLLB kodu → Google iki harfli kodu
_NLLB_TO_GOOGLE = {
    "tur_Latn": "tr",
    "eng_Latn": "en",
    "jpn_Jpan": "ja",
    "kor_Hang": "ko",
    "zho_Hans": "zh-CN",
    "deu_Latn": "de",
    "fra_Latn": "fr",
    "spa_Latn": "es",
    "ita_Latn": "it",
    "rus_Cyrl": "ru",
}

def translate_google(text: str, sl: str = "auto", tl: str = "tr") -> str:
    """İnternet üzerinden Google Translate API'si (ücretsiz endpoint)."""
    import urllib.request
    import urllib.parse

    # NLLB kodunu Google koduna çevir
    sl = _NLLB_TO_GOOGLE.get(sl, sl if len(sl) <= 5 else "auto")
    tl = _NLLB_TO_GOOGLE.get(tl, tl if len(tl) <= 5 else "tr")

    errors = []
    # İki farklı endpoint dene
    for client in ("gtx", "gt4"):
        url = (
            f"https://translate.googleapis.com/translate_a/single"
            f"?client={client}&sl={sl}&tl={tl}&dt=t&q={urllib.parse.quote(text)}"
        )
        try:
            req = urllib.request.Request(url, headers={
                "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/124.0.0.0 Safari/537.36",
                "Accept-Encoding": "gzip, deflate",
            })
            with urllib.request.urlopen(req, timeout=8) as resp:
                raw = resp.read()
                # gzip sıkıştırması olabilir
                try:
                    import gzip
                    raw = gzip.decompress(raw)
                except Exception:
                    pass
                data = json.loads(raw.decode("utf-8"))
            parts = []
            for sentence in data[0]:
                if sentence and sentence[0]:
                    parts.append(str(sentence[0]))
            result = " ".join(parts).strip()
            if result:
                log.info(f"Google Translate ({client}) → {len(result)} karakter")
                return result
        except Exception as e:
            errors.append(f"{client}: {e}")
            continue

    log.warning(f"Google Translate başarısız: {'; '.join(errors)}")
    return ""

# ── Ana çeviri fonksiyonu ─────────────────────────────────────────────────────
def do_translate(text: str, src_lang: str, tgt_lang: str, engine: str) -> str:
    """
    Sıralı motor denemesi:
    0. Hızlı Önbellek (LRU Cache - 0 ms) & Oyun Diyalog Eşleşmesi
    1. Opus-MT   (İng→Türk + Turbo Greedy CTranslate2)
    2. NLLB-200  (çok dilli CTranslate2)
    3. Google Translate (ağ)
    """
    trimmed = text.strip()
    if not trimmed:
        return ""

    src_code = map_lang(src_lang, "eng_Latn")
    tgt_code = map_lang(tgt_lang, "tur_Latn")

    # 0a. Hızlı Önbellek (LRU Cache - 0 ms)
    cache_key = f"{src_code}:{tgt_code}:{trimmed.lower()}"
    cached = get_cached_translation(cache_key)
    if cached:
        log.info(f"LRU Cache (0 ms) -> {cached}")
        return cached

    # 0b. Oyun Diyalog Kalıbı Eşleşmesi (Game Domain Memory)
    low_text = trimmed.lower()
    norm_phrase = re.sub(r'[\.!\?,\s]+$', '', low_text)
    if norm_phrase in _game_phrases:
        matched = _game_phrases[norm_phrase]
        set_cached_translation(cache_key, matched)
        log.info(f"Oyun Diyalog Eğitimi Eşleşmesi: '{trimmed}' -> '{matched}'")
        return matched

    log.info(f"do_translate: '{src_lang}'→'{src_code}' | '{tgt_lang}'→'{tgt_code}' | engine='{engine}'")

    # Google Translate isteniyorsa direkt çağır, yedeksiz
    if engine == "google":
        res = translate_google(trimmed, src_code, tgt_code)
        if res:
            set_cached_translation(cache_key, res)
        return res

    result = ""

    # Opus-MT dene (İng → Türk veya açıkça istendiğinde)
    if engine in ("opus", "") and src_code == "eng_Latn" and tgt_code == "tur_Latn":
        try:
            result = translate_opus(trimmed)
            if result:
                log.info(f"Opus-MT çevirdi: {len(result)} karakter")
        except Exception as e:
            log.warning(f"Opus-MT hata: {e}")

    # NLLB dene
    if not result and engine in ("nllb", ""):
        try:
            result = translate_nllb(trimmed, src_code, tgt_code)
            if result:
                log.info(f"NLLB çevirdi: {len(result)} karakter")
        except Exception as e:
            log.warning(f"NLLB hata: {e}")

    # Google yedek — NLLB kodlarını doğrudan geçir, translate_google içinde dönüştürülüyor
    if not result:
        try:
            result = translate_google(trimmed, src_code, tgt_code)
            if result:
                log.info("Google Translate (yedek) kullanıldı.")
        except Exception as e:
            log.warning(f"Google yedek hata: {e}")

    if result:
        set_cached_translation(cache_key, result)

    return result

# ── HTTP Sunucusu ─────────────────────────────────────────────────────────────
class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/health":
            resp = {
                "status":    "ok",
                "rapidocr":  rapid_ocr is not None,
                "nllb_ready": ct2_translator is not None or _get_nllb_dir() is not None,
                "opus_ready": opus_translator is not None or _get_opus_dir() is not None,
            }
            self._json(200, resp)
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        length = int(self.headers.get("Content-Length", 0))
        body   = self.rfile.read(length) if length > 0 else b""

        if self.path.startswith("/ocr"):
            try:
                if "easy" in self.path.lower():
                    result = run_easy_ocr(body)
                else:
                    result = run_ocr(body)
                self._json(200, result)
            except Exception as e:
                log.error(f"OCR endpoint hatası: {e}", exc_info=True)
                self._json(500, {"success": False, "error": str(e)})

        elif self.path == "/translate":
            try:
                data     = json.loads(body.decode("utf-8"))
                text     = data.get("text", "").strip()
                src_lang = data.get("src_lang", "eng_Latn")
                tgt_lang = data.get("tgt_lang", "tur_Latn")
                engine   = data.get("engine", "").lower().strip()

                log.info(f"/translate isteği: src='{src_lang}' tgt='{tgt_lang}' engine='{engine}' metin='{text[:60]}'")

                if not text:
                    self._json(200, {"success": True, "translation": ""})
                    return

                translated = do_translate(text, src_lang, tgt_lang, engine)
                log.info(f"/translate sonuç: '{translated[:80]}'")
                self._json(200, {"success": True, "translation": translated})
            except Exception as e:
                log.error(f"Translate endpoint hatası: {e}", exc_info=True)
                self._json(500, {"success": False, "error": str(e)})

        else:
            self.send_response(404)
            self.end_headers()

    def _json(self, code: int, obj: dict):
        data = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        pass  # HTTP gürültüsünü bastır

# ── Arka plan model yükleme ───────────────────────────────────────────────────
def _load_all():
    log.info("AI modelleri arka planda yükleniyor...")
    init_rapid_ocr()
    init_opus()
    init_nllb()
    log.info("Tüm AI modelleri hazır! (RapidOCR + Opus-MT + NLLB-200)")

def run(port: int = 18765):
    server_address = ("127.0.0.1", port)
    httpd = HTTPServer(server_address, Handler)
    log.info(f"NOXIR AI Bridge sunucusu 127.0.0.1:{port} adresinde başlatıldı.")
    threading.Thread(target=_load_all, daemon=True).start()
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 18765
    run(port)
```

#### 23. `pc/NoxirPlay.PC/ai_bridge/test_server.py`

```python
"""
NOXIR AI Bridge - Hızlı bağımlılık ve model testi
Kullanım: python test_server.py
"""
import sys, os

print(f"Python: {sys.version}")
print(f"Yol: {sys.executable}")
print()

errors = []

# 1. rapidocr
try:
    from rapidocr_onnxruntime import RapidOCR
    ocr = RapidOCR(text_score=0.40)
    print("✅ RapidOCR yüklendi")
except Exception as e:
    print(f"❌ RapidOCR: {e}")
    errors.append("rapidocr_onnxruntime")

# 2. cv2
try:
    import cv2
    print(f"✅ OpenCV {cv2.__version__}")
except Exception as e:
    print(f"❌ cv2: {e}")
    errors.append("opencv-python-headless")

# 3. numpy
try:
    import numpy as np
    print(f"✅ NumPy {np.__version__}")
except Exception as e:
    print(f"❌ numpy: {e}")
    errors.append("numpy")

# 4. ctranslate2
try:
    import ctranslate2
    print(f"✅ CTranslate2 {ctranslate2.__version__}")
except Exception as e:
    print(f"❌ ctranslate2: {e}")
    errors.append("ctranslate2")

# 5. sentencepiece
try:
    import sentencepiece
    print(f"✅ SentencePiece {sentencepiece.__version__}")
except Exception as e:
    print(f"❌ sentencepiece: {e}")
    errors.append("sentencepiece")

# 6. transformers
try:
    import transformers
    print(f"✅ Transformers {transformers.__version__}")
except Exception as e:
    print(f"❌ transformers: {e}")
    errors.append("transformers")

print()

# Model kontrolü
BASE = os.path.dirname(os.path.abspath(__file__))
opus_path = os.path.join(BASE, "..", "models", "opus-mt-en-tr", "model.bin")
nllb_path = os.path.join(BASE, "..", "models", "nllb-200-ct2-int8", "model.bin")

opus_ok = os.path.exists(opus_path) and os.path.getsize(opus_path) > 10_000_000
nllb_ok = os.path.exists(nllb_path) and os.path.getsize(nllb_path) > 100_000_000

print(f"{'✅' if opus_ok else '❌'} Opus-MT model: {opus_path}")
print(f"{'✅' if nllb_ok else '❌'} NLLB-200 model: {nllb_path}")

if errors:
    print(f"\n⚠️  Eksik paketler: {', '.join(errors)}")
    print(f"Kur: python -m pip install {' '.join(errors)}")
else:
    print("\n✅ Tüm bağımlılıklar mevcut!")
    if opus_ok:
        print("Opus-MT çeviri testi yapılıyor...")
        try:
            import sentencepiece as spm
            sp_src = spm.SentencePieceProcessor(
                model_file=os.path.join(BASE, "..", "models", "opus-mt-en-tr", "source.spm")
            )
            sp_tgt = spm.SentencePieceProcessor(
                model_file=os.path.join(BASE, "..", "models", "opus-mt-en-tr", "target.spm")
            )
            translator = ctranslate2.Translator(
                os.path.dirname(opus_path), device="cpu", compute_type="int8", intra_threads=2
            )
            test_text = "Hello, how are you?"
            toks = sp_src.encode(test_text, out_type=str) + ["</s>"]
            res = translator.translate_batch([toks], beam_size=1, max_decoding_length=50)
            hyp = [t for t in res[0].hypotheses[0] if t != "</s>"]
            out = sp_tgt.decode(hyp)
            print(f"  '{test_text}' → '{out}'")
            print("✅ Opus-MT çeviri testi başarılı!")
        except Exception as e:
            print(f"❌ Opus-MT çeviri test hatası: {e}")

```

#### 24. `pc/NoxirPlay.PC/ai_bridge/word_segmenter.py`

```python
import math
import re

# Sık kullanılan İngilizce kelimeler ve oyun terimleri frekans sözlüğü
COMMON_WORDS = {
    'the': 20000, 'of': 15000, 'and': 14000, 'to': 13000, 'a': 12000, 'in': 11000,
    'for': 10000, 'is': 9500, 'on': 9000, 'that': 8500, 'by': 8000, 'this': 7500,
    'with': 7000, 'i': 12000, 'you': 11000, 'it': 10500, 'not': 9000, 'or': 8000,
    'be': 7500, 'are': 7000, 'from': 6500, 'at': 6000, 'as': 5500, 'your': 5000,
    'all': 4800, 'have': 4700, 'new': 4600, 'more': 4500, 'an': 4400, 'was': 4300,
    'we': 4200, 'will': 4100, 'home': 4000, 'can': 3900, 'us': 3800, 'about': 3700,
    'if': 3600, 'my': 3500, 'has': 3400, 'no': 4000, 'one': 3300, 'yes': 4000,
    'sir': 3500, 'old': 3500, 'driver': 3000, 'man': 3200, 'boy': 2500, 'girl': 2500,
    'mr': 3000, 'mister': 2800, 'mrs': 2500, 'miss': 2500, 'arthur': 2800, 'dutch': 2800,
    'john': 2800, 'luca': 2800, 'enzo': 2800, 'micah': 2500, 'hosea': 2500, 'bill': 2500,
    'come': 3000, 'here': 3200, 'go': 3500, 'away': 2800, 'wait': 3000, 'stop': 3000,
    'look': 3200, 'out': 3400, 'take': 3000, 'easy': 2800, 'sure': 3000, 'wine': 2500,
    'amongst': 2200, 'other': 3200, 'things': 3000, 'thing': 2800, 'get': 3500,
    'got': 3000, 'right': 3200, 'left': 2800, 'well': 3200, 'now': 3400, 'back': 3200,
    'down': 3100, 'up': 3300, 'see': 3200, 'what': 3600, 'who': 3000, 'where': 3000,
    'why': 2800, 'how': 3000, 'good': 3300, 'bad': 2800, 'morning': 2800, 'night': 3000,
    'friend': 3000, 'friends': 2800, 'horse': 3000, 'horses': 2600, 'wagon': 2600,
    'camp': 2800, 'town': 2800, 'money': 3000, 'gold': 2600, 'gun': 2800, 'guns': 2600,
    'sheriff': 2600, 'police': 2600, 'road': 2800, 'train': 2700, 'time': 3300,
    'help': 3000, 'please': 3000, 'sorry': 2800, 'thanks': 2800, 'thank': 2800,
    'listen': 2800, 'hear': 2800, 'tell': 3000, 'told': 2700, 'know': 3400, 'knew': 2500,
    'think': 3200, 'thought': 2700, 'want': 3200, 'wanted': 2600, 'need': 3100,
    'needed': 2500, 'say': 3200, 'said': 3100, 'speak': 2700, 'spoke': 2400,
    'talk': 2800, 'kill': 2700, 'dead': 2800, 'alive': 2600, 'run': 3000, 'hide': 2600,
    'shoot': 2700, 'shot': 2600, 'fire': 2800, 'water': 2700, 'drink': 2600, 'food': 2600,
    'eat': 2600, 'leave': 2900, 'left': 2800, 'stay': 2800, 'together': 2800,
    'alone': 2700, 'again': 3000, 'never': 3000, 'always': 2900, 'maybe': 2900,
    'fine': 2800, 'alright': 2900, 'okay': 2900, 'god': 2900, 'damn': 2700, 'hell': 2700
}

_TOTAL_FREQ = sum(COMMON_WORDS.values())
_WORD_COST = {k: -math.log(v / _TOTAL_FREQ) for k, v in COMMON_WORDS.items()}
_MAX_WORD_LEN = max(len(k) for k in COMMON_WORDS)

def split_concatenated_word(word: str) -> str:
    """
    Viterbi algoritması kullanarak bitişik yazılmış kelimeleri ayırır.
    Örnek: 'olddriver' -> 'old driver', 'amongstotherthings' -> 'amongst other things'
    """
    if len(word) < 5:
        return word
    
    # Zaten bilinen tek bir kelimeyse bölme
    lower = word.lower()
    if lower in COMMON_WORDS and len(lower) <= 8:
        return word

    cost = [0] + [float('inf')] * len(lower)
    for i in range(1, len(lower) + 1):
        for j in range(max(0, i - _MAX_WORD_LEN), i):
            sub = lower[j:i]
            # Sözlükte varsa log maliyeti, yoksa uzunluğa bağlı ceza maliyeti
            c = cost[j] + _WORD_COST.get(sub, 18.0 + (len(sub) * 1.8))
            if c < cost[i]:
                cost[i] = c

    # Geriye doğru en iyi yolu bul
    tokens = []
    i = len(lower)
    while i > 0:
        best_j = 0
        best_c = float('inf')
        for j in range(max(0, i - _MAX_WORD_LEN), i):
            sub = lower[j:i]
            c = cost[j] + _WORD_COST.get(sub, 18.0 + (len(sub) * 1.8))
            if c < best_c:
                best_c = c
                best_j = j
        tokens.append(word[best_j:i])
        i = best_j

    tokens.reverse()
    
    # Eğer hiçbir anlamlı parçalanma olmadıysa orijinali koru
    if len(tokens) == 1:
        return word
        
    return ' '.join(tokens)

def segment_text(text: str) -> str:
    """
    Tüm cümledeki bitişik kelimeleri, noktalama işaretlerini koruyarak ayırır.
    """
    if not text:
        return ""
        
    def replace_word(match):
        w = match.group(0)
        # Sadece saf harflerden oluşan uzun kelimeleri böl
        if len(w) >= 6 and w.isalpha():
            return split_concatenated_word(w)
        return w

    # Kelime sınırlarında tara
    return re.sub(r'\b[A-Za-z]{6,}\b', replace_word, text)

```

#### 25. `pc/NoxirPlay.PC/models/game_dictionary.json`

```json
{
  "phrases": {
    "watch out": "Dikkat et!",
    "watch out!": "Dikkat et!",
    "look out": "Dikkat et!",
    "look out!": "Dikkat et!",
    "hold on": "Bekle!",
    "hold on!": "Bekle!",
    "wait for me": "Beni bekle!",
    "let's go": "Hadi gidelim!",
    "lets go": "Hadi gidelim!",
    "let's do this": "Hadi yapalım şunu!",
    "come on": "Hadi ama!",
    "come on!": "Hadi ama!",
    "follow me": "Beni takip et!",
    "take cover": "Siper al!",
    "take cover!": "Siper al!",
    "don't move": "Kımıldama!",
    "dont move": "Kımıldama!",
    "i'm on it": "Hemen hallediyorum!",
    "im on it": "Hemen hallediyorum!",
    "on my way": "Geliyorum!",
    "are you alright": "İyi misin?",
    "are you alright?": "İyi misin?",
    "are you okay": "İyi misin?",
    "are you okay?": "İyi misin?",
    "what's going on": "Neler oluyor?",
    "what's going on?": "Neler oluyor?",
    "it can't be": "Olamaz!",
    "it cant be": "Olamaz!",
    "no way": "İmkânsız!",
    "no way!": "İmkânsız!",
    "never mind": "Boşver.",
    "over here": "Buraya!",
    "over here!": "Buraya!",
    "good luck": "Bol şans!",
    "good job": "İyi iş çıkardın!",
    "press any key": "Herhangi bir tuşa bas",
    "press any button": "Herhangi bir tuşa bas"
  },
  "terms": {
    "\\bgöğüs\\b": "sandık",
    "\\bgöğsü\\b": "sandığı",
    "\\bgöğsünü\\b": "sandığını",
    "\\boyuncu kadrosu\\b": "büyü yap",
    "\\boyuncuları\\b": "büyüleri",
    "\\braylı silah\\b": "railgun",
    "\\bsoğuma süresi\\b": "bekleme süresi",
    "\\bcan barı\\b": "sağlık göstergesi",
    "\\bdüşürmek\\b": "yere sermek"
  }
}
```

#### 26. `pc/NoxirPlay.PC/models/opus-mt-en-tr/config.json`

```json
{
  "add_source_bos": false,
  "add_source_eos": false,
  "bos_token": "<s>",
  "decoder_start_token": "</s>",
  "eos_token": "</s>",
  "layer_norm_epsilon": null,
  "multi_query_attention": false,
  "unk_token": "<unk>"
}
```

#### 27. `pc/NoxirPlay.PC/models/opus-mt-en-tr/manifest.json`

```json
{
  "model_id": "Helsinki-NLP/opus-mt-tc-big-en-tr",
  "language_pair": "en-tr",
  "quantization": "int8",
  "created_at": "2026-10-31T16:51:08.316794+00:00",
  "files": {
    "MODEL_LICENSE.txt": {
      "sha256": "9d0b3517a75ae9cebdc0662fb96e0c3aa3051b48194b81b8169ee1b14688f5fd",
      "size_bytes": 1202,
      "size_mb": 0.0
    },
    "config.json": {
      "sha256": "72901fbd8abd89fb5cf4a388f26fc681f5c4c58a1e1a88b30b879f107270e7ee",
      "size_bytes": 233,
      "size_mb": 0.0
    },
    "model.bin": {
      "sha256": "a5a148aae553f2573fd1f9ba735a03385f050437f98e51f8b5c4e4f9c4de3719",
      "size_bytes": 237977893,
      "size_mb": 226.95
    },
    "shared_vocabulary.json": {
      "sha256": "44dd886d9f538a4b22e58d89758bd336e73b06c753a436f7531436daafcaedee",
      "size_bytes": 1170026,
      "size_mb": 1.12
    },
    "source.spm": {
      "sha256": "180d3f94ddfee5585d78b702290ded0f4f9bd40f299349c8383b32a579fefad4",
      "size_bytes": 796953,
      "size_mb": 0.76
    },
    "target.spm": {
      "sha256": "cd0c475692178b6c626aadaef01bd8f98d8053946938e4e67005fc1e4811d797",
      "size_bytes": 833391,
      "size_mb": 0.79
    }
  },
  "total_size_bytes": 240779698,
  "total_size_mb": 229.63
}
```

#### 28. `pc/NoxirPlay.PC/models/opus-mt-en-tr/MODEL_LICENSE.txt`

```text
================================================================================
Model Attribution & License
================================================================================
Model Name: Helsinki-NLP/opus-mt-tc-big-en-tr (Opus-MT English to Turkish)
Base Architecture: MarianMT (Opus-MT / Marian)
Language Pair: English to Turkish (en -> tr)
Quantization: CTranslate2 int8 (Optimized for CPU inference)
Original Model Repository: https://huggingface.co/Helsinki-NLP/opus-mt-tc-big-en-tr
Original Creators / Authors: Jörg Tiedemann, Santhosh Thottingal, Helsinki-NLP
Training Dataset: OPUS multilingual open corpus (https://opus.nlpl.eu/)

License: Creative Commons Attribution 4.0 International (CC-BY 4.0)
https://creativecommons.org/licenses/by/4.0/

You are free to:
- Share — copy and redistribute the material in any medium or format
- Adapt — remix, transform, and build upon the material for any purpose, even commercially.

Under the following terms:
- Attribution — You must give appropriate credit, provide a link to the license,
  and indicate if changes were made.
================================================================================
```

#### 29. `pc/NoxirPlay.PC/models/nllb-200-ct2-int8/config.json`

```json
{
  "add_source_bos": false,
  "add_source_eos": false,
  "bos_token": "<s>",
  "decoder_start_token": "</s>",
  "eos_token": "</s>",
  "unk_token": "<unk>"
}
```

#### 30. `pc/NoxirPlay.PC/models/nllb-200-ct2-int8/special_tokens_map.json`

```json
{
  "additional_special_tokens": [
    "ace_Arab",
    "ace_Latn",
    "acm_Arab",
    "acq_Arab",
    "aeb_Arab",
    "afr_Latn",
    "ajp_Arab",
    "aka_Latn",
    "amh_Ethi",
    "apc_Arab",
    "arb_Arab",
    "ars_Arab",
    "ary_Arab",
    "arz_Arab",
    "asm_Beng",
    "ast_Latn",
    "awa_Deva",
    "ayr_Latn",
    "azb_Arab",
    "azj_Latn",
    "bak_Cyrl",
    "bam_Latn",
    "ban_Latn",
    "bel_Cyrl",
    "bem_Latn",
    "ben_Beng",
    "bho_Deva",
    "bjn_Arab",
    "bjn_Latn",
    "bod_Tibt",
    "bos_Latn",
    "bug_Latn",
    "bul_Cyrl",
    "cat_Latn",
    "ceb_Latn",
    "ces_Latn",
    "cjk_Latn",
    "ckb_Arab",
    "crh_Latn",
    "cym_Latn",
    "dan_Latn",
    "deu_Latn",
    "dik_Latn",
    "dyu_Latn",
    "dzo_Tibt",
    "ell_Grek",
    "eng_Latn",
    "epo_Latn",
    "est_Latn",
    "eus_Latn",
    "ewe_Latn",
    "fao_Latn",
    "pes_Arab",
    "fij_Latn",
    "fin_Latn",
    "fon_Latn",
    "fra_Latn",
    "fur_Latn",
    "fuv_Latn",
    "gla_Latn",
    "gle_Latn",
    "glg_Latn",
    "grn_Latn",
    "guj_Gujr",
    "hat_Latn",
    "hau_Latn",
    "heb_Hebr",
    "hin_Deva",
    "hne_Deva",
    "hrv_Latn",
    "hun_Latn",
    "hye_Armn",
    "ibo_Latn",
    "ilo_Latn",
    "ind_Latn",
    "isl_Latn",
    "ita_Latn",
    "jav_Latn",
    "jpn_Jpan",
    "kab_Latn",
    "kac_Latn",
    "kam_Latn",
    "kan_Knda",
    "kas_Arab",
    "kas_Deva",
    "kat_Geor",
    "knc_Arab",
    "knc_Latn",
    "kaz_Cyrl",
    "kbp_Latn",
    "kea_Latn",
    "khm_Khmr",
    "kik_Latn",
    "kin_Latn",
    "kir_Cyrl",
    "kmb_Latn",
    "kon_Latn",
    "kor_Hang",
    "kmr_Latn",
    "lao_Laoo",
    "lvs_Latn",
    "lij_Latn",
    "lim_Latn",
    "lin_Latn",
    "lit_Latn",
    "lmo_Latn",
    "ltg_Latn",
    "ltz_Latn",
    "lua_Latn",
    "lug_Latn",
    "luo_Latn",
    "lus_Latn",
    "mag_Deva",
    "mai_Deva",
    "mal_Mlym",
    "mar_Deva",
    "min_Latn",
    "mkd_Cyrl",
    "plt_Latn",
    "mlt_Latn",
    "mni_Beng",
    "khk_Cyrl",
    "mos_Latn",
    "mri_Latn",
    "zsm_Latn",
    "mya_Mymr",
    "nld_Latn",
    "nno_Latn",
    "nob_Latn",
    "npi_Deva",
    "nso_Latn",
    "nus_Latn",
    "nya_Latn",
    "oci_Latn",
    "gaz_Latn",
    "ory_Orya",
    "pag_Latn",
    "pan_Guru",
    "pap_Latn",
    "pol_Latn",
    "por_Latn",
    "prs_Arab",
    "pbt_Arab",
    "quy_Latn",
    "ron_Latn",
    "run_Latn",
    "rus_Cyrl",
    "sag_Latn",
    "san_Deva",
    "sat_Beng",
    "scn_Latn",
    "shn_Mymr",
    "sin_Sinh",
    "slk_Latn",
    "slv_Latn",
    "smo_Latn",
    "sna_Latn",
    "snd_Arab",
    "som_Latn",
    "sot_Latn",
    "spa_Latn",
    "als_Latn",
    "srd_Latn",
    "srp_Cyrl",
    "ssw_Latn",
    "sun_Latn",
    "swe_Latn",
    "swh_Latn",
    "szl_Latn",
    "tam_Taml",
    "tat_Cyrl",
    "tel_Telu",
    "tgk_Cyrl",
    "tgl_Latn",
    "tha_Thai",
    "tir_Ethi",
    "taq_Latn",
    "taq_Tfng",
    "tpi_Latn",
    "tsn_Latn",
    "tso_Latn",
    "tuk_Latn",
    "tum_Latn",
    "tur_Latn",
    "twi_Latn",
    "tzm_Tfng",
    "uig_Arab",
    "ukr_Cyrl",
    "umb_Latn",
    "urd_Arab",
    "uzn_Latn",
    "vec_Latn",
    "vie_Latn",
    "war_Latn",
    "wol_Latn",
    "xho_Latn",
    "ydd_Hebr",
    "yor_Latn",
    "yue_Hant",
    "zho_Hans",
    "zho_Hant",
    "zul_Latn"
  ],
  "bos_token": "<s>",
  "cls_token": "<s>",
  "eos_token": "</s>",
  "mask_token": {
    "content": "<mask>",
    "lstrip": true,
    "normalized": true,
    "rstrip": false,
    "single_word": false
  },
  "pad_token": "<pad>",
  "sep_token": "</s>",
  "unk_token": "<unk>"
}
```

#### 31. `pc/NoxirPlay.PC/models/nllb-200-ct2-int8/tokenizer_config.json`

```json
{
  "additional_special_tokens": null,
  "bos_token": "<s>",
  "cls_token": "<s>",
  "eos_token": "</s>",
  "mask_token": {
    "__type": "AddedToken",
    "content": "<mask>",
    "lstrip": true,
    "normalized": true,
    "rstrip": false,
    "single_word": false
  },
  "model_max_length": 1024,
  "name_or_path": "facebook/nllb-200-distilled-600M",
  "pad_token": "<pad>",
  "sep_token": "</s>",
  "sp_model_kwargs": {},
  "special_tokens_map_file": null,
  "src_lang": null,
  "tgt_lang": null,
  "tokenizer_class": "NllbTokenizer",
  "unk_token": "<unk>"
}
```

#### 32. `pc/NoxirPlay.PC/native/chiaki-bridge/CMakeLists.txt`

```cmake
cmake_minimum_required(VERSION 3.20)
project(noxir_chiaki_bridge C)

if(NOT DEFINED CHIAKI_SOURCE_DIR)
    message(FATAL_ERROR "CHIAKI_SOURCE_DIR must point to the Chiaki-NG source tree")
endif()

set(CHIAKI_ENABLE_GUI OFF CACHE BOOL "" FORCE)
set(CHIAKI_ENABLE_CLI OFF CACHE BOOL "" FORCE)
set(CHIAKI_ENABLE_TESTS OFF CACHE BOOL "" FORCE)
set(CHIAKI_ENABLE_STEAM_SHORTCUT OFF CACHE BOOL "" FORCE)
set(CHIAKI_ENABLE_FFMPEG_DECODER OFF CACHE STRING "" FORCE)
set(CHIAKI_ENABLE_PI_DECODER OFF CACHE STRING "" FORCE)
set(CHIAKI_ENABLE_SETSU OFF CACHE STRING "" FORCE)
set(CHIAKI_ENABLE_STEAMDECK_NATIVE OFF CACHE STRING "" FORCE)
set(CHIAKI_LIB_ENABLE_OPUS OFF CACHE BOOL "" FORCE)
set(CHIAKI_LIB_ENABLE_MBEDTLS OFF CACHE BOOL "" FORCE)
set(CHIAKI_USE_SYSTEM_CURL ON CACHE STRING "" FORCE)
set(CHIAKI_USE_SYSTEM_NANOPB OFF CACHE STRING "" FORCE)
set(CHIAKI_USE_SYSTEM_JERASURE OFF CACHE STRING "" FORCE)
set(CHIAKI_LIB_JSONC_EXTERNAL_PROJECT OFF CACHE BOOL "" FORCE)
set(CHIAKI_LIB_MINIUPNPC_EXTERNAL_PROJECT OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF CACHE BOOL "" FORCE)

add_subdirectory("${CHIAKI_SOURCE_DIR}" chiaki-ng)

add_library(noxir_chiaki_bridge SHARED noxir_chiaki_bridge.c)
target_link_libraries(noxir_chiaki_bridge PRIVATE chiaki-lib)
target_include_directories(noxir_chiaki_bridge PRIVATE "${CHIAKI_SOURCE_DIR}/lib/include")
set_target_properties(noxir_chiaki_bridge PROPERTIES
    OUTPUT_NAME "noxir-chiaki-bridge"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/out"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/out")

add_custom_command(TARGET noxir_chiaki_bridge POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "$<TARGET_FILE:noxir_chiaki_bridge>"
        "${CMAKE_CURRENT_SOURCE_DIR}/../libnoxir-chiaki-bridge.dll"
    VERBATIM)
```

#### 33. `pc/NoxirPlay.PC/native/chiaki-bridge/noxir_chiaki_bridge.c`

```c
#include <winsock2.h>
#include <windows.h>

#include <chiaki/common.h>
#include <chiaki/log.h>
#include <chiaki/regist.h>
#include <chiaki/session.h>

#include <stdint.h>
#include <stdio.h>
#include <string.h>

#define NOXIR_ERROR_CAPACITY 512
#define NOXIR_REGISTRATION_TIMEOUT_MS 30000

typedef struct noxir_registration_context_t
{
    HANDLE completed;
    int result;
    ChiakiRegisteredHost host;
    char last_log_message[NOXIR_ERROR_CAPACITY];
} NoxirRegistrationContext;

typedef struct noxir_stream_context_t
{
    ChiakiSession session;
    ChiakiLog log;
    HANDLE pipe;
    char error[NOXIR_ERROR_CAPACITY];
    volatile LONG stopping;
    volatile LONG failed;
    int initialized;
} NoxirStreamContext;

static NoxirStreamContext stream_context;
static PVOID vectored_exception_handler;
static void copy_text(char *destination, size_t capacity, const char *source);

static uintptr_t module_for_address(const void *address, char *module, size_t capacity)
{
    copy_text(module, capacity, "unknown");
    MEMORY_BASIC_INFORMATION memory_info;
    if (address && VirtualQuery(address, &memory_info, sizeof(memory_info)) == sizeof(memory_info) && memory_info.AllocationBase)
    {
        GetModuleFileNameA((HMODULE)memory_info.AllocationBase, module, (DWORD)capacity);
        return (uintptr_t)memory_info.AllocationBase;
    }
    return 0;
}

static LONG WINAPI native_exception_filter(EXCEPTION_POINTERS *exception)
{
    if (!exception || !exception->ExceptionRecord ||
        exception->ExceptionRecord->ExceptionCode != EXCEPTION_ACCESS_VIOLATION)
        return EXCEPTION_CONTINUE_SEARCH;

    char local_app_data[MAX_PATH];
    DWORD length = GetEnvironmentVariableA("LOCALAPPDATA", local_app_data, MAX_PATH);
    if (length == 0 || length >= MAX_PATH)
        return EXCEPTION_CONTINUE_SEARCH;

    char folder[MAX_PATH];
    char path[MAX_PATH];
    _snprintf(folder, sizeof(folder), "%s\\NOXIR Play", local_app_data);
    _snprintf(path, sizeof(path), "%s\\native-crash.log", folder);
    CreateDirectoryA(folder, NULL);

    EXCEPTION_RECORD *record = exception->ExceptionRecord;
    char module[MAX_PATH] = "unknown";
    uintptr_t exception_module_base = module_for_address(record->ExceptionAddress, module, sizeof(module));

    char message[2048];
    int count = _snprintf(message, sizeof(message),
        "NOXIR native exception: code=0x%08lX instruction=%p module=%s module_base=%p instruction_rva=0x%llX",
        record->ExceptionCode, record->ExceptionAddress, module, (void *)exception_module_base,
        (unsigned long long)(exception_module_base ? (uintptr_t)record->ExceptionAddress - exception_module_base : 0));
    if (record->ExceptionCode == EXCEPTION_ACCESS_VIOLATION && record->NumberParameters >= 2)
    {
        const char *operation = record->ExceptionInformation[0] == 0 ? "read" :
            record->ExceptionInformation[0] == 1 ? "write" : "execute";
        if (count > 0 && (size_t)count < sizeof(message))
            _snprintf(message + count, sizeof(message) - (size_t)count,
                " operation=%s target=%p", operation, (void *)record->ExceptionInformation[1]);
    }
#ifdef _WIN64
    if (record->ExceptionCode == EXCEPTION_ACCESS_VIOLATION && exception->ContextRecord)
    {
        uintptr_t stack_pointer = (uintptr_t)exception->ContextRecord->Rsp;
        MEMORY_BASIC_INFORMATION stack_info;
        if (VirtualQuery((const void *)stack_pointer, &stack_info, sizeof(stack_info)) == sizeof(stack_info) &&
            stack_info.State == MEM_COMMIT && (uintptr_t)stack_info.BaseAddress <= stack_pointer &&
            stack_pointer + sizeof(uintptr_t) <= (uintptr_t)stack_info.BaseAddress + stack_info.RegionSize)
        {
            uintptr_t return_address = *(const uintptr_t *)stack_pointer;
            char caller_module[MAX_PATH];
            uintptr_t caller_base = module_for_address((const void *)(return_address ? return_address - 1 : 0), caller_module, sizeof(caller_module));
            size_t used = strlen(message);
            if (used < sizeof(message))
                _snprintf(message + used, sizeof(message) - used,
                    " rsp=%p return=%p caller_module=%s caller_base=%p caller_rva=0x%llX", (void *)stack_pointer,
                    (void *)return_address, caller_module, (void *)caller_base,
                    (unsigned long long)(caller_base && return_address ? return_address - 1 - caller_base : 0));
        }
    }
#endif
    strncat(message, "\r\n", sizeof(message) - strlen(message) - 1);

    HANDLE file = CreateFileA(path, FILE_APPEND_DATA, FILE_SHARE_READ | FILE_SHARE_WRITE, NULL,
        OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (file != INVALID_HANDLE_VALUE)
    {
        DWORD written = 0;
        WriteFile(file, message, (DWORD)strlen(message), &written, NULL);
        FlushFileBuffers(file);
        CloseHandle(file);
    }
    return EXCEPTION_CONTINUE_SEARCH;
}

static void copy_text(char *destination, size_t capacity, const char *source)
{
    if (!destination || (uintptr_t)destination < 0x10000 || capacity == 0)
        return;

    if (!source)
        source = "";

    strncpy(destination, source, capacity - 1);
    destination[capacity - 1] = '\0';
}

static void registration_log(ChiakiLogLevel level, const char *message, void *user)
{
    (void)level;
    NoxirRegistrationContext *context = (NoxirRegistrationContext *)user;
    if (!context)
        return;
    copy_text(context->last_log_message, sizeof(context->last_log_message), message);
}

static void registration_finished(ChiakiRegistEvent *event, void *user)
{
    NoxirRegistrationContext *context = (NoxirRegistrationContext *)user;
    if (!context)
        return;
    if (event->type == CHIAKI_REGIST_EVENT_TYPE_FINISHED_SUCCESS && event->registered_host)
    {
        memcpy(&context->host, event->registered_host, sizeof(context->host));
        context->result = 0;
    }
    else if (event->type == CHIAKI_REGIST_EVENT_TYPE_FINISHED_CANCELED)
    {
        context->result = 2;
    }
    else
    {
        context->result = 1;
    }

    SetEvent(context->completed);
}

static void dummy_audio_header(ChiakiAudioHeader *header, void *user)
{
    (void)header;
    (void)user;
}

static void dummy_audio_frame(uint8_t *buf, size_t size, void *user)
{
    (void)buf;
    (void)size;
    (void)user;
}

static void stream_log(ChiakiLogLevel level, const char *message, void *user)
{
    (void)level;
    NoxirStreamContext *context = user ? (NoxirStreamContext *)user : &stream_context;
    copy_text(context->error, sizeof(context->error), message);
}

static void stream_cant_display(void *user, bool cant_display)
{
    NoxirStreamContext *context = user ? (NoxirStreamContext *)user : &stream_context;
    if (cant_display)
    {
        copy_text(context->error, sizeof(context->error), "PS5 bu ekranın akışına izin vermiyor (HDCP veya korumalı içerik).");
        InterlockedExchange(&context->failed, 1);
    }
}

static void stream_event(ChiakiEvent *event, void *user)
{
    NoxirStreamContext *context = user ? (NoxirStreamContext *)user : &stream_context;
    if (event && event->type == CHIAKI_EVENT_QUIT && event->quit.reason != CHIAKI_QUIT_REASON_STOPPED)
    {
        copy_text(context->error, sizeof(context->error), event->quit.reason_str ? event->quit.reason_str : chiaki_quit_reason_string(event->quit.reason));
        InterlockedExchange(&context->failed, 1);
    }
}

__declspec(dllexport) int __cdecl noxir_get_stream_error(char *error_message, size_t error_capacity)
{
    if (InterlockedCompareExchange(&stream_context.failed, 0, 0) == 0)
        return 0;
    copy_text(error_message, error_capacity, stream_context.error);
    return 1;
}

static bool stream_video_sample(uint8_t *buf, size_t size, int32_t frames_lost, bool recovered, void *user)
{
    (void)frames_lost;
    (void)recovered;
    NoxirStreamContext *context = (NoxirStreamContext *)user;
    if (InterlockedCompareExchange(&context->stopping, 0, 0) != 0 || size == 0)
        return false;

    if (context->pipe == INVALID_HANDLE_VALUE)
    {
        context->pipe = CreateFileA("\\\\.\\pipe\\noxirplay-remote-h264", GENERIC_WRITE, 0, NULL, OPEN_EXISTING, 0, NULL);
        if (context->pipe == INVALID_HANDLE_VALUE)
        {
            /* Pipe sunucusu (C# tarafı) henüz bağlantı kabul etmeye hazır değil.
               Bu callback'i sessizce atla; Chiaki bir sonraki video karesinde tekrar çağırır.
               failed=1 SETLEME: pipe hazır değil ≠ kalıcı hata. */
            return true;
        }
    }

    size_t offset = 0;
    while (offset < size)
    {
        if (InterlockedCompareExchange(&context->stopping, 0, 0) != 0)
            return false;

        DWORD written = 0;
        DWORD chunk = (DWORD)((size - offset) > 0x7ffff000 ? 0x7ffff000 : (size - offset));
        if (!WriteFile(context->pipe, buf + offset, chunk, &written, NULL) || written == 0)
        {
            CloseHandle(context->pipe);
            context->pipe = INVALID_HANDLE_VALUE;
            copy_text(context->error, sizeof(context->error), "Video aktarım kanalı kapandı.");
            InterlockedExchange(&context->failed, 1);
            return false;
        }
        offset += written;
    }
    return true;
}

__declspec(dllexport) int __cdecl noxir_start_ps5_stream(
    const char *host, const uint8_t *registration_key, const uint8_t *morning, char *error_message, size_t error_capacity)
{
    if (!host || !registration_key || !morning)
    {
        copy_text(error_message, error_capacity, "PS5 bağlantı bilgileri eksik.");
        return -20;
    }
    if (stream_context.initialized)
    {
        copy_text(error_message, error_capacity, "PS5 görüntü bağlantısı zaten açık.");
        return -21;
    }
    if (!vectored_exception_handler)
        vectored_exception_handler = AddVectoredExceptionHandler(1, native_exception_filter);
    /* SetUnhandledExceptionFilter kaldırıldı: .NET 8 CLR kendi handler'ını kurar,
       üzerine yazmak managed exception raporlamasını bozar.
       AddVectoredExceptionHandler(1,...) yetkili zaten ilk çağrılan handler'dır. */
    ChiakiErrorCode init_result = chiaki_lib_init();
    if (init_result != CHIAKI_ERR_SUCCESS)
    {
        copy_text(error_message, error_capacity, chiaki_error_string(init_result));
        return -22;
    }

    memset(&stream_context, 0, sizeof(stream_context));
    stream_context.pipe = INVALID_HANDLE_VALUE;
    chiaki_log_init(&stream_context.log, CHIAKI_LOG_ALL, stream_log, &stream_context);

    ChiakiConnectInfo info;
    memset(&info, 0, sizeof(info));
    info.ps5 = true;
    info.host = host;
    memcpy(info.regist_key, registration_key, sizeof(info.regist_key));
    memcpy(info.morning, morning, sizeof(info.morning));
    chiaki_connect_video_profile_preset(&info.video_profile, CHIAKI_VIDEO_RESOLUTION_PRESET_720p, CHIAKI_VIDEO_FPS_PRESET_60);
    info.video_profile.codec = CHIAKI_CODEC_H264;
    info.video_profile_auto_downgrade = true;
    info.audio_video_disabled = CHIAKI_AUDIO_DISABLED;
    info.enable_idr_on_fec_failure = true;
    info.packet_loss_max = 0.0;

    ChiakiErrorCode result = chiaki_session_init(&stream_context.session, &info, &stream_context.log);
    if (result != CHIAKI_ERR_SUCCESS)
    {
        copy_text(error_message, error_capacity, chiaki_error_string(result));
        return -23;
    }
    chiaki_session_set_event_cb(&stream_context.session, stream_event, &stream_context);
    chiaki_session_set_video_sample_cb(&stream_context.session, stream_video_sample, &stream_context);

    ChiakiAudioSink audio_sink = {0};
    audio_sink.user = &stream_context;
    audio_sink.header_cb = dummy_audio_header;
    audio_sink.frame_cb = dummy_audio_frame;
    stream_context.session.audio_sink = audio_sink;
    stream_context.session.haptics_sink = audio_sink;

    ChiakiCtrlDisplaySink display_sink = {0};
    display_sink.user = &stream_context;
    display_sink.cantdisplay_cb = stream_cant_display;
    chiaki_session_ctrl_set_display_sink(&stream_context.session, &display_sink);
    stream_context.initialized = 1;
    result = chiaki_session_start(&stream_context.session);
    if (result != CHIAKI_ERR_SUCCESS)
    {
        chiaki_session_fini(&stream_context.session);
        stream_context.initialized = 0;
        copy_text(error_message, error_capacity, chiaki_error_string(result));
        return -24;
    }
    copy_text(error_message, error_capacity, "");
    return 0;
}

__declspec(dllexport) void __cdecl noxir_stop_ps5_stream(void)
{
    if (!stream_context.initialized)
        return;
    InterlockedExchange(&stream_context.stopping, 1);

    // Kilitlenmeyi (deadlock) önlemek için önce pipe'ı kapat:
    // Bloklanmış herhangi bir WriteFile çağrısı derhal sonlanır.
    if (stream_context.pipe != INVALID_HANDLE_VALUE)
    {
        HANDLE pipe = stream_context.pipe;
        stream_context.pipe = INVALID_HANDLE_VALUE;
        CloseHandle(pipe);
    }

    chiaki_session_stop(&stream_context.session);
    chiaki_session_join(&stream_context.session);
    chiaki_session_fini(&stream_context.session);
    stream_context.initialized = 0;
}

__declspec(dllexport) int __cdecl noxir_request_idr(void)
{
    if (!stream_context.initialized || InterlockedCompareExchange(&stream_context.stopping, 0, 0) != 0)
        return -1;
    return chiaki_session_request_idr(&stream_context.session) == CHIAKI_ERR_SUCCESS ? 0 : -2;
}

__declspec(dllexport) int __cdecl noxir_register_ps5(
    const char *host,
    const uint8_t *account_id,
    uint32_t device_link_code,
    uint8_t *server_mac,
    char *server_nickname,
    size_t server_nickname_capacity,
    uint8_t *registration_key,
    uint32_t *rp_key_type,
    uint8_t *rp_key,
    char *error_message,
    size_t error_message_capacity)
{
    if (!host || !account_id || !server_mac || !server_nickname || !registration_key || !rp_key_type || !rp_key)
    {
        copy_text(error_message, error_message_capacity, "Eksik PS5 kayıt bilgisi.");
        return -10;
    }

    if (device_link_code > 99999999 || device_link_code < 10000000)
    {
        copy_text(error_message, error_message_capacity, "Cihaz bağlama kodu 8 haneli olmalı.");
        return -10;
    }

    ChiakiErrorCode init_result = chiaki_lib_init();
    if (init_result != CHIAKI_ERR_SUCCESS)
    {
        copy_text(error_message, error_message_capacity, chiaki_error_string(init_result));
        return -11;
    }

    NoxirRegistrationContext context;
    memset(&context, 0, sizeof(context));
    context.completed = CreateEventW(NULL, TRUE, FALSE, NULL);
    if (!context.completed)
    {
        copy_text(error_message, error_message_capacity, "PS5 kayıt işlemi başlatılamadı.");
        return -12;
    }

    ChiakiLog log;
    chiaki_log_init(&log, CHIAKI_LOG_ALL, registration_log, &context);

    ChiakiRegistInfo info;
    memset(&info, 0, sizeof(info));
    info.target = CHIAKI_TARGET_PS5_1;
    info.host = host;
    info.broadcast = false;
    memcpy(info.psn_account_id, account_id, CHIAKI_PSN_ACCOUNT_ID_SIZE);
    info.pin = device_link_code;
    info.console_pin = 0;
    info.holepunch_info = NULL;
    info.rudp = NULL;

    ChiakiRegist registration;
    memset(&registration, 0, sizeof(registration));
    ChiakiErrorCode start_result = chiaki_regist_start(&registration, &log, &info, registration_finished, &context);
    if (start_result != CHIAKI_ERR_SUCCESS)
    {
        copy_text(error_message, error_message_capacity, chiaki_error_string(start_result));
        CloseHandle(context.completed);
        return -13;
    }

    DWORD wait_result = WaitForSingleObject(context.completed, NOXIR_REGISTRATION_TIMEOUT_MS);
    if (wait_result != WAIT_OBJECT_0)
    {
        chiaki_regist_stop(&registration);
        copy_text(error_message, error_message_capacity,
                  wait_result == WAIT_TIMEOUT ? "PS5 yanıt vermedi. IP adresini ve aynı ağda olduğunu kontrol et." : "PS5 kayıt işlemi kesildi.");
        chiaki_regist_fini(&registration);
        CloseHandle(context.completed);
        return wait_result == WAIT_TIMEOUT ? -14 : -15;
    }

    chiaki_regist_fini(&registration);
    CloseHandle(context.completed);

    if (context.result != 0)
    {
        copy_text(error_message, error_message_capacity,
                  context.last_log_message[0] ? context.last_log_message : "PS5 bu kodla eşleştirilemedi.");
        return context.result;
    }

    memcpy(server_mac, context.host.server_mac, sizeof(context.host.server_mac));
    copy_text(server_nickname, server_nickname_capacity, context.host.server_nickname);
    memcpy(registration_key, context.host.rp_regist_key, sizeof(context.host.rp_regist_key));
    *rp_key_type = context.host.rp_key_type;
    memcpy(rp_key, context.host.rp_key, sizeof(context.host.rp_key));
    copy_text(error_message, error_message_capacity, "");
    return 0;
}
```

#### 34. `pc/NoxirPlay.PC/native/licenses/NOTICE.md`

```markdown
# Third-party notice

NOXIR Play's native PS5 registration bridge includes code from Chiaki-NG v1.10.1, built from commit `f30da0aaeb96fc0026cc03683153f682352e7d7c`.

- Upstream source: https://github.com/chiaki-ng/chiaki-ng
- License: AGPL-3.0-only-OpenSSL; see `Chiaki-NG-AGPL-3.0-only-OpenSSL.txt`.
- The bridge entry point was written for NOXIR Play and calls Chiaki-NG's registration API.
- Chiaki-NG is an independent third-party project and is not endorsed or certified by Sony.
```

#### 35. `tv/noxirplay-tv/app.js`

```javascript
(() => {
  const video = document.getElementById('hdmiVideo');
  const subtitle = document.getElementById('subtitleText');
  const debugHud = document.getElementById('debugHud');

  let config = {
    pcIp: '192.168.1.101',
    port: 8765,
    hdmiInput: 1,
    subtitleDurationMs: 6500,
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
    if (config.bottomPercent) {
      const overlay = document.getElementById('subtitleOverlay');
      if (overlay) overlay.style.bottom = config.bottomPercent;
    }
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

        if (packet.type === 'clear' || !packet.text) {
          subtitle.textContent = '';
          lastReceivedText = '';
          clearTimeout(clearTimer);
          return;
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
          lastReceivedText = text;
          updateDebug(`Altyazı: "${text}"`);

          clearTimeout(clearTimer);
          const duration = packet.durationMs || config.subtitleDurationMs || 6500;
          clearTimer = setTimeout(() => {
            if (subtitle.textContent === text) {
              subtitle.textContent = '';
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

  // 4. Kumanda Tuş Kontrolleri
  // - Mavi tuş (406) veya 'D': Durum / Debug HUD aç/kapat
  // - Sarı tuş (405) veya 'Y': Orijinal İngilizce altyazıyı tamamen gizleme (Kalıcı Siyah Maske) aç/kapat
  document.addEventListener('keydown', (e) => {
    const overlay = document.getElementById('subtitleOverlay');
    // 406: LG webOS Blue button, 68: 'D' key
    if (e.keyCode === 406 || e.keyCode === 68) {
      isDebugVisible = !isDebugVisible;
      if (debugHud) {
        debugHud.style.display = isDebugVisible ? 'block' : 'none';
      }
    }
    // 405: LG webOS Yellow button, 89: 'Y' key, 71: 'G' key
    else if (e.keyCode === 405 || e.keyCode === 89 || e.keyCode === 71) {
      const isHidden = overlay ? overlay.classList.toggle('mask-permanent') : false;
      updateDebug(`İngilizce Yazıyı Tamamen Gizle: ${isHidden ? 'AÇIK (Kalıcı Siyah Maske)' : 'KAPALI'}`);
      if (debugHud && !isDebugVisible) {
        debugHud.style.display = 'block';
        setTimeout(() => {
          if (!isDebugVisible) debugHud.style.display = 'none';
        }, 2500);
      }
    }
  });

  // Başlatma
  loadConfig().then(() => {
    initHdmiVideo();
    connectWebSocket();
    // Varsayılan olarak İngilizce altyazı bölgesini kalıcı siyah maskeyle tamamen kapat
    const overlay = document.getElementById('subtitleOverlay');
    if (overlay) overlay.classList.add('mask-permanent');
  });
})();
```

#### 36. `tv/noxirplay-tv/appinfo.json`

```json
{
  "id": "com.noxir.play.tv",
  "version": "1.0.0",
  "vendor": "NOXIR Play",
  "type": "web",
  "main": "index.html",
  "title": "NOXIR Play",
  "icon": "icon.png",
  "largeIcon": "icon.png",
  "resolution": "1920x1080",
  "supportTouchMode": false,
  "requiredPermissions": [
    "media.display"
  ],
  "requiredACG": [],
  "handlesRelaunch": true
}
```

#### 37. `tv/noxirplay-tv/config.json`

```json
{
  "pcIp": "192.168.1.101",
  "port": 8765,
  "hdmiInput": 1,
  "subtitleDurationMs": 6500,
  "fontSize": "38px",
  "bottomPercent": "7%"
}

```

#### 38. `tv/noxirplay-tv/index.html`

```html
<!doctype html>
<html lang="tr">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
  <title>NOXIR Play</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <!-- Tam ekran HDMI 1 PS5 Girişi -->
  <video id="hdmiVideo" class="fullscreen-video" autoplay playsinline>
    <source src="ext://hdmi:1" type="service/webos-external">
  </video>

  <!-- Şeffaf Türkçe Altyazı Katmanı -->
  <div id="subtitleOverlay" class="subtitle-overlay">
    <div id="subtitleText" class="subtitle-text" aria-live="polite"></div>
  </div>

  <!-- Yalnızca kumandadan Mavi tuş ile açılabilen gizli durum bilgisi -->
  <div id="debugHud" class="debug-hud"></div>

  <script src="app.js"></script>
</body>
</html>
```

#### 39. `tv/noxirplay-tv/style.css`

```css
* {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

html, body {
  width: 100%;
  height: 100%;
  margin: 0;
  padding: 0;
  overflow: hidden;
  background-color: #000000;
  color: #ffffff;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  user-select: none;
}

/* Tam ekran HDMI 1 video görüntüsü */
.fullscreen-video {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  object-fit: contain;
  background-color: #000000;
  z-index: 1;
  border: none;
  outline: none;
}

/* Altyazı katmanı - Ekranın alt bölgesinde kalıcı veya dinamik maske */
.subtitle-overlay {
  position: fixed;
  left: 0;
  right: 0;
  bottom: 5%;
  z-index: 10;
  display: flex;
  justify-content: center;
  align-items: center;
  pointer-events: none;
}

/* Kalıcı Siyah Maske Bandı: İngilizce yazıları tamamen kapatır, hiç göstermez */
.subtitle-overlay.mask-permanent {
  background: #000000;
  padding: 18px 0;
  box-shadow: 0 0 35px 20px #000000, 0 0 15px 5px #000000;
  min-height: 80px;
}

/* Altyazı metni - Okunabilir büyük font ve tam kapatıcı arka plan */
.subtitle-text {
  color: #ffffff;
  font-size: 40px;
  font-weight: 700;
  line-height: 1.35;
  text-align: center;
  text-shadow:
    0 2px 4px rgba(0, 0, 0, 1),
    0 4px 14px rgba(0, 0, 0, 1);
  padding: 8px 32px;
  max-width: 90%;
  word-wrap: break-word;
  white-space: pre-line;
  letter-spacing: 0.01em;
  min-height: 48px;
}

/* Kalıcı maske aktif değilken metin gelince devreye giren otomatik siyah bant */
.subtitle-overlay:not(.mask-permanent) .subtitle-text:not(:empty) {
  background: #000000 !important;
  border-radius: 8px;
  box-shadow: 0 0 25px 10px #000000;
  min-width: 50%;
}

.subtitle-overlay:not(.mask-permanent) .subtitle-text:empty {
  display: none;
}

/* İsteğe bağlı gizli durum bilgisi (Kumanda Mavi tuşu veya 'D' tuşuyla açılır) */
.debug-hud {
  position: fixed;
  top: 24px;
  left: 24px;
  z-index: 100;
  background: rgba(10, 14, 22, 0.88);
  border: 1px solid #2e384d;
  color: #3fcf8e;
  font-size: 15px;
  padding: 10px 16px;
  border-radius: 8px;
  font-family: monospace;
  display: none;
  pointer-events: none;
}
```

#### 40. `tv/Paketle.bat`

```bat
@echo off
setlocal
cd /d "%~dp0.."
echo [NOXIR Play] LG webOS TV uygulamasi paketleniyor...
call ares-package.cmd tv\noxirplay-tv -o tv\dist
if %ERRORLEVEL% equ 0 (
    echo.
    echo [BASARILI] tv\dist\com.noxir.play.tv_1.0.0_all.ipk olusturuldu!
) else (
    echo.
    echo [HATA] Paketleme basarisiz oldu.
)
echo.
pause
```

#### 41. `tv/TV_Baglanti_Ayarla.bat`

```bat
@echo off
setlocal
cd /d "%~dp0.."
echo =======================================================
echo [NOXIR Play] LG webOS TV Baglanti Bilgilerini Guncelle
echo =======================================================
echo.
echo TV'deki "Developer Mode" uygulamasindaki bilgileri girin:
echo.
set /p TV_IP="TV IP Adresi (ornek 192.168.1.31): "
set /p TV_PASS="Passphrase (TV ekranindaki 6 karakterli kod): "

if "%TV_IP%"=="" (
    echo [HATA] IP adresi bos birakilamaz.
    pause
    exit /b 1
)

echo.
echo Cihaz yapilandiriliyor...
call ares-setup-device.cmd -m noxir-tv -i "host=%TV_IP%" -i "port=9922" -i "username=prisoner" -i "passphrase=%TV_PASS%"
if %ERRORLEVEL% neq 0 (
    call ares-setup-device.cmd -a noxir-tv -i "host=%TV_IP%" -i "port=9922" -i "username=prisoner" -i "passphrase=%TV_PASS%"
)

echo.
echo TV anahtari (SSH key) aliniyor...
call ares-novacom.cmd --getkey -d noxir-tv
echo.
echo Test ediliyor:
call ares-device.cmd -i -d noxir-tv
echo.
pause
```

#### 42. `tv/TVye_Yukle_ve_Baslat.bat`

```bat
@echo off
setlocal
cd /d "%~dp0.."

echo =======================================================
echo [NOXIR Play] LG webOS TV'ye Yukleme ve Baslatma
echo =======================================================

set "IPK=tv\dist\com.noxir.play.tv_1.0.0_all.ipk"
if not exist "%IPK%" (
    echo [BILGI] IPK paketi bulunamadi, once paketleniyor...
    call ares-package.cmd tv\noxirplay-tv -o tv\dist
)

echo.
echo 1. TV'ye paket yukleniyor (noxir-tv)...
call ares-install.cmd -d noxir-tv "%IPK%"
if %ERRORLEVEL% neq 0 (
    echo.
    echo [UYARI] TV baglantisi saglanamadi!
    echo Lutfen sunlari kontrol edin:
    echo 1. TV acik mi ve ayni Wi-Fi/Ethernet agina bagli mi?
    echo 2. TV'de "Developer Mode" uygulamasinda "Key Server" ON durumunda mi?
    echo 3. TV'nin IP adresi degisti mi? (Gerekiyorsa TV_Baglanti_Ayarla.bat calistirin)
    echo.
    pause
    exit /b 1
)

echo.
echo 2. TV'de NOXIR Play baslatiliyor...
call ares-launch.cmd -d noxir-tv com.noxir.play.tv
if %ERRORLEVEL% equ 0 (
    echo.
    echo =======================================================
    echo [BASARILI] NOXIR Play televizyonda acildi!
    echo PS5'in HDMI 1 goruntusu ekranda olmali.
    echo =======================================================
) else (
    echo.
    echo [HATA] Uygulama baslatilamadi.
)

echo.
pause
```

#### 43. `electron-react-ts/package.json`

```json
{
  "name": "pc-app-example",
  "version": "1.0.0",
  "main": "dist/main/main.js",
  "scripts": {
    "dev": "concurrently \"npm run dev:main\" \"npm run dev:renderer\"",
    "dev:main": "tsc -p tsconfig.main.json --watch",
    "dev:renderer": "vite",
    "build": "npm run build:main && npm run build:renderer",
    "build:main": "tsc -p tsconfig.main.json",
    "build:renderer": "vite build",
    "preview": "electron dist/main/main.js"
  },
  "dependencies": {
    "electron": "^28.0.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "zustand": "^4.4.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "@vitejs/plugin-react": "^4.2.0",
    "concurrently": "^8.2.0",
    "typescript": "^5.3.0",
    "vite": "^5.0.0",
    "electron-builder": "^24.9.0"
  }
}
```

---

> **Rapor sonu.** Bu belge, proje dosyalarının tamamı taranarak otomatik oluşturulmuştur.
> Eklerdeki dosya içerikleri, incelenen çalışma ağacının son halini yansıtır.
