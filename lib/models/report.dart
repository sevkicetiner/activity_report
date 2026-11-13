// Plain data classes shared by every data source and the UI.

class AppRef {
  const AppRef(this.packageName, this.label);

  final String packageName;
  final String label;

  factory AppRef.fromMap(Map<dynamic, dynamic> m) =>
      AppRef(m['packageName'] as String, m['label'] as String);
}

class AppUsage {
  const AppUsage({
    required this.app,
    required this.daily,
    required this.openCount,
    required this.notificationCount,
  });

  final AppRef app;

  /// Foreground time per day, index 0 = oldest day of the window. Length 7.
  final List<Duration> daily;
  final int openCount;
  final int notificationCount;

  Duration get total => daily.fold<Duration>(Duration.zero, (a, b) => a + b);

  factory AppUsage.fromMap(Map<dynamic, dynamic> m) => AppUsage(
    app: AppRef.fromMap(m),
    daily: (m['dailyMillis'] as List)
        .map((v) => Duration(milliseconds: (v as num).toInt()))
        .toList(),
    openCount: (m['openCount'] as num).toInt(),
    notificationCount: (m['notificationCount'] as num).toInt(),
  );
}

class WeeklyReport {
  const WeeklyReport({
    required this.weekStart,
    required this.apps,
    required this.installed,
    required this.removed,
    required this.notificationsAvailable,
    required this.isDemo,
    this.dailyUnlocks,
  });

  static const days = 7;

  /// Local midnight of the oldest day in the window.
  final DateTime weekStart;
  final List<AppUsage> apps;
  final List<AppRef> installed;
  final List<AppRef> removed;

  /// False when the platform could not give us notification counts.
  final bool notificationsAvailable;
  final bool isDemo;

  /// Device unlocks per day (index 0 = oldest day). Null when the platform
  /// cannot report them (Android < 9).
  final List<int>? dailyUnlocks;

  int? get totalUnlocks => dailyUnlocks?.fold<int>(0, (a, b) => a + b);

  DateTime dayAt(int i) =>
      DateTime(weekStart.year, weekStart.month, weekStart.day + i);

  List<Duration> get dailyTotals => List.generate(
    days,
    (i) => apps.fold<Duration>(Duration.zero, (s, a) => s + a.daily[i]),
  );

  Duration get totalScreenTime =>
      dailyTotals.fold<Duration>(Duration.zero, (a, b) => a + b);

  int get totalOpens => apps.fold<int>(0, (s, a) => s + a.openCount);

  int get totalNotifications =>
      apps.fold<int>(0, (s, a) => s + a.notificationCount);

  int get busiestDayIndex {
    final t = dailyTotals;
    var best = 0;
    for (var i = 1; i < t.length; i++) {
      if (t[i] > t[best]) best = i;
    }
    return best;
  }

  List<AppUsage> get rankedByTime =>
      [...apps]..sort((a, b) => b.total.compareTo(a.total));
}
