# Güvenlik Notları

## Git geçmişinde açığa çıkmış Firebase yapılandırması

İlk commit (`027a665`), `android/app/google-services.json` ve
`lib/firebase_options.dart` dosyalarını içeriyordu. Bu dosyalar
`bb6e9fc` ve `e4f3ac1` commit'lerinde repodan kaldırıldı, ancak **git
geçmişi yeniden yazılmadığı için eski commit hâlâ herkese açık şekilde
erişilebilir** (`git show 027a665:lib/firebase_options.dart`).

Açığa çıkan bilgiler:
- Firebase Android API anahtarı
- Proje numarası ve OAuth client ID'leri
- Uygulama imza sertifikası hash'i (`certificate_hash`)
- Paket adı

**Bu, Claude tarafından yapılamayan, sizin (repo sahibi olarak) Google
Cloud / Firebase Console üzerinden yapmanız gereken bir aksiyon
gerektirir:**

1. [Google Cloud Console → API'ler ve Hizmetler → Kimlik Bilgileri](https://console.cloud.google.com/apis/credentials)
   üzerinden ilgili Android API anahtarını bulun.
2. Anahtara **paket adı + SHA-1 sertifika parmak izi** kısıtlaması ekleyin
   (henüz yoksa) — bu, anahtar sızmış olsa bile başka bir uygulamanın
   onu kullanmasını engeller.
3. İsterseniz anahtarı tamamen yenileyin (regenerate) ve
   `flutterfire configure` ile `google-services.json` /
   `firebase_options.dart` dosyalarını yeniden oluşturun.
4. Firestore güvenlik kurallarınızın (`firestore.rules`, bu repoda
   mevcut) production'da deploy edildiğinden emin olun — asıl erişim
   kontrolü API anahtarında değil, bu kurallardadır.
5. (Opsiyonel, ileri seviye) Geçmişten kalıcı olarak temizlemek
   isterseniz `git filter-repo` veya BFG Repo-Cleaner kullanabilirsiniz.
   Bu, repoyu daha önce klonlamış/fork'lamış kişilerdeki kopyaları
   etkilemez, ama yeni klonlarda dosyayı görünmez kılar.

Bu notlar bilgilendirme amaçlıdır; anahtar rotasyonu/kısıtlaması hesap
erişimi gerektirdiğinden repo içinden otomatik olarak yapılamaz.
