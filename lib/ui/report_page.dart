import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report.dart';
import '../state/providers.dart';
import 'format.dart';

class ReportPage extends ConsumerWidget {
  const ReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(reportProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your week'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(reportProvider),
          ),
        ],
      ),
      body: report.when(
        data: (r) => RefreshIndicator(
          onRefresh: () => ref.refresh(reportProvider.future),
          child: _ReportView(report: r),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load the report.\n$e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView({required this.report});
  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final ranked = report.rankedByTime;
    final busiest = report.busiestDayIndex;
    final busiestDay = weekdayNames[report.dayAt(busiest).weekday - 1];
    final tileWidth = (MediaQuery.of(context).size.width - 32 - 12) / 2;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        if (report.isDemo) ...[const _DemoBanner(), const SizedBox(height: 12)],
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _StatTile(
              width: tileWidth,
              label: 'Total screen time',
              value: formatDuration(report.totalScreenTime),
            ),
            _StatTile(
              width: tileWidth,
              label: 'Busiest day',
              value:
                  '$busiestDay · ${formatDuration(report.dailyTotals[busiest])}',
            ),
            if (ranked.isNotEmpty)
              _StatTile(
                width: tileWidth,
                label: 'Most used app',
                value: ranked.first.app.label,
              ),
            _StatTile(
              width: tileWidth,
              label: 'App opens',
              value: '${report.totalOpens}',
            ),
            if (report.totalUnlocks case final unlocks?)
              _StatTile(
                width: tileWidth,
                label: 'Phone unlocks',
                value:
                    '$unlocks · ${formatAverage(unlocks / WeeklyReport.days)}/day',
              ),
            if (report.notificationsAvailable)
              _StatTile(
                width: tileWidth,
                label: 'Notifications',
                value: '${report.totalNotifications}',
              ),
          ],
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Screen time per day',
          child: _DailyChart(report: report),
        ),
        _SectionCard(
          title: 'Most used apps',
          child: _TopApps(
            apps: ranked.take(5).toList(),
            showNotifications: report.notificationsAvailable,
          ),
        ),
        _SectionCard(
          title: 'Installed & removed',
          child: _AppChanges(report: report),
        ),
      ],
    );
  }
}

class _DemoBanner extends StatelessWidget {
  const _DemoBanner();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.science_outlined),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Demo data. This platform does not let apps read other apps\' '
                'usage, or you chose to skip the permission.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.width,
    required this.label,
    required this.value,
  });
  final double width;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: t.labelMedium),
              const SizedBox(height: 6),
              Text(
                value,
                style: t.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _DailyChart extends StatelessWidget {
  const _DailyChart({required this.report});
  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    final totals = report.dailyTotals;
    final maxMinutes = totals
        .map((d) => d.inMinutes)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final color = Theme.of(context).colorScheme.primary;
    final small = Theme.of(context).textTheme.labelSmall;
    const maxBar = 90.0;

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < totals.length; i++)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    totals[i].inMinutes == 0
                        ? ''
                        : '${(totals[i].inMinutes / 60).toStringAsFixed(1)}h',
                    style: small,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 22,
                    height: maxMinutes == 0
                        ? 2
                        : (maxBar * totals[i].inMinutes / maxMinutes).clamp(
                            2.0,
                            maxBar,
                          ),
                    decoration: BoxDecoration(
                      color: i == report.busiestDayIndex
                          ? color
                          : color.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(weekdayNames[report.dayAt(i).weekday - 1], style: small),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TopApps extends StatelessWidget {
  const _TopApps({required this.apps, required this.showNotifications});
  final List<AppUsage> apps;
  final bool showNotifications;

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) return const Text('No usage recorded yet.');
    final maxMinutes = apps.first.total.inMinutes;
    final small = Theme.of(context).textTheme.bodySmall;

    return Column(
      children: [
        for (final a in apps)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(a.app.label, overflow: TextOverflow.ellipsis),
                    ),
                    Text(formatDuration(a.total)),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: maxMinutes == 0 ? 0 : a.total.inMinutes / maxMinutes,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 2),
                Text(
                  '${a.openCount} opens'
                  '${showNotifications ? ' · ${a.notificationCount} notifications' : ''}',
                  style: small,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AppChanges extends StatelessWidget {
  const _AppChanges({required this.report});
  final WeeklyReport report;

  @override
  Widget build(BuildContext context) {
    if (report.installed.isEmpty && report.removed.isEmpty) {
      return const Text('No changes this week.');
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final a in report.installed)
          Chip(avatar: const Icon(Icons.add, size: 18), label: Text(a.label)),
        for (final a in report.removed)
          Chip(
            avatar: const Icon(Icons.delete_outline, size: 18),
            label: Text(a.label),
          ),
      ],
    );
  }
}
