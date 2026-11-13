import '../models/report.dart';

/// The single seam between the UI and the platform.
/// Android: real data via a MethodChannel. iOS / demo: mock data.
abstract class UsageDataSource {
  bool get isDemo;
  Future<bool> hasPermission();
  Future<void> requestPermission();
  Future<WeeklyReport> fetchWeeklyReport();
}
