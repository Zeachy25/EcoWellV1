import 'package:flutter/material.dart';

import '../../../core/constants/legal.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Version $kConsentVersion', style: textTheme.bodySmall),
          const SizedBox(height: 16),
          for (final s in legalSections) ...[
            Text(
              s.title,
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(s.body),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}
