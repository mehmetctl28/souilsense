# 🌱 SoilSense — Akıllı Bitki Telemetri ve Otonom Sulama Sistemi

SoilSense; **ESP32** mikrodenetleyicilerinden gelen toprak nemi, ortam sıcaklığı, ışık şiddeti ve ham ADC verilerini **Firebase Realtime Database** üzerinden gerçek zamanlı işleyen, bitki türüne özel bilimsel eşik değerlerine göre otonom sulama kararları veren **Flutter** tabanlı bir IoT uygulamasıdır.

---

## 🚀 Temel Sistem Özellikleri

* **Çift Modlu Mimari (Dual-Mode IoT Engine):**
  * **Simülasyon Modu (`isHardwareMode = false`):** Fiziksel ESP32 bağlı değilken uygulama içi telemetri simülatörüyle tüm eşik, görev ve grafik algoritmalarını test eder. Gerçek Firebase `/sensors` düğümlerini **ezmez**.
  * **Donanım Modu (`isHardwareMode = true`):** Yalnızca fiziksel ESP32'den gelen telemetri paketlerini okur. Pompa komutlarında (`pumpCommands`) cihazdan `actualState` onayı bekler ve 20 saniyelik **Watchdog** zaman aşımı koruması uygular.
* **Plant Intelligence 2.0 Analiz Motoru:**
  * **Bitkiye Özel Bakım Profilleri:** Her bitki için `minMoisture`, `maxMoisture`, `minTemp`, `maxTemp`, `minLight`, `maxLight` sınırları tanımlanır.
  * **Veri Tazeliği Kontrollü Sağlık Skoru:** Sensör çevrimdışıysa eski veriyi "güncel" gibi sunmaz; *"Son Bilinen Ölçüme Göre"* olarak etiketler.
  * **Gerçek Saatlik Kuruma Hızı (Drying Rate):** Zaman damgalı geçmişten ($\Delta \text{Nem} / \Delta \text{Saat}$) toprağın saatlik su kaybını ve kritik sınıra kalan süreyi hesaplar.
  * **Sulama Sonrası Etki Analizi (Watering Response):** Sulama öncesi ve sonrası nem artışını karşılaştırarak pompanın/su deposunun gerçekten işe yarayıp yaramadığını doğrular.
  * **Donanım ve Kalibrasyon Tanılama:** Ham ADC uç değerlerini (`<100` veya `>4000`), ardışık kilitlenmiş ölçümleri ve donmuş (flatline) sensör verilerini tespit eder.
* **Gerçek Zaman Serisi Grafikleri (`MoistureChart`):** Yapay veri üretmez; 24 saatlik ve 7 günlük gerçek telemetri noktalarını Min / Maks / Ortalama istatistikleriyle çizer.
* **Cihaz Sağlık Merkezi (`Device Health Center`):** Tüm ESP32 düğümlerinin ADC kalibrasyon sınırlarını, son paket gecikmelerini ve pompa yanıt durumlarını tek ekranda listeler.

---

## 📂 Proje Klasör ve Mimari Yapısı

Uygulama **Provider** durum yönetimi (`MultiProvider` + `ChangeNotifierProxyProvider`) ile katmanlı olarak tasarlanmıştır:

```text
lib/
├── main.dart                        # Senkron SharedPreferences yüklemesi ve Provider ağacı
├── constants/
│   ├── colors.dart                  # Uygulama renk paleti ve durum renkleri
│   └── plant_data.dart              # Bitki kataloğu ve rehber verileri
├── models/
│   ├── plant.dart                   # Bitki modeli ve türe özel varsayılan bilimsel eşikler
│   ├── sensor_data.dart             # SensorData, SensorConfig (ADC dönüşümü), TelemetryPoint
│   └── todo.dart                    # Unix timestamp (DateTime) tabanlı görev modeli
├── providers/
│   ├── auth_provider.dart           # Firebase Auth oturum yönetimi (15sn timeout korumalı)
│   ├── plant_provider.dart          # Kullanıcı bazlı (users/{uid}/plants) bitki yönetimi
│   ├── sensor_provider.dart         # Yetkili sensör dinleyicileri, otonom sulama ve Watchdog
│   ├── todo_provider.dart           # Durum imzalı (signature-based) otomatik görev senkronizasyonu
│   └── theme_provider.dart          # Kalıcı Açık / Koyu tema yönetimi
├── services/
│   └── plant_intelligence.dart      # Plant Intelligence 2.0 analiz ve tanılama algoritmaları
├── screens/
│   ├── home_screen.dart             # Bahçe Durum Özeti, Hızlı Sulama ve Telemetri Simülatörü
│   ├── my_plants_screen.dart        # Filtreleme, sıralama, hızlı sulama ve Sensör ID değiştirme
│   ├── plant_detail_screen.dart     # Canlı telemetri, Zekâ 2.0 kartları ve ADC Kalibrasyon Sihirbazı
│   ├── explore_screen.dart          # Bitki kütüphanesi ve bakım rehberleri
│   ├── settings_screen.dart         # Donanım/Simülasyon anahtarı, güvenlik sınırları ve bildirim testi
│   └── login_screen.dart            # Kullanıcı giriş ve kayıt ekranı
└── widgets/
    ├── moisture_chart.dart          # Gerçek zaman serisi grafikleri (24 Saat / 7 Gün)
    ├── device_health_sheet.dart     # ESP32 donanım ve sensör sağlık merkezi
    ├── todo_list.dart               # Gerçek takvim seçicili Aktif / Otomatik / Manuel görev listesi
    └── quick_action_button.dart     # Ana ekran hızlı işlem bileşeni
```

---

## 🔥 Firebase Realtime Database Şeması (Veri Sözleşmesi)

Kullanıcı verileri `users/{uid}` altında izole edilir. Uygulama tüm `/sensors` ağını dinlemez; yalnızca kullanıcının bitkilerine eşleştirdiği sensör düğümlerine bireysel abonelik açar:

```json
{
  "users": {
    "USER_UID": {
      "plants": {
        "PLANT_ID": {
          "name": "Salon Orkidem",
          "type": "Orkide",
          "sensorId": "sensor1",
          "minMoisture": 30,
          "maxMoisture": 75,
          "minTemp": 19.0,
          "maxTemp": 27.0,
          "minLight": 30.0,
          "maxLight": 75.0
        }
      },
      "todos": {
        "auto_water_PLANT_ID": {
          "title": "Sula: Salon Orkidem",
          "isAuto": true,
          "isCompleted": false,
          "dueTimestamp": 1762900000000
        }
      },
      "sensorHistory": {
        "sensor1": {
          "1762900000000": { "moisture": 48.5, "temperature": 23.4, "light": 62.0 }
        }
      },
      "wateringEvents": {
        "sensor1": {
          "EVENT_ID": { "title": "Pompa Komutu: AÇIK", "timestamp": 1762900000000, "type": "watering" }
        }
      },
      "alerts": {
        "sensor1": {
          "ALERT_ID": { "title": "Kritik Nem Uyarısı", "timestamp": 1762900000000, "type": "alert" }
        }
      }
    }
  },
  "sensorOwners": {
    "sensor1": "USER_UID"
  },
  "sensors": {
    "sensor1": {
      "current": {
        "moisture": 48.5,
        "temperature": 23.4,
        "light": 62.0,
        "rawAdc": 2150,
        "lastUpdate": 1762900000000
      },
      "history": {
        "1762900000000": {
          "moisture": 48.5,
          "temperature": 23.4,
          "light": 62.0
        }
      }
    }
  },
  "pumpCommands": {
    "sensor1": {
      "requestedState": false,
      "actualState": false,
      "autoWatering": true,
      "maxDurationSeconds": 15,
      "updatedAt": 1762900000000,
      "timedOut": false
    }
  },
  "sensorConfigs": {
    "sensor1": {
      "ownerUid": "USER_UID",
      "dryAdcValue": 3200,
      "wetAdcValue": 1400,
      "readIntervalSeconds": 60,
      "maxPumpSeconds": 15,
      "minMoisture": 30,
      "maxMoisture": 75,
      "hardwareMode": true
    }
  }
}
```

---

## 🔌 ESP32 Donanım Entegrasyon Kuralları

ESP32 tarafında kod geliştirirken mobil uygulamayla tam uyum için aşağıdaki 3 kurala uyulmalıdır:

1. **Telemetri Gönderimi (`/sensors/{sensorId}/current`):**
   * `moisture` (0–100), `temperature` (°C), `light` (0–100), `rawAdc` (0–4095) ve `lastUpdate` (Unix ms veya saniye) gönderilmelidir.
   * Uygulama `rawAdc` gönderildiğinde `sensorConfigs/{sensorId}` içindeki `dryAdcValue` ve `wetAdcValue` sınırlarına göre nem yüzdesini otomatik kalibre eder.
2. **İki Yönlü Pompa Kontrolü (`/pumpCommands/{sensorId}`):**
   * Uygulama pompayı açmak istediğinde `requestedState: true` yazar.
   * ESP32 bu komutu okuduğunda röleyi/pompayı açmalı ve **hemen `actualState: true` yazarak** komutu onaylamalıdır (20 saniye içinde onay gelmezse uygulama güvenlik amacıyla `requestedState: false` ve `timedOut: true` yazar).
   * ESP32 üzerinde **bağımsız donanım zamanlayıcısı (Hardware Watchdog)** bulunmalı; internet kesilse bile `maxDurationSeconds` (varsayılan 15 sn) dolduğunda röleyi fiziksel olarak kapatıp `actualState: false` ve `requestedState: false` yazmalıdır.
3. **Uzaktan Kalibrasyon (`/sensorConfigs/{sensorId}`):**
   * Kullanıcı uygulama içindeki *Sensör Kalibrasyon Sihirbazı* veya *Ayarlar* üzerinden `dryAdcValue`, `wetAdcValue` ve `maxPumpSeconds` değerlerini değiştirdiğinde bu düğüm güncellenir.

---

## 🛠️ Kurulum ve Çalıştırma

1. **Bağımlılıkları yükleyin:**
   ```bash
   flutter pub get
   ```
2. **Firebase Yapılandırması:**
   * `android/app/google-services.json` dosyasının mevcut olduğundan ve `package_name` alanının `com.example.soilsense` ile eşleştiğinden emin olun.
   * Firebase Realtime Database kurallarını proje kök dizinindeki `database.rules.json` dosyasıyla güncelleyin.
3. **Birim Testlerini Çalıştırın:**
   ```bash
   flutter test
   ```
4. **Uygulamayı Başlatın:**
   ```bash
   flutter run
   ```

---

## 🤝 Ekip İçi Git Çalışma Kuralları (Branching)

Çakışmaları (Merge Conflict) önlemek için doğrudan `main` dalına (branch) `push` yapılmaz:

1. Yeni bir özellik veya düzeltme öncesi güncel `main` dalından yeni bir dal açın:
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/ozellik-adi
   ```
2. Değişikliklerinizi yaptıktan sonra `flutter test` komutunun hatasız geçtiğini doğrulayın.
3. Dalınızı GitHub'a gönderip **Pull Request (PR)** açın:
   ```bash
   git add .
   git commit -m "feat: kısa ve net açıklama"
   git push origin feature/ozellik-adi
   ```