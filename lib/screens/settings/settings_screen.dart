import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/backup_service.dart';
import '../../services/google_drive_service.dart';
import '../premium/premium_screen.dart';
import '../support/feedback_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final BackupService _backup = BackupService();
  bool _busy = false;

  void _message(String value) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _export() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      await _backup.exportToDrive(user.uid);
      _message('Google Drive yedeklemesi tamamlandı.');
    } catch (error) {
      _message('Yedekleme tamamlanamadı: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      final backups = await _backup.listBackups();
      if (!mounted) return;
      if (backups.isEmpty) {
        _message('Google Drive hesabınızda yedek bulunamadı.');
        return;
      }
      final selected = await showModalBottomSheet<DriveBackupFile>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => _BackupPicker(backups: backups),
      );
      if (selected == null || !mounted) return;
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Yedek geri yüklensin mi?'),
              content: Text(
                '${_formatDate(selected.modifiedTime ?? selected.createdTime)} tarihli yedek mevcut verilerle birleştirilecek.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Vazgeç'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Geri Yükle'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
      await _backup.importFromDrive(userId: user.uid, driveFileId: selected.id);
      _message('Yedek başarıyla geri yüklendi.');
    } catch (error) {
      _message('Yedek geri yüklenemedi: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Çıkış yapılsın mı?'),
            content: const Text('Google ve uygulama oturumunuz kapatılacak.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Çıkış Yap'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await AuthService.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      _message('Çıkış yapılamadı: $error');
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteData() async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Tüm veriler silinsin mi?'),
            content: const Text(
              'Araçlar, masraflar, hatırlatmalar ve plaka anahtarları kalıcı olarak silinir. Bu işlem geri alınamaz.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Verilerimi Sil'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      for (final name in [
        'expenses',
        'reminders',
        'vehicle_plate_keys',
        'vehicles',
      ]) {
        final snapshot = await FirebaseFirestore.instance
            .collection(name)
            .where('userId', isEqualTo: user.uid)
            .get();
        for (var offset = 0; offset < snapshot.docs.length; offset += 400) {
          final batch = FirebaseFirestore.instance.batch();
          for (final document in snapshot.docs.skip(offset).take(400)) {
            batch.delete(document.reference);
          }
          await batch.commit();
        }
      }
      _message('Uygulama verileriniz silindi.');
    } catch (error) {
      _message('Veriler silinemedi: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Tarihi bilinmeyen';
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text(user?.displayName ?? 'Profil'),
              subtitle: Text(user?.email ?? ''),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('Premium Hakkında Bilgi'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              ),
            ),
            ListTile(
              enabled: !_busy,
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('Google Drive’a Yedekle'),
              subtitle: const Text('Yeni tarihli bir yedek oluşturur'),
              onTap: _export,
            ),
            ListTile(
              enabled: !_busy,
              leading: const Icon(Icons.cloud_download_outlined),
              title: const Text('Google Drive’dan Geri Yükle'),
              subtitle: const Text('Yedek listesinden seçim yapın'),
              onTap: _import,
            ),
            ListTile(
              leading: const Icon(Icons.feedback_outlined),
              title: const Text('Hata, Görüş veya Öneri Bildir'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FeedbackScreen()),
              ),
            ),
            const Divider(),
            ListTile(
              enabled: !_busy,
              leading: Icon(
                Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Verilerimi Sil',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: _deleteData,
            ),
            ListTile(
              enabled: !_busy,
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Çıkış Yap'),
              onTap: _signOut,
            ),
            if (_busy) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              const Center(child: Text('İşlem yapılıyor...')),
            ],
          ],
        ),
      ),
    );
  }
}

class _BackupPicker extends StatelessWidget {
  const _BackupPicker({required this.backups});
  final List<DriveBackupFile> backups;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Geri Yüklenecek Yedeği Seçin',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: backups.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = backups[index];
              final value = (item.modifiedTime ?? item.createdTime)?.toLocal();
              final dateText = value == null
                  ? 'Tarih bilgisi yok'
                  : '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year} '
                        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
              return ListTile(
                leading: const Icon(Icons.cloud_done_outlined),
                title: Text(dateText),
                subtitle: Text(item.name),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(context, item),
              );
            },
          ),
        ),
      ],
    );
  }
}
