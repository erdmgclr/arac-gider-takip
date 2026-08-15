import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../../core/utils/formatters.dart';
import '../../models/vehicle.dart';
import '../../repositories/vehicle_repository.dart';
import '../../services/vehicle_image_service.dart';
import '../../services/vehicle_background_service.dart';
import '../../widgets/app_date_time_picker.dart';

part 'add_vehicle_screen_widgets.dart';

enum VehicleCategory { car, motorcycle }

enum VehicleFuelType { petrol, diesel, lpg, petrolLpg, electric, hybrid, other }

class AddVehicleScreen extends StatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final PageController _pageController = PageController();
  final VehicleRepository _vehicleRepository = VehicleRepository();
  final VehicleImageService _imageService = VehicleImageService();

  final GlobalKey<FormState> _basicInfoFormKey = GlobalKey<FormState>();

  final GlobalKey<FormState> _usageInfoFormKey = GlobalKey<FormState>();

  final TextEditingController _brandController = TextEditingController();

  final TextEditingController _modelController = TextEditingController();

  final TextEditingController _engineController = TextEditingController();

  final TextEditingController _yearController = TextEditingController();

  final TextEditingController _plateController = TextEditingController();

  final TextEditingController _kilometerController = TextEditingController();

  final TextEditingController _purchasePriceController =
      TextEditingController();

  final TextEditingController _tankCapacityController = TextEditingController();

  final TextEditingController _lpgTankCapacityController =
      TextEditingController();

  final TextEditingController _batteryCapacityController =
      TextEditingController();

  int _currentStep = 0;

  VehicleCategory _vehicleCategory = VehicleCategory.car;

  VehicleFuelType? _fuelType;

  String? _hybridType;

  DateTime? _purchaseDate;
  bool _addTrackingDates = false;
  DateTime? _trafficInsuranceEndDate;
  DateTime? _cascoEndDate;
  DateTime? _inspectionEndDate;

  bool _isCustomBrand = false;
  bool _isCustomModel = false;
  bool _isSaving = false;
  String? _localImagePath;
  String? _localStickerPath;
  bool _removingBackground = false;

  final List<String> _carBrands = const [
    'Audi',
    'BMW',
    'BYD',
    'Chery',
    'Citroen',
    'Dacia',
    'Fiat',
    'Ford',
    'Honda',
    'Hyundai',
    'Kia',
    'Mercedes-Benz',
    'MG',
    'Nissan',
    'Opel',
    'Peugeot',
    'Renault',
    'Seat',
    'Skoda',
    'Tesla',
    'Togg',
    'Toyota',
    'Volkswagen',
    'Volvo',
  ];

  final List<String> _motorcycleBrands = const [
    'Arora',
    'Bajaj',
    'BMW Motorrad',
    'CFMoto',
    'Honda',
    'Kawasaki',
    'KTM',
    'Kuba',
    'Mondial',
    'Piaggio',
    'RKS',
    'Suzuki',
    'TVS',
    'Vespa',
    'Yamaha',
    'Yuki',
  ];

  final Map<String, List<String>> _demoModels = const {
    'Fiat': ['Egea', 'Doblo', 'Fiorino', 'Linea', 'Panda', 'Punto', 'Tipo'],
    'Renault': ['Clio', 'Megane', 'Captur', 'Austral', 'Taliant', 'Kangoo'],
    'Toyota': ['Corolla', 'Yaris', 'C-HR', 'Corolla Cross', 'RAV4', 'Hilux'],
    'Honda': ['Civic', 'City', 'CR-V', 'HR-V', 'Jazz', 'PCX', 'Forza', 'CBR'],
    'Opel': ['Astra', 'Corsa', 'Mokka', 'Crossland', 'Grandland', 'Combo'],
    'Yamaha': ['NMAX', 'XMAX', 'MT-07', 'MT-09', 'R25', 'Tenere 700'],
  };

  @override
  void dispose() {
    _pageController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _engineController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    _kilometerController.dispose();
    _purchasePriceController.dispose();
    _tankCapacityController.dispose();
    _lpgTankCapacityController.dispose();
    _batteryCapacityController.dispose();
    super.dispose();
  }

  List<String> get _availableBrands {
    return _vehicleCategory == VehicleCategory.car
        ? _carBrands
        : _motorcycleBrands;
  }

  List<String> get _availableModels {
    return _demoModels[_brandController.text] ?? const [];
  }

  bool get _isElectric {
    return _fuelType == VehicleFuelType.electric;
  }

  bool get _isPetrolLpg {
    return _fuelType == VehicleFuelType.petrolLpg;
  }

  bool get _isHybrid {
    return _fuelType == VehicleFuelType.hybrid;
  }

  bool get _isPlugInHybrid {
    return _isHybrid && _hybridType == 'Plug-in Hibrit';
  }

  void _changeVehicleCategory(VehicleCategory category) {
    if (_vehicleCategory == category) {
      return;
    }

    setState(() {
      _vehicleCategory = category;
      _brandController.clear();
      _modelController.clear();
      _engineController.clear();
      _isCustomBrand = false;
      _isCustomModel = false;
    });
  }

  Future<void> _selectBrand() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return _SearchSelectionSheet(
          title: 'Marka Seç',
          searchHint: 'Marka ara',
          items: _availableBrands,
          customOptionText: 'Markamı bulamadım',
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    if (result == _SearchSelectionSheet.customValue) {
      setState(() {
        _isCustomBrand = true;
        _isCustomModel = true;
        _brandController.clear();
        _modelController.clear();
      });

      return;
    }

    setState(() {
      _isCustomBrand = false;
      _isCustomModel = false;
      _brandController.text = result;
      _modelController.clear();
    });

    // Marka seçim penceresinin kapanmasını bekle.
    await Future<void>.delayed(const Duration(milliseconds: 220));

    if (!mounted) {
      return;
    }

    // Marka seçildikten sonra model ekranını otomatik aç.
    await _selectModel();
  }

  Future<void> _selectModel() async {
    if (_brandController.text.trim().isEmpty) {
      _showMessage('Önce marka seçmelisiniz.');
      return;
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        return _SearchSelectionSheet(
          title: 'Model Seç',
          searchHint: 'Model ara',
          items: _availableModels,
          customOptionText: 'Modelimi bulamadım',
        );
      },
    );

    if (result == null) {
      return;
    }

    if (result == _SearchSelectionSheet.customValue) {
      setState(() {
        _isCustomModel = true;
        _modelController.clear();
      });

      return;
    }

    setState(() {
      _isCustomModel = false;
      _modelController.text = result;
    });
  }

  Future<void> _selectPurchaseDate() async {
    final selectedDate = await AppDateTimePicker.show(
      context,
      title: 'Alış Tarihi',
      mode: AppPickerMode.date,
      initialValue: _purchaseDate ?? DateTime.now(),
      minimumDate: DateTime(1950),
      maximumDate: DateTime.now(),
    );

    if (!mounted || selectedDate == null) {
      return;
    }

    setState(() {
      _purchaseDate = selectedDate;
    });
  }

  Future<void> _pickTrackingDate(
    String title,
    DateTime? current,
    ValueChanged<DateTime?> onChanged,
  ) async {
    final value = await AppDateTimePicker.show(
      context,
      title: title,
      mode: AppPickerMode.date,
      initialValue: current ?? DateTime.now(),
      minimumDate: DateTime(1950),
      maximumDate: DateTime(2100),
    );
    if (mounted && value != null) onChanged(value);
  }

  Widget _trackingDateTile(
    String title,
    DateTime? value,
    ValueChanged<DateTime?> onChanged,
  ) {
    final text = value == null
        ? 'Daha sonra ekle'
        : '${value.day.toString().padLeft(2, '0')}.'
              '${value.month.toString().padLeft(2, '0')}.${value.year}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(text),
      trailing: Wrap(
        children: [
          if (value != null)
            IconButton(
              onPressed: () => onChanged(null),
              icon: const Icon(Icons.close_rounded),
            ),
          IconButton(
            onPressed: () => _pickTrackingDate(title, value, onChanged),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
        ],
      ),
    );
  }

  Future<void> _goToNextStep() async {
    if (_currentStep == 0) {
      final isValid = _basicInfoFormKey.currentState?.validate() ?? false;

      if (!isValid) {
        return;
      }
    }

    if (_currentStep == 1) {
      final isValid = _usageInfoFormKey.currentState?.validate() ?? false;

      if (!isValid) {
        return;
      }

      final shouldContinue = await _checkOptionalInformation();

      if (!shouldContinue) {
        return;
      }
    }

    if (_currentStep >= 2) {
      return;
    }

    setState(() {
      _currentStep++;
    });

    await _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<bool> _checkOptionalInformation() async {
    final kilometerMissing = _kilometerController.text.trim().isEmpty;

    final priceMissing = _purchasePriceController.text.trim().isEmpty;

    if (!kilometerMissing && !priceMissing) {
      return true;
    }

    final missingInformation = <String>[];

    if (kilometerMissing) {
      missingInformation.add(
        'Kilometre bilgisi olmadığı için kilometre başına maliyet hesaplanamaz.',
      );
    }

    if (priceMissing) {
      missingInformation.add(
        'Alış fiyatı olmadığı için toplam sahip olma maliyeti hesaplanamaz.',
      );
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.info_outline_rounded),
          title: const Text('Bazı bilgiler eksik'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: missingInformation
                .map(
                  (message) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Icon(Icons.circle, size: 7),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(message)),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Bilgileri Tamamla'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Yine de Devam Et'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  void _goToPreviousStep() {
    if (_currentStep == 0) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _currentStep--;
    });

    _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _chooseVehiclePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
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
    final path = await _imageService.pickAndSave(source);
    if (!mounted || path == null) return;
    setState(() => _localImagePath = path);
  }

  Future<void> _removeVehicleBackground() async {
    final originalPath = _localImagePath;
    if (originalPath == null) {
      _showMessage('Önce araç fotoğrafı seçin.');
      return;
    }
    setState(() => _removingBackground = true);
    try {
      final stickerPath = await VehicleBackgroundService.instance
          .removeBackground(originalPath);
      if (mounted) setState(() => _localStickerPath = stickerPath);
    } catch (error) {
      if (mounted) _showMessage('Arka plan kaldırılamadı: $error');
    } finally {
      if (mounted) setState(() => _removingBackground = false);
    }
  }

  Future<void> _saveVehicle() async {
    if (_isSaving) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Araç kaydetmek için yeniden giriş yapmalısınız.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final plate = _plateController.text.trim();
      final km = int.tryParse(_kilometerController.text.trim());
      String? originalImageDriveId;
      String? stickerImageDriveId;
      if (_localImagePath != null) {
        originalImageDriveId = await _imageService.uploadToDrive(
          localPath: _localImagePath!,
          userId: user.uid,
        );
      }
      if (_localStickerPath != null) {
        stickerImageDriveId = await _imageService.uploadToDrive(
          localPath: _localStickerPath!,
          userId: user.uid,
        );
      }
      final vehicle = Vehicle(
        id: '',
        userId: user.uid,
        category: _vehicleCategory == VehicleCategory.car
            ? 'CAR'
            : 'MOTORCYCLE',
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        engine: _empty(_engineController.text),
        year: int.tryParse(_yearController.text.trim()),
        fuelType: _fuelTypeCode(_fuelType!),
        hybridType: _empty(_hybridType),
        plate: _empty(plate),
        normalizedPlate: VehicleRepository.normalizePlate(plate),
        startKm: km,
        currentKm: km,
        purchasePrice: _decimal(_purchasePriceController.text),
        purchaseDate: _purchaseDate,
        tankCapacity: _decimal(_tankCapacityController.text),
        lpgTankCapacity: _decimal(_lpgTankCapacityController.text),
        batteryCapacity: _decimal(_batteryCapacityController.text),
        trafficInsuranceEndDate: _trafficInsuranceEndDate,
        cascoEndDate: _cascoEndDate,
        inspectionEndDate: _inspectionEndDate,
        localImagePath: _localImagePath,
        localStickerPath: _localStickerPath,
        originalImageDriveId: originalImageDriveId,
        stickerImageDriveId: stickerImageDriveId,
        backgroundRemoved: _localStickerPath != null,
      );
      await _vehicleRepository.addVehicle(vehicle);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            Icons.check_circle_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 52,
          ),
          title: const Text('Araç başarıyla eklendi'),
          content: Text(
            '${vehicle.brand} ${vehicle.model} ana sayfaya eklendi.',
            textAlign: TextAlign.center,
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Ana Sayfaya Dön'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on DuplicatePlateException catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded),
          title: const Text('Bu plaka zaten kayıtlı'),
          content: Text(
            '${e.plate.toUpperCase()} plakalı araç hesabınızda zaten bulunuyor.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Plakayı Düzelt'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) _showMessage('Araç kaydedilemedi: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _empty(String? value) {
    final v = value?.trim();
    return v == null || v.isEmpty ? null : v;
  }

  double? _decimal(String value) {
    final v = value.trim().replaceAll(' ', '').replaceAll(',', '.');
    return v.isEmpty ? null : double.tryParse(v);
  }

  String _fuelTypeCode(VehicleFuelType type) {
    return switch (type) {
      VehicleFuelType.petrol => 'PETROL',
      VehicleFuelType.diesel => 'DIESEL',
      VehicleFuelType.lpg => 'LPG',
      VehicleFuelType.petrolLpg => 'PETROL_LPG',
      VehicleFuelType.electric => 'ELECTRIC',
      VehicleFuelType.hybrid => 'HYBRID',
      VehicleFuelType.other => 'OTHER',
    };
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Araç Ekle'),
        leading: IconButton(
          onPressed: _goToPreviousStep,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _buildStepIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildBasicInformationStep(),
                  _buildUsageInformationStep(),
                  _buildPhotoAndReviewStep(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildStepIndicator() {
    const titles = ['Araç', 'Kullanım', 'Kontrol'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: Row(
        children: List.generate(titles.length, (index) {
          final isCompleted = index < _currentStep;
          final isSelected = index == _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (index > 0)
                            Expanded(
                              child: Container(
                                height: 2,
                                color: index <= _currentStep
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).dividerColor,
                              ),
                            ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected || isCompleted
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                            ),
                            child: isCompleted
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 17,
                                    color: Colors.white,
                                  )
                                : Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                          if (index < titles.length - 1)
                            Expanded(
                              child: Container(
                                height: 2,
                                color: index < _currentStep
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).dividerColor,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        titles[index],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildBasicInformationStep() {
    return Form(
      key: _basicInfoFormKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          _buildStepHeader(
            icon: Icons.directions_car_rounded,
            title: 'Araç Bilgileri',
            description:
                'Giderlerini takip etmek istediğiniz aracı tanımlayın.',
          ),
          const SizedBox(height: 20),
          _buildSectionCard(
            title: 'Araç Türü',
            child: Row(
              children: [
                Expanded(
                  child: _VehicleCategoryButton(
                    title: 'Otomobil',
                    icon: Icons.directions_car_rounded,
                    selected: _vehicleCategory == VehicleCategory.car,
                    onTap: () {
                      _changeVehicleCategory(VehicleCategory.car);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _VehicleCategoryButton(
                    title: 'Motosiklet',
                    icon: Icons.two_wheeler_rounded,
                    selected: _vehicleCategory == VehicleCategory.motorcycle,
                    onTap: () {
                      _changeVehicleCategory(VehicleCategory.motorcycle);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSectionCard(
            title: 'Marka ve Model',
            child: Column(
              children: [
                if (_isCustomBrand)
                  TextFormField(
                    controller: _brandController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Marka *',
                      hintText: 'Markayı yazın',
                      prefixIcon: Icon(Icons.sell_outlined),
                    ),
                    validator: _requiredValidator,
                  )
                else
                  _SelectionField(
                    label: 'Marka *',
                    value: _brandController.text,
                    emptyText: 'Marka seçin',
                    icon: Icons.sell_outlined,
                    onTap: _selectBrand,
                    validator: _requiredValidator,
                  ),
                const SizedBox(height: 12),
                if (_isCustomModel)
                  TextFormField(
                    controller: _modelController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Model *',
                      hintText: 'Modeli yazın',
                      prefixIcon: Icon(Icons.directions_car_outlined),
                    ),
                    validator: _requiredValidator,
                  )
                else
                  _SelectionField(
                    label: 'Model *',
                    value: _modelController.text,
                    emptyText: _brandController.text.isEmpty
                        ? 'Önce marka seçin'
                        : 'Model seçin',
                    icon: Icons.directions_car_outlined,
                    onTap: _selectModel,
                    validator: _requiredValidator,
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _engineController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Motor / Versiyon',
                    prefixIcon: Icon(Icons.settings_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Model Yılı',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null;
                    }

                    final year = int.tryParse(value);
                    final maximumYear = DateTime.now().year + 1;

                    if (year == null || year < 1900 || year > maximumYear) {
                      return 'Geçerli bir model yılı girin';
                    }

                    return null;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageInformationStep() {
    return Form(
      key: _usageInfoFormKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          _buildStepHeader(
            icon: Icons.speed_rounded,
            title: 'Kullanım Bilgileri',
            description:
                'Maliyet ve tüketim hesaplamalarında kullanılacak bilgileri ekleyin.',
          ),
          const SizedBox(height: 20),
          _buildSectionCard(
            title: 'Yakıt ve Enerji',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<VehicleFuelType>(
                  initialValue: _fuelType,
                  decoration: const InputDecoration(
                    labelText: 'Yakıt / Enerji Türü *',
                    prefixIcon: Icon(Icons.local_gas_station_outlined),
                  ),
                  items: VehicleFuelType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(_fuelTypeLabel(type)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _fuelType = value;

                      if (value != VehicleFuelType.hybrid) {
                        _hybridType = null;
                      }
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Yakıt veya enerji türünü seçin';
                    }

                    return null;
                  },
                ),
                if (_isHybrid) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _hybridType,
                    decoration: const InputDecoration(
                      labelText: 'Hibrit Türü *',
                      prefixIcon: Icon(Icons.electric_bolt_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Benzin Hibrit',
                        child: Text('Benzin Hibrit'),
                      ),
                      DropdownMenuItem(
                        value: 'Dizel Hibrit',
                        child: Text('Dizel Hibrit'),
                      ),
                      DropdownMenuItem(
                        value: 'Plug-in Hibrit',
                        child: Text('Plug-in Hibrit'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _hybridType = value;
                      });
                    },
                    validator: (value) {
                      if (_isHybrid && value == null) {
                        return 'Hibrit türünü seçin';
                      }

                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 12),
                if (_isElectric)
                  _buildCapacityField(
                    controller: _batteryCapacityController,
                    label: 'Batarya Kapasitesi',
                    suffix: 'kWh',
                    icon: Icons.battery_charging_full_rounded,
                  )
                else if (_isPetrolLpg) ...[
                  _buildCapacityField(
                    controller: _tankCapacityController,
                    label: 'Benzin Deposu',
                    suffix: 'L',
                    icon: Icons.local_gas_station_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildCapacityField(
                    controller: _lpgTankCapacityController,
                    label: 'LPG Tankı',
                    suffix: 'L',
                    icon: Icons.propane_tank_outlined,
                  ),
                ] else if (_isPlugInHybrid) ...[
                  _buildCapacityField(
                    controller: _tankCapacityController,
                    label: 'Yakıt Deposu',
                    suffix: 'L',
                    icon: Icons.local_gas_station_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildCapacityField(
                    controller: _batteryCapacityController,
                    label: 'Batarya Kapasitesi',
                    suffix: 'kWh',
                    icon: Icons.battery_charging_full_rounded,
                  ),
                ] else if (_fuelType != null &&
                    _fuelType != VehicleFuelType.other &&
                    !_isHybrid)
                  _buildCapacityField(
                    controller: _tankCapacityController,
                    label: 'Depo Kapasitesi',
                    suffix: 'L',
                    icon: Icons.local_gas_station_outlined,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSectionCard(
            title: 'Araç ve Kilometre',
            child: Column(
              children: [
                TextFormField(
                  controller: _plateController,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(12),
                    _UpperCaseTextFormatter(),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Plaka',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _kilometerController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Alındığı Kilometre',
                    prefixIcon: Icon(Icons.speed_rounded),
                    suffixText: 'km',
                    helperText:
                        'Sıfır kilometre araç için 0, ikinci el araç için satın alındığı kilometreyi girin.',
                    helperMaxLines: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSectionCard(
            title: 'Satın Alma Bilgileri',
            child: Column(
              children: [
                TextFormField(
                  controller: _purchasePriceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Araç Alış Fiyatı',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    prefixText: '₺ ',
                    helperText:
                        'Toplam sahip olma maliyetinin hesaplanması için kullanılır.',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _selectPurchaseDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Alış Tarihi',
                      prefixIcon: Icon(Icons.calendar_month_outlined),
                      suffixIcon: Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                    child: Text(
                      _purchaseDate == null
                          ? 'Tarih seçin'
                          : Formatters.date(_purchaseDate!),
                      style: TextStyle(
                        color: _purchaseDate == null
                            ? Theme.of(context).colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSectionCard(
            title: 'Takip Tarihleri',
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Şimdi eklemek istiyorum'),
                  subtitle: const Text(
                    'Sigorta, kasko ve muayene bitiş tarihleri yaklaşınca takip edilir. Daha sonra araç düzenleme ekranından da eklenebilir.',
                  ),
                  value: _addTrackingDates,
                  onChanged: (value) =>
                      setState(() => _addTrackingDates = value),
                ),
                if (_addTrackingDates) ...[
                  _trackingDateTile(
                    'Trafik Sigortası Bitiş Tarihi',
                    _trafficInsuranceEndDate,
                    (value) => setState(() => _trafficInsuranceEndDate = value),
                  ),
                  _trackingDateTile(
                    'Kasko Bitiş Tarihi',
                    _cascoEndDate,
                    (value) => setState(() => _cascoEndDate = value),
                  ),
                  _trackingDateTile(
                    'Muayene Geçerlilik Bitiş Tarihi',
                    _inspectionEndDate,
                    (value) => setState(() => _inspectionEndDate = value),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoAndReviewStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        _buildStepHeader(
          icon: Icons.fact_check_outlined,
          title: 'Fotoğraf ve Kontrol',
          description:
              'Araç bilgilerini kontrol edin ve isterseniz araç fotoğrafı ekleyin.',
        ),
        const SizedBox(height: 20),
        _buildSectionCard(
          title: 'Araç Fotoğrafı',
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _chooseVehiclePhoto,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                children: [
                  if (_localImagePath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        File(_localImagePath!),
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Icon(
                      _vehicleCategory == VehicleCategory.car
                          ? Icons.directions_car_rounded
                          : Icons.two_wheeler_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  const SizedBox(height: 14),
                  Text(
                    'Araç Fotoğrafı Ekleyin',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fotoğraf zorunlu değildir. Daha sonra araç detayından ekleyebilirsiniz.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _chooseVehiclePhoto,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: Text(
                      _localImagePath == null
                          ? 'Fotoğraf Ekle'
                          : 'Fotoğrafı Değiştir',
                    ),
                  ),
                  if (_localImagePath != null) ...[
                    const SizedBox(height: 10),
                    FilledButton.tonalIcon(
                      onPressed: _removingBackground
                          ? null
                          : _removeVehicleBackground,
                      icon: _removingBackground
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_fix_high_rounded),
                      label: Text(
                        _removingBackground
                            ? 'Arka plan kaldırılıyor...'
                            : 'Arka Planı Kaldır',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildSectionCard(
          title: 'Araç Özeti',
          child: Column(
            children: [
              _ReviewRow(
                icon: _vehicleCategory == VehicleCategory.car
                    ? Icons.directions_car_rounded
                    : Icons.two_wheeler_rounded,
                title: 'Araç',
                value: '${_brandController.text} ${_modelController.text}',
              ),
              if (_engineController.text.trim().isNotEmpty)
                _ReviewRow(
                  icon: Icons.settings_outlined,
                  title: 'Motor / Versiyon',
                  value: _engineController.text,
                ),
              if (_yearController.text.trim().isNotEmpty)
                _ReviewRow(
                  icon: Icons.calendar_today_outlined,
                  title: 'Model Yılı',
                  value: _yearController.text,
                ),
              _ReviewRow(
                icon: Icons.local_gas_station_outlined,
                title: 'Yakıt / Enerji',
                value: _fuelType == null
                    ? 'Belirtilmedi'
                    : _fuelTypeLabel(_fuelType!),
              ),
              if (_plateController.text.trim().isNotEmpty)
                _ReviewRow(
                  icon: Icons.pin_outlined,
                  title: 'Plaka',
                  value: _plateController.text,
                ),
              _ReviewRow(
                icon: Icons.speed_rounded,
                title: 'Alındığı Kilometre',
                value: _kilometerController.text.trim().isEmpty
                    ? 'Belirtilmedi'
                    : '${_kilometerController.text} km',
              ),
              _ReviewRow(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Alış Fiyatı',
                value: _purchasePriceController.text.trim().isEmpty
                    ? 'Belirtilmedi'
                    : '₺${_purchasePriceController.text}',
                showDivider: false,
              ),
            ],
          ),
        ),
        if (_kilometerController.text.trim().isEmpty ||
            _purchasePriceController.text.trim().isEmpty) ...[
          const SizedBox(height: 14),
          _buildMissingInformationCard(),
        ],
      ],
    );
  }

  Widget _buildMissingInformationCard() {
    final messages = <String>[];

    if (_kilometerController.text.trim().isEmpty) {
      messages.add(
        'Sıfır kilometre araç için 0, ikinci el araç için alındığı kilometre gereklidir.',
      );
    }

    if (_purchasePriceController.text.trim().isEmpty) {
      messages.add('Toplam sahip olma maliyeti için alış fiyatı gereklidir.');
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.tertiaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Bazı hesaplamalar kullanılamayacak',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...messages.map(
            (message) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 6),
                  ),
                  const SizedBox(width: 9),
                  Expanded(child: Text(message)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        child: Row(
          children: [
            if (_currentStep > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _goToPreviousStep,
                  child: const Text('Geri'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: _currentStep > 0 ? 2 : 1,
              child: FilledButton(
                onPressed: _isSaving
                    ? null
                    : _currentStep == 2
                    ? _saveVehicle
                    : _goToNextStep,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_currentStep == 2 ? 'Aracı Kaydet' : 'Devam Et'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepHeader({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0D0D) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF242424) : const Color(0xFFE3E7ED),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }

  Widget _buildCapacityField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixText: suffix,
        helperText: 'Opsiyonel, daha sonra düzenlenebilir.',
      ),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Bu alan zorunludur';
    }

    return null;
  }

  String _fuelTypeLabel(VehicleFuelType type) {
    switch (type) {
      case VehicleFuelType.petrol:
        return 'Benzin';
      case VehicleFuelType.diesel:
        return 'Dizel';
      case VehicleFuelType.lpg:
        return 'LPG';
      case VehicleFuelType.petrolLpg:
        return 'Benzin + LPG';
      case VehicleFuelType.electric:
        return 'Elektrik';
      case VehicleFuelType.hybrid:
        return 'Hibrit';
      case VehicleFuelType.other:
        return 'Diğer';
    }
  }

}

