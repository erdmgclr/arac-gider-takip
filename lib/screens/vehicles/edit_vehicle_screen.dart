import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/vehicle.dart';
import '../../repositories/vehicle_repository.dart';
import '../../services/vehicle_image_service.dart';
import '../../services/vehicle_background_service.dart';
import '../../widgets/app_date_time_picker.dart';

class EditVehicleScreen extends StatefulWidget {
  const EditVehicleScreen({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  State<EditVehicleScreen> createState() => _EditVehicleScreenState();
}

class _EditVehicleScreenState extends State<EditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = VehicleRepository();
  final _imageService = VehicleImageService();
  late final TextEditingController _brand = TextEditingController(
    text: widget.vehicle.brand,
  );
  late final TextEditingController _model = TextEditingController(
    text: widget.vehicle.model,
  );
  late final TextEditingController _engine = TextEditingController(
    text: widget.vehicle.engine ?? '',
  );
  late final TextEditingController _year = TextEditingController(
    text: widget.vehicle.year?.toString() ?? '',
  );
  late final TextEditingController _plate = TextEditingController(
    text: widget.vehicle.plate ?? '',
  );
  late final TextEditingController _km = TextEditingController(
    text: widget.vehicle.currentKm?.toString() ?? '',
  );
  late final TextEditingController _purchasePrice = TextEditingController(
    text:
        widget.vehicle.purchasePrice?.toStringAsFixed(2).replaceAll('.', ',') ??
        '',
  );
  DateTime? _purchaseDate;
  DateTime? _insurance;
  DateTime? _casco;
  DateTime? _inspection;
  bool _saving = false;
  bool _processingImage = false;
  late String? _localImagePath = widget.vehicle.localImagePath;
  late String? _localStickerPath = widget.vehicle.localStickerPath;
  late String? _originalDriveId = widget.vehicle.originalImageDriveId;
  late String? _stickerDriveId = widget.vehicle.stickerImageDriveId;

  @override
  void initState() {
    super.initState();
    _insurance = widget.vehicle.trafficInsuranceEndDate;
    _casco = widget.vehicle.cascoEndDate;
    _inspection = widget.vehicle.inspectionEndDate;
    _purchaseDate = widget.vehicle.purchaseDate;
  }

  @override
  void dispose() {
    _brand.dispose();
    _model.dispose();
    _engine.dispose();
    _year.dispose();
    _plate.dispose();
    _km.dispose();
    _purchasePrice.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(String title, DateTime? value) =>
      AppDateTimePicker.show(
        context,
        title: title,
        mode: AppPickerMode.date,
        initialValue: value ?? DateTime.now(),
        minimumDate: DateTime(1950),
        maximumDate: DateTime(2100),
      );

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Kameradan Çek'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden Seç'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final selected = await _imageService.pickAndSave(source);
    if (selected == null || !mounted) return;
    setState(() {
      _localImagePath = selected;
      _localStickerPath = null;
      _stickerDriveId = null;
    });
  }

  Future<void> _removeBackground() async {
    if (_localImagePath == null) return;
    setState(() => _processingImage = true);
    try {
      final value = await VehicleBackgroundService.instance.removeBackground(
        _localImagePath!,
      );
      if (mounted) setState(() => _localStickerPath = value);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Arka plan kaldırılamadı: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _processingImage = false);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      if (_localImagePath != null &&
          _localImagePath != widget.vehicle.localImagePath) {
        _originalDriveId = await _imageService.uploadToDrive(
          localPath: _localImagePath!,
          userId: widget.vehicle.userId,
        );
      }
      if (_localStickerPath != null &&
          _localStickerPath != widget.vehicle.localStickerPath) {
        _stickerDriveId = await _imageService.uploadToDrive(
          localPath: _localStickerPath!,
          userId: widget.vehicle.userId,
        );
      }
      final updated = Vehicle(
        id: widget.vehicle.id,
        userId: widget.vehicle.userId,
        category: widget.vehicle.category,
        brand: _brand.text.trim(),
        model: _model.text.trim(),
        engine: _engine.text.trim(),
        year: int.tryParse(_year.text),
        fuelType: widget.vehicle.fuelType,
        hybridType: widget.vehicle.hybridType,
        plate: _plate.text.trim(),
        normalizedPlate: VehicleRepository.normalizePlate(_plate.text),
        startKm: widget.vehicle.startKm,
        currentKm: int.tryParse(_km.text),
        purchasePrice: double.tryParse(
          _purchasePrice.text.trim().replaceAll('.', '').replaceAll(',', '.'),
        ),
        purchaseDate: _purchaseDate,
        tankCapacity: widget.vehicle.tankCapacity,
        lpgTankCapacity: widget.vehicle.lpgTankCapacity,
        batteryCapacity: widget.vehicle.batteryCapacity,
        trafficInsuranceEndDate: _insurance,
        cascoEndDate: _casco,
        inspectionEndDate: _inspection,
        localImagePath: _localImagePath,
        localStickerPath: _localStickerPath,
        originalImageDriveId: _originalDriveId,
        stickerImageDriveId: _stickerDriveId,
        backgroundRemoved: _localStickerPath != null,
        status: widget.vehicle.status,
        hasFinancing: widget.vehicle.hasFinancing,
        isCustomBrand: widget.vehicle.isCustomBrand,
        isCustomModel: widget.vehicle.isCustomModel,
        createdAt: widget.vehicle.createdAt,
      );
      await _repository.updateVehicle(widget.vehicle, updated);
      if (mounted) Navigator.pop(context, true);
    } on DuplicatePlateException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bu plaka başka bir araçta kayıtlı.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _dateField(
    String title,
    DateTime? value,
    ValueChanged<DateTime?> onChanged,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(
        value == null
            ? 'Girilmeyecek'
            : '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}',
      ),
      trailing: Wrap(
        children: [
          if (value != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => onChanged(null),
            ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: () async => onChanged(await _pick(title, value)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Aracı Düzenle')),
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Araç Fotoğrafı',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              height: 160,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child:
                  (_localStickerPath ?? _localImagePath) != null &&
                      File(_localStickerPath ?? _localImagePath!).existsSync()
                  ? Image.file(
                      File(_localStickerPath ?? _localImagePath!),
                      fit: BoxFit.contain,
                    )
                  : const Icon(Icons.directions_car_rounded, size: 64),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickPhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Fotoğrafı Değiştir'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _localImagePath == null || _processingImage
                        ? null
                        : _removeBackground,
                    icon: const Icon(Icons.auto_fix_high_rounded),
                    label: Text(
                      _processingImage ? 'İşleniyor...' : 'Arka Planı Kaldır',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _brand,
              decoration: const InputDecoration(labelText: 'Marka'),
              validator: (v) => v!.trim().isEmpty ? 'Zorunlu' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _model,
              decoration: const InputDecoration(labelText: 'Model'),
              validator: (v) => v!.trim().isEmpty ? 'Zorunlu' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _engine,
              decoration: const InputDecoration(labelText: 'Motor / Versiyon'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _year,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Model Yılı'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _plate,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Plaka'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _km,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Güncel Kilometre',
                suffixText: 'km',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _purchasePrice,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Alış Fiyatı',
                prefixText: '₺ ',
                helperText: 'İsteğe bağlı, sonradan değiştirilebilir',
              ),
            ),
            _dateField(
              'Alış Tarihi',
              _purchaseDate,
              (v) => setState(() => _purchaseDate = v),
            ),
            const SizedBox(height: 18),
            Text(
              'Takip Tarihleri',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            _dateField(
              'Trafik Sigortası Bitiş Tarihi',
              _insurance,
              (v) => setState(() => _insurance = v),
            ),
            _dateField(
              'Kasko Bitiş Tarihi',
              _casco,
              (v) => setState(() => _casco = v),
            ),
            _dateField(
              'Muayene Geçerlilik Bitiş Tarihi',
              _inspection,
              (v) => setState(() => _inspection = v),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving ? 'Kaydediliyor...' : 'Değişiklikleri Kaydet',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
