# AGENTS.md - SoilSense çalışma rehberi ve yapılacaklar

Güncelleme: 24 Kasım 2026 | Plan v1.1

## Amaç ve kapsam

Android'de giriş, bitki ekleme, sensör eşleştirme, gerçek ölçüm izleme ve uygulamadan sulama akışını güvenilir bir ilk sürüme dönüştürmek.

İlk kapsam: Flutter + Firebase, Android, yerel simülasyon ve uygulamadan manuel sulama. Telefon kapalıyken otomatik sulama, gerçek arka plan bildirimleri ve diğer platformlar sonraki aşamadır. Mevcut otomatik sulama yolu kullanılacaksa ilgili P0 kontrolleri tamamlanır.

## Planın dayanağı ve mevcut durum

- İncelenen uzak sürüm: `a935a66c8c0dd3b69b5c706baab0a5cf09fcb183` (`master`).
- `master` ortak tabandır. `fix/android-setup` Android derleme düzeltmesini, onun üzerine kurulan `feature/p0-irrigation-safety` P0 kodunu ve testlerini taşır. `osman` bu iki değişikliğin birlikte denendiği daldır. Android debug APK bu birleşik kodla derlendi.
- Simülasyonun pompa, ölçüm, geçmiş, görev/arşiv ve ayar yolları ayrıldı. T01 ve R04 yerel otomatik testlerle doğrulandı.
- 24 Kasım kontrolü: 25 Flutter testi, 46 yerel Firebase kural testi ve Android derlemesi geçti. Analizde hata/uyarı yok; 114 bilgi düzeyinde bildirim var. Canlı Firebase yapılandırması ve ESP32 firmware'i doğrulanmadı.
- Cihaz sözleşmesi v2'ye geçti: kullanıcı komutu `pumpCommands`, cihaz onayı `pumpStatus` yolunda. [Sözleşme ve geçiş adımları](docs/P0_DEVICE_CONTRACT.md) bu dalın esas referansıdır. Eski firmware ile yeni kurallar birlikte kullanılamaz; canlıya yayımlanmadı.
- Önceki incelemedeki test çağrısı yorumu düzeltildi: `test/widget_test.dart` içindeki `history: frozenHistory` kullanımı zaten doğru; bu satır için düzeltme görevi yok.

## Bu dosyayı kullanan geliştirici/ajan için çalışma kuralları

- Bu dosya iş sırası ve proje bağlamıdır. Kullanıcı P0 işlerini başlattı; bu kapsamın dışındaki P1/P2 işleri için mevcut görev kapsamını gözet.
- Kullanıcının mevcut değişikliklerini koru. Önce çalışma dalını ve farkları kontrol et; Android düzeltmelerini kaybetmeden ilerle.
- Küçük, gözden geçirilebilir değişiklikler yap. İlgili hatayı giderirken kapsam dışı paket yükseltmesini veya geniş yeniden yazımı aynı işe katma.
- P0, gerçek pompa kullanımından önce ele alınacak işlerdir. P1 ilk teslim, P2 sonraki geliştirme aşamasıdır. Risk maddeleri doğrulanacak senaryolardır.
- Her işin tamamlanma ölçütünü doğrula. Yalnızca kod yazıldığı için kutuyu işaretleme; yapılan kontrolü ve kalan sınırlamayı kısa bir ilerleme notuna ekle.
- Canlı Firebase ve ESP32 davranışını görmeden doğrulanmış sayma. Emülatör, kod incelemesi ve gerçek cihaz sonuçlarını ayrı belirt.
- Hangi komutun gönderildiği, cihazın neyi onayladığı ve pompanın gerçek durumu ayrı izlenmelidir. Simülasyon durumu gerçek cihaz ve bakım kayıtlarına taşınmamalıdır.
- AGENTS.md canlı takip listesidir; PDF bu tarihteki paylaşılabilir kopyadır. PDF kutuları işaretlenince bu dosya otomatik güncellenmez. Plan değişirse iki belgeyi tutarlı güncelle.

## Uygulama sırası

İşaretli kutular yerel kod ve otomatik test doğrulamasını gösterir. Gerçek cihaz ve canlı ortam gerektiren maddeler açık bırakıldı; ayrıntılar ilerleme kaydındadır.

- [ ] **M01 - Çalışan başlangıç sürümünü oluştur**
  - İş: Yerel Android düzeltmelerini koru, güncel master ile birleştir ve emülatörde giriş ile bitki eklemeyi doğrula.
  - Tamamlanma ölçütü: Ekip aynı sürümü yeniden kurup çalıştırabilir.
  - İlgili maddeler: T12.

- [ ] **M02 - Firebase ve ESP32 sözleşmesini netleştir**
  - İş: Test ortamını, cihaz kimliğini, yayındaki kuralları ve komut/ölçüm alanlarını belirle; firmware'i incele.
  - Tamamlanma ölçütü: Uygulama ve cihazın kullanacağı veri sözleşmesi yazılıdır.
  - İlgili maddeler: R08, B01-B03.

- [x] **M03 - Simülasyonu uçtan uca ayır**
  - İş: Ölçüm, sulama, görev, arşiv ve ayarların simülasyon akışını gerçek veriden ayır.
  - Tamamlanma ölçütü: Simülasyonun gerçek cihaz ve bakım kayıtlarını değiştirmediği testle gösterilir.
  - İlgili maddeler: T01, R04.

- [x] **M04 - Eşleştirme ve kuralları tamamla**
  - İş: Cihaz sahipliğini, kullanıcı/cihaz yazma yetkilerini ve veri doğrulamasını birlikte uygula.
  - Tamamlanma ölçütü: Doğru işlemler kabul edilir; yanlış kullanıcı ve bozuk veri reddedilir.
  - İlgili maddeler: T02-T03.

- [ ] **M05 - Sulama komut akışını düzelt**
  - İş: Pompa durumlarını, cihaz onayını, süre sınırını, komut kimliğini ve tekrar engellemesini tamamla.
  - Tamamlanma ölçütü: Komutun gönderilmesi, çalışması, tamamlanması ve hatası ayrı görülebilir.
  - İlgili maddeler: T07, R01-R03, R05.

- [ ] **M06 - Ölçüm ve otomatik kararları sağlamlaştır**
  - İş: Zaman damgası, eksik veri, kalibrasyon, günlük limit ve sulamalar arası beklemeyi düzelt.
  - Tamamlanma ölçütü: Bozuk veri veya oturum değişimi yanlış sulama başlatmaz.
  - İlgili maddeler: T04-T06, T09, R02.

- [ ] **M07 - Günlük kullanım akışlarını toparla**
  - İş: Hataları görünür yap; hesap/sensör değişimi, bitki silme, grafik ve etki raporlarını tamamla.
  - Tamamlanma ölçütü: Kullanıcı durumun ne olduğunu ve nasıl ilerleyeceğini anlayabilir.
  - İlgili maddeler: T08, T10, R05-R07, R09.

- [ ] **M08 - Cihazla doğrula ve teslim kontrollerini kur**
  - İş: Her düzeltmeyle ilgili testi çalıştır; gerçek cihaz senaryolarını dene ve analiz, test, Android derlemesini otomatikleştir.
  - Tamamlanma ölçütü: K01-K09 kabul kontrolleri kanıtlarıyla tamamlanır.
  - İlgili maddeler: T11, K01-K09.

- [ ] **M09 - İlk teslimden sonra ek özelliklere geç**
  - İş: Arka plan bildirimi, telefon kapalıyken otomatik sulama, ekran iyileştirmeleri ve diğer platformları ayrı işler olarak ele al.
  - Tamamlanma ölçütü: Yeni kapsam ve öncelikler ayrı belirlenir.
  - İlgili maddeler: T13-T14.

## Kodda görülen sorunlar ve düzeltme listesi

"Sorun" satırları ilk incelemenin bulgularını korur; güncel durumu kutular ve ilerleme kaydı gösterir.

- [x] **T01 | P0 - Simülasyonun gerçek kayıtlara etkisini kaldır**
  - Sorun: Sanal ölçümler görev/arşiv kayıtlarını; sulama düğmesi bitki pompa durumunu; sensör bağlama akışı sahiplik ve ayarları değiştirebiliyor.
  - İş: Simülasyon ölçümlerini, görevlerini, pompa durumunu ve ayarlarını yerelde ayır.
  - Tamamlanma ölçütü: Simülasyon işlemleri gerçek cihaz ve bakım yollarına yazmaz.
  - İlgili alanlar: `lib/providers/sensor_provider.dart`, `lib/providers/todo_provider.dart`, `lib/providers/plant_provider.dart`, `lib/main.dart`, `lib/screens/home_screen.dart`, `lib/screens/my_plants_screen.dart`, `lib/screens/plant_detail_screen.dart`.

- [x] **T02 | P0 - Cihaz eşleştirmesini doğrula**
  - Sorun: Yerel emülatör kontrolünde giriş yapmış kullanıcı sahipsiz cihazı kod doğrulaması olmadan sahiplenebildi.
  - İş: Gerçek cihaz sahipliğini doğrulayan tek kullanımlık eşleştirme ve atomik sahiplenme akışı kur.
  - Tamamlanma ölçütü: Geçersiz/tekrar kullanılan kod ve eşzamanlı ikinci sahiplenme reddedilir.
  - İlgili alanlar: `database.rules.json`, `lib/providers/sensor_provider.dart`.

- [x] **T03 | P0 - Firebase yazma yetkilerini ve alanları sınırla**
  - Sorun: Kullanıcı ve cihaz yazma alanları ayrılmamış; pompa süresi ve veri biçimleri yeterince doğrulanmıyor.
  - İş: Kullanıcının komutunu, cihazın ölçüm/onayını ayır; tür, aralık ve süre kontrolleri ekle.
  - Tamamlanma ölçütü: Yetkisiz durum değişikliği ve geçersiz süre/veri kurallar tarafından reddedilir.
  - İlgili alanlar: `database.rules.json`, `lib/models/sensor_data.dart`, `lib/providers/sensor_provider.dart`.

- [x] **T04 | P0 - Ölçüm zamanını doğru yorumla**
  - Sorun: ESP32 çalışma süresi gibi geçersiz bir değer mevcut saate çevrilip güncel ölçüm sayılabiliyor.
  - İş: Unix saniye/milisaniye sözleşmesini belirle; eksik, geçersiz, eski ve gelecek zamanı ele al.
  - Tamamlanma ölçütü: Çalışma süresi veya bozuk zaman, sensörü güncel göstermez.
  - İlgili alanlar: `lib/models/sensor_data.dart`, `test/widget_test.dart`.

- [x] **T05 | P0 - Eksik ölçümle sulamayı engelle**
  - Sorun: Eksik nem yüzde sıfır olarak yorumlanabiliyor; otomatik sulama eksik alan işaretini kontrol etmiyor.
  - İş: Veri yok durumunu kuru topraktan ayır; geçersiz ölçümü sulama kararından çıkar.
  - Tamamlanma ölçütü: Eksik veya bozuk nem/ADC paketi otomatik komut üretmez.
  - İlgili alanlar: `lib/models/sensor_data.dart`, `lib/providers/sensor_provider.dart`.

- [x] **T06 | P0 - Sulama limitlerini kalıcı ve tutarlı yap**
  - Sorun: Oturum değişimi sayaçları temizliyor; tekrar yükleme eksik. Son sulama zamanı kalıcı tutulmuyor.
  - İş: Sayaç ve son sulamayı kullanıcı/cihaz bazında sakla; açılış, oturum ve gün değişimini yönet.
  - Tamamlanma ölçütü: Yeniden açma ve çıkış-giriş, günlük limiti veya bekleme süresini sıfırlamaz.
  - İlgili alanlar: `lib/providers/sensor_provider.dart`.

- [x] **T07 | P0 - Pompa durumunu cihaz onayına bağla**
  - Sorun: Ekrandaki durum cihaz onayından önce değişiyor; bazı ekranlar başarısız komutta da başarı bildiriyor.
  - İş: Gönderiliyor, onaylandı, çalışıyor, tamamlandı ve hata durumlarını tek kaynaktan yönet.
  - Tamamlanma ölçütü: Komut başarısızsa veya onay gelmemişse ekranda sulandı yazmaz.
  - İlgili alanlar: `lib/providers/sensor_provider.dart`, `lib/providers/plant_provider.dart`, `lib/screens/home_screen.dart`, `lib/screens/my_plants_screen.dart`, `lib/screens/plant_detail_screen.dart`.

- [ ] **T08 | P1 - Bağlantı ve kayıt hatalarını görünür yap**
  - Sorun: Sensör erişim hataları ekrana taşınmıyor; bazı yazma ve dinleme hataları sessizce geçiliyor.
  - İş: Anlaşılır hata, başarısız kayıt durumu ve yeniden deneme akışı ekle.
  - Tamamlanma ölçütü: Başarısız işlem başarılı gösterilmez; kullanıcı sonraki adımı görür.
  - İlgili alanlar: `lib/providers/sensor_provider.dart`, `lib/screens/settings_screen.dart`, `lib/widgets/device_health_sheet.dart`.

- [ ] **T09 | P1 - ADC kalibrasyonunu doğrula**
  - Sorun: Islak/kuru değerleri ters sıradayken hesap yanlış sonuç verebiliyor; aralık denetimi eksik.
  - İş: Ölçüm yönünü doğru işle; eşit, aralık dışı ve yetersiz fark olan değerleri doğrula.
  - Tamamlanma ölçütü: Desteklenen her ölçüm yönü doğru yüzde üretir; geçersiz ayar kaydedilmez.
  - İlgili alanlar: `lib/models/sensor_data.dart`, `lib/screens/plant_detail_screen.dart`.

- [ ] **T10 | P1 - Grafik geçmişini zaman aralığına göre getir**
  - Sorun: Son 100 nokta yedi günlük geçmişi garanti etmiyor; geçmişin tamamı indiriliyor.
  - İş: Tarih aralığına göre sorgula; örnekleme, saklama ve eksik zaman gösterimini belirle.
  - Tamamlanma ölçütü: 24 saat/7 gün görünümü doğru aralığı gösterir ve sorgular sınırlıdır.
  - İlgili alanlar: `lib/providers/sensor_provider.dart`, `lib/widgets/moisture_chart.dart`.

- [ ] **T11 | P1 - Kritik akışların test kapsamını tamamla**
  - Sorun: Mevcut testler ağırlıklı olarak modelleri ve hesaplamaları kontrol ediyor.
  - İş: Kurallar, simülasyon, pompa onayı, oturum ve limitler için test ekle; kontrolleri otomatikleştir.
  - Tamamlanma ölçütü: Analiz, ilgili testler, kurallar emülatörü ve Android derlemesi doğrulanır.
  - İlgili alanlar: `test/widget_test.dart`, `test/`, `database.rules.json`, `.github/workflows/ (önerilen)`.

- [ ] **T12 | P1 - Android düzeltmelerini güncel kodla birleştir**
  - Sorun: Yerel çalışan Android düzeltmeleri kaydedilmemiş; yeni master ile henüz birleşmemiş.
  - İş: Mevcut çalışmayı koru; anlamlı değişiklikleri ayır, birleştir ve tekrar derle.
  - Tamamlanma ölçütü: Yeni master ile emülatörde giriş ve bitki ekleme çalışır.
  - İlgili alanlar: `android/app/build.gradle.kts`, `android/build.gradle.kts`, `android/settings.gradle.kts`, `android/gradle/wrapper/gradle-wrapper.properties`, `pubspec.lock`.

- [ ] **T13 | P2 - Gerçek bildirim kapsamını tamamla**
  - Sorun: Uygulama içindeki bildirim testi, arka planda telefon bildirimi geldiğini doğrulamıyor.
  - İş: İhtiyaç netleşince bildirim altyapısını kur; açık, arka planda ve kapalı uygulamayı ayrı dene.
  - Tamamlanma ölçütü: Seçilen senaryolarda gerçek bildirim gelir; desteklenmeyen durum açıkça belirtilir.
  - İlgili alanlar: `lib/providers/sensor_provider.dart`, `lib/screens/settings_screen.dart`, `pubspec.yaml`.

- [ ] **T14 | P2 - Mimariyi ve geliştirme ortamını sadeleştir**
  - Sorun: Sensör sınıfında çok fazla sorumluluk var; eski bağımlılıklar, Kotlin uyarıları ve izlenen derleme çıktıları bulunuyor.
  - İş: Firebase erişimi, simülasyon ve sulama kararını ayır; sürümleri belgele, paketleri kontrollü güncelle ve çıktıları temizle.
  - Tamamlanma ölçütü: Kurulum tekrarlanabilir; gerekli kontroller geçer ve gereksiz çıktılar değişikliklere karışmaz.
  - İlgili alanlar: `lib/providers/sensor_provider.dart`, `pubspec.yaml`, `pubspec.lock`, `android/`, `.gitignore`, `README.md`.

## Potansiyel sorunlar ve doğrulanacak senaryolar

Bu maddeler gerçekleşmiş hata iddiası değildir; belirtilen senaryolarla doğrulanıp gerekirse giderilir.

- [ ] **R01 | P0 - Kesinti sonrası eski komutun çalışması**
  - İş / kontrol: Komuta kimlik ve son geçerlilik zamanı ekle; ESP32'nin eski veya uyguladığı komutu tekrar çalıştırmadığını test et.
  - Tamamlanma ölçütü: Bağlantı geri geldiğinde süresi geçmiş komut uygulanmaz.

- [x] **R02 | P0 - Çift tıklama, ardışık ölçüm ve iki telefon**
  - İş / kontrol: Cihaz başına bekleyen işlem ve tekrar kontrolü kur; günlük limiti tek telefon belleğine bağlı bırakma.
  - Tamamlanma ölçütü: Aynı olaydan birden fazla sulama başlamaz; ortak limit korunur.

- [ ] **R03 | P0 - Uygulama kapalıyken pompanın açık kalması**
  - İş / kontrol: ESP32'nin bağımsız süre sınırını ve açılış durumunu doğrula; internet ve uygulama kapalıyken dene.
  - Tamamlanma ölçütü: Süre dolduğunda pompa uygulamadan bağımsız kapanır.

- [x] **R04 | P0 - Modlar arasında durum taşınması**
  - İş / kontrol: Simülasyon/donanım durumlarını ayır; geçişte bekleyen işlem, ayar, ölçüm ve zamanlayıcıları test et.
  - Tamamlanma ölçütü: Sanal durum gerçek komutu veya gerçek durum sanal sonucu bozmaz.

- [ ] **R05 | P1 - Sulama etki raporunun erken hesaplanması**
  - İş / kontrol: Raporu tamamlanan komutla ilişkilendir; cihaz onayı ve uygun ölçüm bekleme süresini uygula.
  - Tamamlanma ölçütü: Sulama başlamadan veya bitmeden etki raporu üretilmez.

- [ ] **R06 | P1 - Hesap, bitki veya sensör değişiminde eski işlem**
  - İş / kontrol: Abonelik ve zamanlayıcıları temizle; geç gelen sonucu doğru oturumla eşleştir; bağlantı kaldırma/yeniden eşleştirmeyi tanımla.
  - Tamamlanma ölçütü: Eski hesaba veya kaldırılan cihaza ait işlem yeni duruma taşınmaz.

- [ ] **R07 | P1 - Geçmiş ve tekrar eden uyarıların büyümesi**
  - İş / kontrol: Aynı uyarıyı tekilleştir; kayıt saklama süresini ve sınırlı sorguları belirle.
  - Tamamlanma ölçütü: Her telemetride aynı uyarı çoğalmaz; geçmiş sınırsız indirilmez.

- [ ] **R08 | P0 - Canlı kurallar ile firmware uyumsuzluğu**
  - İş / kontrol: Yayındaki kuralları repoyla karşılaştır; cihaz kimliğini, veri yollarını ve mesaj biçimini incele.
  - Tamamlanma ölçütü: Uygulama ve ESP32 aynı sözleşmeyle gerekli işlemleri yapabilir.

- [ ] **R09 | P1 - Firebase başlatma hatasından sonra devam**
  - İş / kontrol: Başlatma başarısızlığını yönet; anlaşılır açılış hatası ve yeniden deneme ekle.
  - Tamamlanma ölçütü: Yapılandırma/bağlantı sorunu belirsiz alt ekran hatalarına dönüşmez.

## İlk teslim kabul kontrolleri

- [ ] **K01 - Android kurulumu ve temel akış:** Belgelenen sürümlerle kurulum, giriş, bitki ekleme ve eşleştirme tamamlanır.
- [ ] **K02 - Gerçek ölçüm ve sulama zinciri:** Ölçüm görülür; komut gönderilir, cihaz onaylar, pompa çalışır ve süre sonunda kapanır; geçmiş doğru kaydedilir.
- [x] **K03 - Simülasyon ayrımı:** Sanal ölçüm, görev, arşiv, sulama ve ayar işlemleri gerçek cihaz/bakım kayıtlarını değiştirmez.
- [x] **K04 - Yetki ve eşleştirme kuralları:** Yanlış kullanıcı, geçersiz kod, tekrar sahiplenme ve bozuk alanlar reddedilir; doğru cihaz işlemleri kabul edilir.
- [x] **K05 - Ölçüm doğruluğu:** Eksik, eski, gelecekteki ve çalışma süresi biçimindeki zaman; eksik nem ve ters kalibrasyon senaryoları doğrulanır.
- [x] **K06 - Limit ve eşzamanlılık:** Yeniden açma, çıkış-giriş, gün değişimi, çift tıklama ve iki telefon limit veya bekleme süresini bozamaz.
- [ ] **K07 - Bağlantı ve cihaz dayanıklılığı:** İnternet kesintisi, geç onay, uygulama kapanması ve ESP32 yeniden başlamasında eski komut tekrarlanmaz; pompa süre sonunda kapanır.
- [ ] **K08 - Ekran, geçmiş ve oturum tutarlılığı:** Başarısız komut başarı görünmez; 24 saat/7 gün aralığı ve etki raporu doğrudur; hesap/sensör değişiminde eski veri taşınmaz.
- [ ] **K09 - Teslim kanıtları:** Analiz, ilgili otomatik testler, kurallar emülatörü ve Android derlemesi geçer; gerçek cihaz testi ve kalan sınırlamalar kayda alınır.

İlgili değişikliklere göre doğrulama: `flutter analyze`, `flutter test`, Firebase Realtime Database Emülatörü kurallar testleri ve `flutter build apk --debug`. Son çalıştırmalar aşağıda kayıtlıdır. Android emülatöründe giriş/bitki ekleme ile gerçek ESP32/pompa akışı bu son sürümde ayrıca denenmelidir.

## Dış bilgiler ve ekip bağımlılıkları

- [ ] **B01 - Firebase proje ve ortam bilgisi:** Proje kimliği, test/canlı ortam ayrımı ve yayındaki kuralların hangi sürüm olduğu belirlenir.
- [ ] **B02 - ESP32 firmware ve örnek veri:** Mehmet'ten firmware konumu, örnek telemetri, cihazın giriş yöntemi ve röle/pompa süre sınırı alınır.
- [ ] **B03 - Gerçek cihaz denemesi:** Kart, sensör, röle ve pompa ile test zamanı belirlenir; bağlantı kesintisi senaryosu da denenir.

Önerilen iş paylaşımı: Osman mobil uygulama, birleştirme ve test takibini; Mehmet firmware, cihaz örnekleri ve donanım denemesini üstlenebilir. Firebase sözleşmesi ve ilk gerçek cihaz kontrolü birlikte netleştirilir. Bu öneri atanmış görev veya gönderilmiş mesaj değildir.

## Firebase erişimi

- **Belge, kod ve yerel test:** Canlı Firebase erişimi gerekmiyor. Kod incelemesi ve kuralların demo emülatöründe testi yerelde yapılabilir.
- **Yayındaki yapılandırmayı inceleme:** İlgili Firebase projesine okuma yetkili bağlantı gerekiyor. Kurallar, cihaz veri yolları ve proje yapılandırması bu aşamada karşılaştırılır.
- **Kuralları yayımlama veya bulutta değişiklik:** İlgili işlem için yazma/yayımlama yetkisi gerekiyor. Gerekli yetki, üzerinde çalışılan işin kapsamına göre seçilir.

Mehmet'in Osman'ı projeye eklemesi, Codex'e otomatik bağlantı sağlamaz. Bu oturumda bağlı bir Firebase aracı bulunmuyor. Canlı kontrol gerektiğinde kullanıcının yetkili oturumu veya desteklenen bağlantı kullanılır. Sırf belge hazırlamak için bağlantı kurmaya gerek yok.

## İlerleme kaydı

### 24 Kasım 2026 - P0 uygulama ve yerel kurallar

- **M03, T01, R04, K03:** Simülasyon için ayrı ölçüm, pompa, kalibrasyon, güvenlik ayarı, geçmiş ve görev/arşiv durumu kullanılıyor. Simülasyon işlemlerinde buluta sıfır yazma; mod geçişinde gerçek duruma taşınmama testleri geçti. Kullanıcının normal bitki ekleme/düzenleme işlemleri hesap verisi olarak kaydedilmeye devam eder.
- **M04, T02, T03, K04:** Eşleştirme kodu, süre ve UID doğrulanıyor; sahiplenme tek seferlik. Kullanıcı komutları ve cihazın ölçüm/onay yetkileri ayrıldı. Yanlış kullanıcı, yanlış/tekrar kod, eşzamanlı sahiplenme, bozuk veri/süre ve sahte onay yerel kurallarla reddedildi.
- **T04, T05, K05:** Çalışma süresi, bozuk/gelecek/eski zaman ve eksik/bozuk ölçüm güncel veri sayılmıyor. Geçersiz ölçümle sulama engelleniyor. ADC dönüşümü iki yönü de destekliyor; eşit/geçersiz uçlar reddediliyor.
- **T06, R02, K06:** Otomatik limit ve son sulama aynı komut kaydında atomik korunuyor. UTC günü başına 3 kabul edilmiş otomatik istek, 30 dakika bekleme, yeniden oluşturulan uygulama durumu, gün geçişi ve eşzamanlı iki istemci kontrolü geçti. Manuel/durdurma işlemi sayacı sıfırlamıyor.
- **T07:** Komut gönderme ile cihazın çalışıyor/tamamlandı onayı ayrıldı. Yanlış kimlikli/geçmeyen onay başarı sayılmıyor; zaman aşımında durum bilinmiyor gösteriliyor. Çift tıklama, yazma hatası, oturum/bitki değişimi ve gecikmiş işlem testleri geçti. Durdurma süresi 1 olarak taşınır ve eski telefon süre ayarından etkilenmez. UI çağrıları sonuç kontrol ediyor; gerçek ekran-cihaz zinciri K02 kapsamında açık.
- **R01 kısmi:** Komut kimliği, 20 saniyelik geçerlilik ve kuyruğa düşen isteğin zamanını yenilememe eklendi. Tamamlanmış cihaz onayı idle/running ile geri alınamıyor. ESP32'nin kendi tekrar engeli ve kesinti sonrası davranışı henüz doğrulanmadı.
- **M01/T12 kısmi:** Güncel master alındı, mevcut Android değişiklikleri korundu ve yeni APK derlendi. Bu sürümde emülatör giriş/bitki ekleme kontrolü bekliyor.
- **T08/T09/T11/R05/R06 kısmi:** Erişim/komut hatası gösterimi, ADC doğrulaması, tamamlanma sonrası rapor bekleme ve eski oturuma ait işlem koruması ilerletildi. Bu maddelerin tüm kabul ölçütleri ve CI henüz tamamlanmadı.

**Kontroller ve kanıt:**

- `flutter test --no-pub`: **25/25 geçti** (18 P0 testi ve önceki 7 test).
- `node tool/test_database_rules.mjs`: **46/46 geçti**; yalnızca yerel Database Emulator, `demo-soilsense-p0` ad alanı.
- `flutter analyze --no-pub --no-fatal-infos`: **çıkış 0**, hata ve uyarı yok; 114 bilgi düzeyinde bakım bildirimi bulunuyor.
- `flutter build apk --debug --target-platform android-x64 --no-pub`: **başarılı**, `build/app/outputs/flutter-apk/app-debug.apk` oluştu. Kotlin eklentilerinin gelecekteki uyumluluğu ile ilgili uyarı sürüyor; T14 kapsamında.
- `git diff --check`: geçti. Testleri tekrarlama talimatı [cihaz sözleşmesinde](docs/P0_DEVICE_CONTRACT.md).
- **Bu doğrulamanın kapsamı dışında:** Canlı Firebase, ESP32 firmware'i, fiziksel pompa ve Android emülatöründe giriş ve bitki eklemenin elle denenmesi.

**Açık P0 ve sonraki adım:** R01, R03 ve R08 gerçek cihaz/firmware doğrulaması nedeniyle açık. Erişilebilir repo geçmişi, Mehmet'in erişilebilir depoları ve olası yerel Arduino/PlatformIO/indirilenler konumlarında firmware bulunamadı. Kaynak kod, örnek cihaz verisi ve cihaz giriş yöntemi edinilince v2 sözleşmesiyle uyarlanacak; ayrı test ortamında kesinti, yeniden başlatma ve bağımsız pompa kapanması denenecek. B01-B03 halen açık. P0 bütünü tamamlandı sayılmıyor.

## Kaynaklar

- [İncelenen kaynak sürüm](https://github.com/mehmetctl28/souilsense/commit/a935a66c8c0dd3b69b5c706baab0a5cf09fcb183)
- [Firebase proje erişimi ve roller](https://firebase.google.com/docs/projects/iam/overview)
- [Realtime Database yerel emülatörü](https://firebase.google.com/docs/emulator-suite/connect_rtdb)

## PDF kopyası

Paylaşılabilir kontrol listesi: `output/pdf/SoilSense_Yapilacaklar_Listesi.pdf`.
