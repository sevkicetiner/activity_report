import 'package:flutter/services.dart';

import '../models/report.dart';
import 'usage_data_source.dart';

class AndroidUsageDataSource implements UsageDataSource {
  static const _channel = MethodChannel('activity_report/usage');

  @override
  bool get isDemo => false;

  @override
  Future<bool> hasPermission() async =>
      await _channel.invokeMethod<bool>('hasPermission') ?? false;

  @override
  Future<void> requestPermission() =>
      _channel.invokeMethod<void>('openPermissionSettings');

  @override
  Future<WeeklyReport> fetchWeeklyReport() async {
    final raw = await _channel.invokeMapMethod<String, dynamic>(
      'getWeeklyReport',
    );
    if (raw == null) throw StateError('Empty report from platform channel');

    return WeeklyReport(
      weekStart: DateTime.fromMillisecondsSinceEpoch(
        (raw['weekStartMillis'] as num).toInt(),
      ),
      apps: (raw['apps'] as List)
          .map((m) => AppUsage.fromMap(m as Map<dynamic, dynamic>))
          .toList(),
      installed: (raw['installed'] as List)
          .map((m) => AppRef.fromMap(m as Map<dynamic, dynamic>))
          .toList(),
      removed: (raw['removed'] as List)
          .map((m) => AppRef.fromMap(m as Map<dynamic, dynamic>))
          .toList(),
      notificationsAvailable: raw['notificationsAvailable'] as bool,
      isDemo: false,
      dailyUnlocks: (raw['dailyUnlocks'] as List?)
          ?.map((v) => (v as num).toInt())
          .toList(),
    );
  }
}
