import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _description = TextEditingController();
  final _steps = TextEditingController();
  final List<XFile> _attachments = [];
  String _type = 'Hata';
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    _steps.dispose();
    super.dispose();
  }

  Future<void> _addScreenshot() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image != null && mounted) setState(() => _attachments.add(image));
  }

  Future<String> _diagnostics() async {
    final package = await PackageInfo.fromPlatform();
    final device = await DeviceInfoPlugin().deviceInfo;
    return 'Uygulama: ${package.appName} ${package.version}+${package.buildNumber}\n'
        'Platform: ${device.data['systemName'] ?? device.data['brand'] ?? 'Bilinmiyor'}\n'
        'Model: ${device.data['model'] ?? device.data['device'] ?? 'Bilinmiyor'}';
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (AppConfig.supportEmail == 'DESTEK_EPOSTANIZI_YAZIN') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Destek e-posta adresi yapılandırılmamış.'),
        ),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final diagnostics = await _diagnostics();
      final subject = 'Araç Gider Takip - $_type - ${_subject.text.trim()}';
      final body =
          '''Tür: $_type
Konu: ${_subject.text.trim()}
Kullanıcı: ${user?.email ?? 'Bilinmiyor'}

Açıklama:
${_description.text.trim()}

Tekrarlama Adımları / Ek Bilgi:
${_steps.text.trim()}

$diagnostics''';

      if (_attachments.isNotEmpty) {
        await SharePlus.instance.share(
          ShareParams(
            subject: subject,
            text: 'Alıcı: ${AppConfig.supportEmail}\n\n$body',
            files: _attachments,
          ),
        );
        return;
      }

      final uri = Uri(
        scheme: 'mailto',
        path: AppConfig.supportEmail,
        queryParameters: {'subject': subject, 'body': body},
      );
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await SharePlus.instance.share(
          ShareParams(
            subject: subject,
            text: 'Alıcı: ${AppConfig.supportEmail}\n\n$body',
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gönderim başlatılamadı: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İletişim ve Geri Bildirim')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Hata', label: Text('Hata')),
                  ButtonSegment(value: 'Görüş', label: Text('Görüş')),
                  ButtonSegment(value: 'Öneri', label: Text('Öneri')),
                ],
                selected: {_type},
                onSelectionChanged: (value) =>
                    setState(() => _type = value.first),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _subject,
                decoration: const InputDecoration(labelText: 'Konu'),
                validator: (value) =>
                    value?.trim().isEmpty == true ? 'Konu girin' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Açıklama',
                  hintText: 'Ne oldu veya ne öneriyorsunuz?',
                ),
                validator: (value) =>
                    value?.trim().isEmpty == true ? 'Açıklama girin' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _steps,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Tekrarlama adımları / Ek bilgi',
                  hintText: 'Hangi ekranda, hangi işlemden sonra oluştu?',
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _sending ? null : _addScreenshot,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text('Ekran Görüntüsü Ekle (${_attachments.length})'),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(_sending ? 'Hazırlanıyor...' : 'Gönder'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
