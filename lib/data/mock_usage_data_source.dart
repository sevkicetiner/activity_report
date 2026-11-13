import 'dart:math';

import '../models/report.dart';
import 'usage_data_source.dart';

class _Seed {
  const _Seed(
    this.pkg,
    this.label,
    this.avgMinutes,
    this.opensPerDay,
    this.notifsPerDay,
  );
  final String pkg;
  final String label;
  final int avgMinutes;
  final int opensPerDay;
  final int notifsPerDay;
}

/// Deterministic demo data (fixed seed) so screenshots and tests are stable.
class MockUsageDataSource implements UsageDataSource {
  static const _seeds = [
    _Seed('demo.social', 'Social', 75, 22, 14),
    _Seed('demo.video', 'Video Streaming', 60, 4, 2),
    _Seed('demo.messages', 'Messages', 40, 35, 40),
    _Seed('demo.browser', 'Browser', 30, 12, 0),
    _Seed('demo.music', 'Music', 25, 5, 0),
    _Seed('demo.maps', 'Maps', 10, 3, 0),
    _Seed('demo.mail', 'Mail', 12, 9, 11),
  ];

  @override
  bool get isDemo => true;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> requestPermission() async {}

  @override
  Future<WeeklyReport> fetchWeeklyReport() async {
    final rnd = Random(42);
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day - 6);

    final apps = [
      for (final s in _seeds)
        AppUsage(
          app: AppRef(s.pkg, s.label),
          daily: List.generate(
            WeeklyReport.days,
            (_) => Duration(
              minutes: (s.avgMinutes * (0.4 + rnd.nextDouble() * 1.2)).round(),
            ),
          ),
          openCount: s.opensPerDay * 7 + rnd.nextInt(10),
          notificationCount: s.notifsPerDay * 7 + rnd.nextInt(8),
        ),
    ];

    return WeeklyReport(
      weekStart: weekStart,
      apps: apps,
      installed: const [
        AppRef('demo.focusflow', 'FocusFlow'),
        AppRef('demo.recipebox', 'RecipeBox'),
      ],
      removed: const [AppRef('demo.puzzlerush', 'Puzzle Rush')],
      notificationsAvailable: true,
      isDemo: true,
      dailyUnlocks: List.generate(
        WeeklyReport.days,
        (_) => 45 + rnd.nextInt(40),
      ),
    );
  }
}
