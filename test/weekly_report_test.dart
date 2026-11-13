import 'package:activity_report/data/mock_usage_data_source.dart';
import 'package:activity_report/models/report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('screen time is consistent between per-day and per-app views', () async {
    final r = await MockUsageDataSource().fetchWeeklyReport();
    final byApp = r.apps.fold<Duration>(Duration.zero, (s, a) => s + a.total);
    expect(r.dailyTotals.length, WeeklyReport.days);
    expect(r.totalScreenTime, byApp);
  });

  test('busiest day index points at the maximum', () async {
    final r = await MockUsageDataSource().fetchWeeklyReport();
    final totals = r.dailyTotals;
    final max = totals.reduce((a, b) => a > b ? a : b);
    expect(totals[r.busiestDayIndex], max);
  });

  test('AppUsage.fromMap parses the platform-channel payload', () {
    final usage = AppUsage.fromMap({
      'packageName': 'a.b.c',
      'label': 'Demo',
      'dailyMillis': [60000, 0, 120000, 0, 0, 0, 0],
      'openCount': 3,
      'notificationCount': 5,
    });
    expect(usage.app.label, 'Demo');
    expect(usage.total, const Duration(minutes: 3));
    expect(usage.openCount, 3);
  });

  test('unlocks are optional and summed when present', () async {
    final r = await MockUsageDataSource().fetchWeeklyReport();
    expect(r.dailyUnlocks, hasLength(WeeklyReport.days));
    expect(r.totalUnlocks, r.dailyUnlocks!.reduce((a, b) => a + b));

    final noUnlocks = WeeklyReport(
      weekStart: r.weekStart,
      apps: r.apps,
      installed: const [],
      removed: const [],
      notificationsAvailable: false,
      isDemo: true,
    );
    expect(noUnlocks.totalUnlocks, isNull);
  });
}
