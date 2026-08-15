# Firestore Veri Yapısı

> Bu belge, kod tabanındaki repository sınıfları (`lib/repositories/`) ile
> senkron tutulmalıdır. Bir koleksiyon veya alan değiştiğinde bu dosya da
> aynı pull request içinde güncellenmelidir.

Uygulama, iç içe alt-koleksiyonlar yerine **düz (top-level) koleksiyonlar**
kullanır; ilişki `userId` / `vehicleId` alanlarıyla kurulur.

```
users/{userId}
  → kullanıcı profili (lib/services/user_service.dart)

vehicles/{vehicleId}
  userId, category, brand, model, engine, year, fuelType, hybridType,
  plate, normalizedPlate, startKm, currentKm, purchasePrice, purchaseDate,
  tankCapacity, lpgTankCapacity, batteryCapacity,
  mtvNextPaymentDate, trafficInsuranceEndDate, cascoEndDate, inspectionEndDate,
  localImagePath, localStickerPath, originalImageDriveId, stickerImageDriveId,
  backgroundRemoved, status (ACTIVE | DELETED), hasFinancing,
  isCustomBrand, isCustomModel, createdAt, updatedAt

expenses/{expenseId}
  userId, vehicleId,
  type (enum: FUEL | CHARGE | MAINTENANCE | TAX | INSURANCE | INSPECTION |
        TOLL | PARKING | FINE | TIRE | OTHER),
  subType, isFullTank, amount, quantity, unitPrice, km, expenseDate,
  maintenanceItems[], replacedItems[], nextMaintenanceDate, nextMaintenanceKilometer,
  nextDueDate, stationName, receiptNumber, documentName, documentMimeType,
  maintenanceType, serviceName, laborCost,
  localDocumentPath, driveDocumentId, importKey, importSource,
  createdAt, updatedAt

reminders/{reminderId}
  userId, vehicleId, sourceExpenseId, title, dueDate, dueKilometer,
  completed, createdAt, updatedAt

vehicle_plate_keys/{userId}_{normalizedPlate}
  userId, vehicleId, normalizedPlate, createdAt
  → plaka benzersizliğini garanti eden yardımcı koleksiyon; addVehicle ve
    updateVehicle transaction içinde bu dokümanı okuyup yazar.
```

## Önemli notlar

- **"Sigorta", "kasko", "MTV", "bakım" ayrı koleksiyon değildir.** Bunlar
  `expenses` koleksiyonundaki tek bir dokümanın `type`/`maintenanceType`
  alanlarındaki değerlerdir (bkz. `lib/models/expense.dart` → `ExpenseType`).
- **Belge/fiş görselleri** Firebase Storage'da değil, cihazda
  (`localDocumentPath`) veya kullanıcının kendi Google Drive
  `appDataFolder` alanında (`driveDocumentId`) tutulur
  (bkz. `lib/services/google_drive_service.dart`).
- **`vehicles.currentKm`**, her gider ekleme/güncelleme/silme işleminden sonra
  `ExpenseRepository._recalculateVehicleCurrentKm` tarafından otomatik olarak
  yeniden hesaplanır.
- **Güvenlik kuralları:** `firestore.rules` bu repoda tutulur (bkz. kök dizin).
  Her koleksiyon için temel kural: yalnızca `request.auth.uid == resource.data.userId`
  olan kullanıcı kendi dokümanlarını okuyup yazabilir.

## Planlanan Özellikler

- Google Drive otomatik geri yükleme
- Yakıt istasyonu tespiti
- Yakıt fiyat karşılaştırmaları
- Marka bazlı tüketim analizleri
- Araç bazlı raporlama
