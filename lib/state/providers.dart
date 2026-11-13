import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/android_usage_data_source.dart';
import '../data/mock_usage_data_source.dart';
import '../data/usage_data_source.dart';
import '../models/report.dart';

/// True when the user chose demo data, or when the platform cannot provide
/// real data (iOS). Android users can switch it on from the permission screen.
final demoModeProvider = StateProvider<bool>((ref) => !Platform.isAndroid);

final dataSourceProvider = Provider<UsageDataSource>((ref) {
  return ref.watch(demoModeProvider)
      ? MockUsageDataSource()
      : AndroidUsageDataSource();
});

final permissionProvider = FutureProvider<bool>(
  (ref) => ref.watch(dataSourceProvider).hasPermission(),
);

final reportProvider = FutureProvider<WeeklyReport>(
  (ref) => ref.watch(dataSourceProvider).fetchWeeklyReport(),
);
