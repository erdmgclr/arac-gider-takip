# Firestore Veri Yapısı

users
└── {userId}
    ├── profile
    └── vehicles
        └── {vehicleId}
            ├── vehicleInfo
            ├── fuel_records
            │   └── {fuelRecordId}
            ├── expenses
            │   └── {expenseId}
            ├── maintenance
            │   └── {maintenanceId}
            ├── reminders
            │   └── {reminderId}
            ├── documents
            │   └── {documentId}
            ├── insurance
            │   └── {insuranceId}
            ├── casco
            │   └── {cascoId}
            └── mtv
                └── {mtvId}

## Planlanan Özellikler

- Google Drive otomatik geri yükleme
- OCR fiş okuma
- Yakıt istasyonu tespiti
- Yakıt fiyat karşılaştırmaları
- Marka bazlı tüketim analizleri
- Araç bazlı raporlama
- Çoklu bakım kalemi yönetimi
- Yaklaşan bakım bildirimleri
