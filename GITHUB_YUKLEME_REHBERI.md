# NOXIR Play - Web Sitesi, GitHub Pages & Shopier Rehberi

Bu rehber, **NOXIR Play** tanıtım ve satış web sitesini **kaynak kodlarınızı (C#, Python, yapay zeka modelleri) asla açık kaynak yapmadan**, tamamen güvenli bir şekilde GitHub Pages üzerinde nasıl yayınlayacağınızı ve **Shopier** ödeme sistemini nasıl bağlayacağınızı açıklar.

---

## 🔒 1. Güvenlik Güvencesi: Kaynak Kodlar Nasıl Korunuyor?

* **Ana Proje Dizininde Git Yok:** Projenin C# kaynak kodları (`pc/`), Python köprüsü (`runtime/`) ve yapay zeka modelleri (`models/`) ana dizinde saklı kalır.
* **Yalnızca `website/` Klasörü Yüklenir:** Hazırlanan `website_github_yukle.bat` betiği yalnızca `website/` klasörünün içine girip Git başlatır. Bu sayede GitHub'a sadece:
  * `index.html` (Tanıtım sayfası, interaktif simülatör, uygulama arayüzü)
  * `style.css` (PlayStation & Cyberpunk temalı modern tasarım)
  * `script.js` (Lazer OCR taramalı canlı PS5 çeviri simülasyonu & Shopier yönlendirmesi)
  * `assets/` (Logo ve simgeler)
  yüklenir.
* **Sonuç:** Milyonlarca satır kodunuz, tescilli modelleriniz ve fikri mülkiyetiniz **%100 gizli ve güvende kalır**.

---

## 🚀 2. Web Sitesini GitHub'a Yükleme ve Yayına Alma (GitHub Pages)

### 1. Adım: GitHub'da Yeni Bir Depo (Repository) Açın
1. [GitHub](https://github.com)'a giriş yapın.
2. Sağ üstteki **+** simgesinden **New repository** seçin.
3. Repository name: `noxir-play` (veya istediğiniz bir isim).
4. **Public** seçin (GitHub Pages'in ücretsiz çalışabilmesi için deponun Public olması gerekir; merak etmeyin içinde sadece web arayüzü dosyaları olacaktır).
5. "Add a README file" seçeneğini **işaretlemeyin** (boş depo olsun).
6. **Create repository** butonuna basın.
7. Sayfada çıkan `.git` uzantılı HTTPS adresinizi kopyalayın (Örn: `https://github.com/kullaniciadi/noxir-play.git`).

### 2. Adım: Tek Tıkla Yükleyin
1. Masaüstündeki `test` klasöründe bulunan **`website_github_yukle.bat`** dosyasına çift tıklayın.
2. Konsol ekranında kopyaladığınız GitHub repo adresini yapıştırıp `Enter` tuşuna basın.
3. Dosyalar birkaç saniyede GitHub'a yüklenecektir.

### 3. Adım: GitHub Pages'i Aktif Edin (Siteniz Canlıya Geçsin)
1. GitHub'da repo sayfanıza gidin.
2. Üst menüden **Settings** (Ayarlar) -> sol menüden **Pages** sekmesine tıklayın.
3. **Build and deployment** başlığı altında:
   * **Source:** `Deploy from a branch`
   * **Branch:** `main` / `/(root)` seçin.
4. **Save** butonuna tıklayın.
5. 1-2 dakika içinde siteniz dünya çapında şu adreste yayında olacaktır:
   👉 **`https://kullaniciadi.github.io/noxir-play/`**

---

## 🛒 3. Shopier Entegrasyonu & 1.89 GB Setup Dağıtımı

Uygulamanız ücretli olduğu için kaynak kod veya kurulum dosyasını doğrudan GitHub'da herkese açık bırakmak yerine **Shopier** üzerinden satışa sunacaksınız.

### 1. Adım: Shopier'de Ürün Açın
1. [Shopier](https://www.shopier.com) satıcı panelinize giriş yapın.
2. **Ürünler -> Yeni Ürün Ekle** seçin.
3. Ürün Tipi: **Dijital Ürün** seçin.
4. Ürün Başlığı: `NOXIR Play v1.0 - PS5 Canlı Yapay Zeka Çeviri Programı`
5. Fiyat: `399 TL` (veya belirlediğiniz fiyat).
6. Ürün Açıklaması: Web sitesindeki özellik özetini ve sistem gereksinimlerini ekleyin.
7. Görsel: `website/assets/icon.png` veya uygulama ekran görüntüsü yükleyin.

### 2. Adım: 1.89 GB Setup Dosyasını Buluta Yükleyin
`NOXIR_Play_Setup_v1.0.exe` (1.89 GB) dosyasını şu platformlardan birine yükleyin:
* **Google Drive** (Bağlantıya sahip olan herkes indirebilir yapın)
* **Mega.nz** veya **Yandex Disk** / **OneDrive**
* Shopier'de ürün ayarlarından **"Sipariş Sonrası Otomatik İndirme / Mesaj"** alanına bu Google Drive indirme bağlantınızı yapıştırın.
* Müşteri kredi kartıyla ödeme yaptığı an Shopier Setup indirme linkini müşteriye otomatik olarak verir.

### 3. Adım: Web Sitesine Shopier Linkinizi Ekleyin
1. `website/script.js` dosyasını Not Defteri veya VS Code ile açın.
2. En baştaki satıra bakın:
   ```javascript
   const SHOPIER_DEFAULT_URL = "https://www.shopier.com/ShowProductNew/products.php?id=BURAYA_URUN_KODUNUZ";
   ```
3. `https://www.shopier.com/` yerine Shopier'deki ürününüzün tam linkini yapıştırın ve kaydedin.
4. `website_github_yukle.bat` dosyasını tekrar çalıştırarak güncellemeyi GitHub'a gönderin.

---

## 🌟 4. Web Sitesinde Neler Var?

Web sitesi müşterilerin satın alma kararını hızlandırmak için baştan sona optimize edilmiştir:
1. **Canlı Video Tanıtım & Çeviri Simülatörü (`#demo`):**
   * HTML5 Canvas tabanlı dinamik PS5 oyun içi ortamı (sinematik arka plan ve parçacıklar).
   * Lazer OCR tarama çizgisi (PP-OCRv6 simülasyonu).
   * Sahne değiştirme: God of War Ragnarök, The Last of Us Part I, Cyberpunk 2077.
   * Canlı telemetri HUD: 11 ms CTranslate2 INT8 çeviri gecikmesi, 60 FPS göstergesi.
2. **Resmi Uygulama Arayüzü Vitrini (`#arayuz`):**
   * WPF masaüstü programının birebir koyu temalı cam arayüzü.
   * Çalışır sekmeler: **Ana Sayfa**, **Çeviri Ayarları**, **LG TV'ye Yükle**, **Kullanım Kılavuzu**.
3. **Shopier Satın Alma Penceresi (Modal):**
   * Özel lansman fiyatı (399 TL), ömür boyu lisans vurgusu, SSL & 3D Secure güven rozetleri.
4. **Tek Tıkla Kurulum Vurgusu (`#kurulum`):**
   * Müşteriye harici hiçbir şey kurmasına gerek olmadığı, sadece `NOXIR_Play_Setup_v1.0.exe` dosyasını çalıştırmasının yeterli olduğu net bir dille anlatılmaktadır.
