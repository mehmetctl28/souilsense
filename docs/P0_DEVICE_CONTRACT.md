# P0 cihaz sözleşmesi ve geçiş notları

Güncelleme: 24 Kasım 2026. Bu sözleşme P0 dalındaki uygulama ve database.rules.json içindir.
Canlı Firebase'e yayımlanmadı; mevcut ESP32 firmware'i bulunamadı ve donanım üzerinde doğrulanmadı.

## Uyum sınırı

Bu değişiklik bir cihaz protokolü geçişidir (protocolVersion: 2). Eski firmware'in
pumpCommands içindeki actualState alanını yazması artık desteklenmez.
Cihaz onayı ayrı pumpStatus yolundadır. Uygulama eski firmware verisini gösterebilir,
ancak güncel v2 telemetri ve v2 pompa durumu olmadan gerçek bir başlatma komutu göndermez.

İlk teslim uygulamadan manuel sulamadır. Uygulamanın başlattığı otomatik sulama,
uygulama çalışırken gelen ölçümlere bağlıdır. Telefon kapalıyken kendi kendine sulama
bu değişikliğin kapsamına dahil değildir. Süre sonunda röleyi kapatma cihazın bağımsız sorumluluğudur.

## Kimlik ve eşleştirme

- İnsan kullanıcısı Firebase Auth ile giriş yapar. device özel yetkisi olmayan hesaplar kullanıcıdır.
- ESP32, kendi Firebase Auth kimliğine ve güvenilir yönetim ortamından atanmış
  device: true, sensorId: "sensor1" özel yetkilerine sahip olmalıdır.
  Uygulama veya kart bu yetkileri kendine atayamaz.
- Cihaz yalnızca kendi telemetrisini ve pompa durumunu yazar; kullanıcı bu iki alanı yazamaz.
- Yönetim ortamı pairingCodes/sensor1 altında {code, expiresAt} oluşturur.
  code cihaz başına benzersiz, en az 128 bit rastgelelik taşıyan bir sır olmalıdır
  (örneğin 16 rastgele baytın 32 haneli hex gösterimi). expiresAt Unix milisaniyedir.
  Kurallar 16-128 karakter kabul eder; sır üretiminin rastgeleliği yönetim ortamında sağlanır.
- pairingCodes kullanıcıya ve cihaza okunamaz/yazılamaz. Kod cihaz etiketi veya
  güvenilir cihaz kurulum sürecinden kullanıcıya verilir; uygulama veritabanından kodu indirmez.
- Kullanıcı bitki ayrıntısında kodu girer. Uygulama
  sensorOwners/sensor1 = {uid: "<kullanıcı UID>", claimCode: "<girilen kod>"}
  kaydını yazar. Kurallar kodu, süreyi ve UID'yi denetler; kayıt yalnızca boşsa oluşturulur.
  Aynı anda iki sahiplenmeden en fazla biri kabul edilir.
- Sahiplik kullanıcı tarafından silinemez/değiştirilemez. Yeniden eşleştirme veya cihaz devri
  yönetim ortamında, yeni kod üretilerek yapılır. Eski scalar UID sahiplikleri okunabilir.
- Kullanıcı hesabının projeye yönetici olarak davet edilmesi ile uygulama son kullanıcısının
  Firebase Auth kimliği farklıdır. Mobil uygulamaya yönetim anahtarı koyulmaz.

## Veri yolları

### Cihazdan ölçüm: sensors/{sensorId}/current

Alanlar: protocolVersion (2), moisture (0-100), temperature (-50..100 C),
light (0-100), lastUpdate (Unix ms). rawAdc (0-4095 tam sayı) isteğe bağlıdır.

Cihaz sunucu saatiyle uyumlu gerçek zaman kullanır; millis() duvar saati değildir.
Yazma kuralları 60 saniyeden eski veya 5 saniyeden fazla gelecekteki paketleri reddeder.
Uygulama gelecekteki zamanı güncel kabul etmez. Paket eksik/bozuksa otomatik sulama yapılmaz.
Eski kayıtları okumada makul Unix saniye değerleri normalize edilir; v2 yazımı milisaniyedir.

### Kullanıcıdan ayar: sensorConfigs/{sensorId}

İzinli alanlar:
- dryAdcValue / wetAdcValue: 0-4095; aralarında en az 200 fark.
- readIntervalSeconds: 1-3600.
- maxPumpSeconds: 1-30.
- minMoisture / maxMoisture: 0-100, alt eşik üst eşikten küçük.
- autoWatering: boolean.

Bu mod ayarı uygulamanın otomatik komut üretmesini açar/kapatır. ESP32 ayrıca kendi
otonom sulama algoritmasını bu işaretle başlatmamalıdır; iki bağımsız denetleyici
aynı cihazı yönetirse günlük limit/komut akışı bozulur.

### Kullanıcıdan komut: pumpCommands/{sensorId}

| Alan | Anlam |
| --- | --- |
| protocolVersion | 2 |
| commandId | Her kullanıcı isteği için yeni, benzersiz kimlik |
| requestedState | true = başlat; false = durdur |
| automatic | Otomatik başlatma için true; manuel/durdurma için false |
| maxDurationSeconds | 1-30; cihaz ayarındaki sınırı aşamaz |
| issuedAt | Sunucu saat farkı uygulanmış istek zamanı, Unix ms |
| expiresAt | issuedAt + 20000 |
| dayStart | UTC gün başlangıcı, Unix ms |
| autoCount | O gün kabul edilmiş otomatik başlatma sayısı, 0-3 |
| lastAutoAt | Son kabul edilmiş otomatik başlatma zamanı; yoksa 0 |

Komut ve limit alanları aynı Firebase transaction içinde güncellenir.
Giriş-çıkış, uygulamanın yeniden kurulması veya ikinci telefon limiti sıfırlayamaz.
Otomatik başlatmalar arasında en az 30 dakika bulunur; bu bekleme gece yarısında sıfırlanmaz.
Günlük sayaç UTC gece yarısında yeni güne geçer. Cihaz onay vermese de kabul edilmiş
otomatik komut kotadan düşer; başarısızlıkta otomatik geri alma yapılmaz.
Manuel/durdurma komutu mevcut sayaç ve son otomatik zamanı korur.

Kurallar yalnızca son 5 saniyede üretilmiş istekleri kabul eder.
Uygulama bağlantı yokken komut başlatmaz; işlem tekrar denense bile issuedAt yenilenmez.
Aynı cihazda bekleyen/çalışan başlatma varken yeni başlatma reddedilir.
Durdurma mevcut çalışmayı sonlandırmak için yeni commandId ile gönderilir.
Durdurma komutunda süre alanı 1 olarak taşınır; cihaz bu değeri beklemeden röleyi kapatır.
Eski actualState, autoWatering, updatedAt, timedOut alanları bu yola yazılmaz.

### Cihazdan onay: pumpStatus/{sensorId}

Alanlar: protocolVersion (2), commandId, actualState (boolean), state,
updatedAt (Unix ms). state: idle, running, completed veya rejected.

- Henüz komut yokken commandId boş ve state idle, actualState false olabilir.
- Komut varsa onay o anki commandId ile eşleşmelidir.
- running yalnızca actualState true ile yazılır.
- completed/rejected/idle yalnızca actualState false ile yazılır.
- Aynı commandId tamamlandı veya reddedildi ise durum idle/running olarak geri alınamaz;
  cihaz bu sonucu koruyarak heartbeat gönderir. Yeni işlem için yeni komut kimliği gerekir.
- Kullanıcı bu yolu yazamaz; yalnızca ilgili cihazın kimliği yazabilir.
- Cihaz durumu en geç 20 saniyede bir yenilenmelidir. Uygulama 60 saniyeden eski
  durumu kesin açık/kapalı bilgisi olarak göstermez.
- Onay gelmemesi rölenin kapalı olduğu anlamına gelmez; uygulama bu durumda
  "cihaz durumu bilinmiyor" gösterir.

## Firmware'de uygulanması ve fiziksel olarak doğrulanması gerekenler

1. Açılışta ve yeniden başlatmada röleyi kapalı tut.
2. Cihaz kimliğini ve gerçek saati hazırlamadan pompa açma.
3. Komutun protokolünü, kimliğini, geçerlilik süresini ve 1-30 saniye sınırını denetle.
4. İşlenmiş commandId değerlerini yeniden uygulama. Son işlenen kimliği/sonuçları
   yeniden başlama sonrasında da koru; saati geçmiş komutu hiçbir durumda oynatma.
5. Röleyi açarken yerel, bloklanmayan bir süre sınırı başlat.
   Firebase/Wi-Fi çağrısı bloklansa veya uygulama kapansa da süre dolunca fiziksel röleyi kapat.
6. Açılışı aynı commandId ile running olarak onayla.
7. Süre dolduğunda röleyi kapatıp completed ve actualState false yaz.
8. requestedState false komutunda röleyi kapat ve yeni kimlikle sonucu bildir.
9. Bağlantı geri geldiğinde önce fiziksel durumu bildir; kuyruğa düşmüş eski başlatmayı çalıştırma.
10. İnternet kesintisi, uygulamanın kapanması ve kartın yeniden başlatılmasıyla gerçek pompa testi yap.

Bu firmware davranışları şu anda uygulandı veya test edildi sayılmıyor (R01, R03, R08 açık).

## Eski projeden geçiş sırası

1. Ayrı test ortamında örnek cihaz ve kullanıcıyla bu sözleşmeyi kur.
2. Mevcut sahiplik, ayarlar ve gerekli geçmişin yedeğini al; aktif pompayı kapat.
3. Firmware'i v2 için güncelle; cihaz yetkilerini yönetim ortamında sağla.
4. Test ortamında kuralları yükle; geçerli ve geçersiz akışları dene.
5. Eski sensorConfigs alanlarını (ownerUid, hardwareMode vb.) temizle; geçerli alanları koru.
   maxPumpSeconds değerini 1-30 aralığına getir.
6. Eski pumpCommands kaydını kontrollü biçimde dönüştür; o günkü limit ve son sulama
   bilgisi varsa koru. Sayaç kaybını yeni sulama izni gibi yorumlama.
7. Yeni uygulama, kurallar ve cihaz birlikte doğrulandıktan sonra canlı geçişi planla.
   Yeni kurallar eski istemci/firmware yazımlarıyla uyumlu değildir; tek başına yayımlama.
8. Geri dönüş gerekiyorsa pompa kapalıyken uygulama, kurallar ve firmware sürümlerini
   birlikte ele al. Yalnızca kuralları gevşeterek geçiş sorununu çözme.

## Yerel doğrulama

Canlı Firebase veya gerçek pompa kullanmadan:

- flutter test --no-pub
- flutter analyze --no-pub --no-fatal-infos
- flutter build apk --debug --target-platform android-x64 --no-pub
- Firebase CLI ile: firebase emulators:exec --only database --project demo-soilsense-p0 "node tool/test_database_rules.mjs"

Alternatif: FIREBASE_DATABASE_EMULATOR_JAR değişkenini resmi Database Emulator JAR
dosyasına ayarlayıp node tool/test_database_rules.mjs çalıştır. Java ve Node gerekir.
Test aracı yalnızca 127.0.0.1/localhost ve demo-soilsense-p0 ad alanını kullanır;
test verisi gerçek projeye gönderilmez. Özel bir Java yolu gerekiyorsa JAVA_EXE ayarlanabilir.

## Firmware arama kaydı

24 Kasım 2026'da:
- Bu deponun erişilebilir Git geçmişi/dalları ve README'si tarandı.
- Mehmet'in erişilebilir souilsense ve pokelife depolarında firmware dosyası bulunamadı.
- Yerel ChatGPT proje klasörleri, varsa Arduino/PlatformIO klasörleri, Masaüstü ve
  İndirilenler içinde .ino, platformio.ini ve ilgili firmware/ESP32 arşivleri arandı.
- Erişilemeyen özel depo, başka bilgisayar veya kart üzerindeki mevcut firmware
  bu aramanın kapsamına girmedi. Kaynak ve gerçek cihaz doğrulaması halen bekleniyor.

## Kaynaklar

- https://firebase.google.com/docs/database/flutter/read-and-write
- https://firebase.google.com/docs/reference/security/database
- https://firebase.google.com/docs/emulator-suite/connect_rtdb
