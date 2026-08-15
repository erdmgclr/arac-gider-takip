import 'package:flutter/material.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Araç Gider Takip Premium',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            const ListTile(
              leading: Icon(Icons.cloud_done_outlined),
              title: Text('Otomatik Google Drive yedekleme'),
            ),
            const ListTile(
              leading: Icon(Icons.receipt_long_outlined),
              title: Text('Sınırsız belge ve fiş arşivi'),
            ),
            const ListTile(
              leading: Icon(Icons.analytics_outlined),
              title: Text('Gelişmiş maliyet raporları'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(
                  title: Text('Mağaza yapılandırması gerekli'),
                  content: Text(
                    'Google Play Console veya App Store Connect ürünleri '
                    'oluşturulduktan sonra satın alma servisi bağlanacaktır.',
                  ),
                ),
              ),
              child: const Text('Premium Hakkında Bilgi'),
            ),
          ],
        ),
      ),
    );
  }
}
