# Claude Proje Talimatları

Bu proje Flutter ile geliştirilen bir araç gider ve bakım yönetim uygulamasıdır.

## Temel Kurallar

- Türkçe arayüz kullanılmalıdır.
- Null Safety zorunludur.
- Mevcut tasarım dili korunmalıdır.
- Kullanıcı deneyimini bozacak değişikliklerden kaçınılmalıdır.
- Firestore veri yapısı değiştirilirken geriye uyumluluk korunmalıdır.
- Gereksiz paket eklenmemelidir.
- Performans ve Firestore maliyeti dikkate alınmalıdır.

## Kullanılan Teknolojiler

- Flutter
- Provider
- Firebase Authentication
- Cloud Firestore
- Google Drive API
- OCR

## Kodlama Standartları

- Açıklayıcı değişken isimleri kullanılmalıdır.
- Büyük refaktörlerde mevcut işleyiş korunmalıdır.
- Widget yapıları mümkün olduğunca temiz tutulmalıdır.
- Tekrarlayan kodlar ortak bileşenlere dönüştürülmelidir.

## Veri Güvenliği

- Hassas bilgiler repository'e eklenmemelidir.
- Firebase yapılandırma dosyaları Git üzerinde tutulmamalıdır.
- Kullanıcı verileri yalnızca yetkili kullanıcı tarafından erişilebilir olmalıdır.

## Yeni Özellik Geliştirme Kuralları

- Önce mevcut mimari analiz edilmelidir.
- Mevcut veri modeli korunmalıdır.
- Veri migrasyonu gerekiyorsa açıkça belirtilmelidir.
- Firestore okuma ve yazma maliyetleri değerlendirilmelidir.

## Analiz İsteklerinde

Kod değişikliği önermeden önce:

1. Mevcut mimariyi analiz et.
2. Sorunu tespit et.
3. Olası etkileri değerlendir.
4. En düşük riskli çözümü öner.
5. Gerekirse tam dosya içeriklerini üret.
