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
