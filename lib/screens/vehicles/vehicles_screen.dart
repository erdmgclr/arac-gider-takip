import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../models/vehicle.dart';
import '../../repositories/vehicle_repository.dart';
import '../../services/vehicle_background_service.dart';
import '../../services/vehicle_image_service.dart';
import 'add_vehicle_screen.dart';
import 'edit_vehicle_screen.dart';

class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});
  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final VehicleRepository _repository = VehicleRepository();
  final VehicleImageService _imageService = VehicleImageService();
  bool _processingImage = false;
  StreamSubscription<List<Vehicle>>? _subscription;
  List<Vehicle> _vehicles = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _loading = false;
      return;
    }
    _subscription = _repository.watchVehicles(uid).listen((items) {
      if (mounted) {
        _restoreVehicleImages(items);
        setState(() {
          _vehicles = items;
          _loading = false;
        });
      }
    });
  }

  Future<void> _restoreVehicleImages(List<Vehicle> items) async {
    for (final vehicle in items) {
      try {
        final restored = await _imageService.restoreMissingImages(vehicle);
        if (restored.hasChanges) {
          await _repository.updateLocalImagePaths(
            vehicleId: vehicle.id,
            localImagePath: restored.originalPath,
            localStickerPath: restored.stickerPath,
          );
        }
      } catch (_) {
        // Kart varsayılan ikonla açılır; sonraki akışta yeniden denenir.
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _openActions(Vehicle vehicle) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            18,
            0,
            18,
            20 + MediaQuery.viewPaddingOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                vehicle.displayName,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (vehicle.plate?.isNotEmpty == true)
                Text(
                  vehicle.plate!,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              const SizedBox(height: 18),
              _ActionTile(
                icon: Icons.edit_rounded,
                label: 'Aracı Düzenle',
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditVehicleScreen(vehicle: vehicle),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.photo_camera_outlined,
                label: 'Fotoğrafı Değiştir',
                onTap: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditVehicleScreen(vehicle: vehicle),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.auto_fix_high_rounded,
                label: 'Arka Planı Kaldır',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _removeBackground(vehicle);
                },
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Aracı Sil',
                color: Theme.of(context).colorScheme.error,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _delete(vehicle);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeBackground(Vehicle vehicle) async {
    if (_processingImage) return;
    final originalPath = vehicle.localImagePath;
    if (originalPath == null || !File(originalPath).existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Önce araca fotoğraf ekleyin.')),
        );
      }
      return;
    }
    setState(() => _processingImage = true);
    try {
      final stickerPath = await VehicleBackgroundService.instance
          .removeBackground(originalPath);
      final stickerDriveId = await _imageService.uploadToDrive(
        localPath: stickerPath,
        userId: vehicle.userId,
      );
      final updated = Vehicle(
        id: vehicle.id,
        userId: vehicle.userId,
        category: vehicle.category,
        brand: vehicle.brand,
        model: vehicle.model,
        engine: vehicle.engine,
        year: vehicle.year,
        fuelType: vehicle.fuelType,
        hybridType: vehicle.hybridType,
        plate: vehicle.plate,
        normalizedPlate: vehicle.normalizedPlate,
        startKm: vehicle.startKm,
        currentKm: vehicle.currentKm,
        purchasePrice: vehicle.purchasePrice,
        purchaseDate: vehicle.purchaseDate,
        tankCapacity: vehicle.tankCapacity,
        lpgTankCapacity: vehicle.lpgTankCapacity,
        batteryCapacity: vehicle.batteryCapacity,
        mtvNextPaymentDate: vehicle.mtvNextPaymentDate,
        trafficInsuranceEndDate: vehicle.trafficInsuranceEndDate,
        cascoEndDate: vehicle.cascoEndDate,
        inspectionEndDate: vehicle.inspectionEndDate,
        localImagePath: vehicle.localImagePath,
        localStickerPath: stickerPath,
        originalImageDriveId: vehicle.originalImageDriveId,
        stickerImageDriveId: stickerDriveId,
        backgroundRemoved: true,
        status: vehicle.status,
        hasFinancing: vehicle.hasFinancing,
        isCustomBrand: vehicle.isCustomBrand,
        isCustomModel: vehicle.isCustomModel,
        createdAt: vehicle.createdAt,
      );
      await _repository.updateVehicle(vehicle, updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Araç görselinin arka planı kaldırıldı.'),
          ),
        );
      }
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

  Future<void> _delete(Vehicle vehicle) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Araç silinsin mi?'),
            content: Text('${vehicle.displayName} kaldırılacak.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Sil'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) await _repository.deleteVehicle(vehicle);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Araçlarım')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddVehicleScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Araç Ekle'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _vehicles.isEmpty
          ? const Center(child: Text('Henüz kayıtlı araç yok.'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: _vehicles.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final vehicle = _vehicles[index];
                final imagePath =
                    vehicle.localStickerPath ?? vehicle.localImagePath;
                return Material(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () => _openActions(vehicle),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 76,
                            height: 58,
                            child:
                                imagePath != null &&
                                    File(imagePath).existsSync()
                                ? Image.file(
                                    File(imagePath),
                                    fit: BoxFit.contain,
                                  )
                                : Icon(
                                    vehicle.category == 'MOTORCYCLE'
                                        ? Icons.two_wheeler_rounded
                                        : Icons.directions_car_rounded,
                                    size: 44,
                                  ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vehicle.displayName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  vehicle.plate?.isNotEmpty == true
                                      ? vehicle.plate!
                                      : 'Plaka girilmedi',
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  vehicle.currentKm == null
                                      ? 'KM girilmedi'
                                      : '${vehicle.currentKm} km',
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: effectiveColor.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: effectiveColor.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(icon, color: effectiveColor, size: 24),
            const SizedBox(width: 13),
            Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
