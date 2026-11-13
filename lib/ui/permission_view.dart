import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

class PermissionView extends ConsumerWidget {
  const PermissionView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.insights, size: 56),
              const SizedBox(height: 16),
              Text(
                'See your week on this phone',
                style: textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'To build your report, Android needs you to grant "Usage access" '
                'to this app. Everything is computed on your device and never '
                'leaves it.',
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () =>
                    ref.read(dataSourceProvider).requestPermission(),
                child: const Text('Open usage access settings'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () =>
                    ref.read(demoModeProvider.notifier).state = true,
                child: const Text('Try it with demo data'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
