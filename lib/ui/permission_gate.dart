import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'permission_view.dart';
import 'report_page.dart';

/// Shows the report when we can read data, otherwise explains the permission.
/// Re-checks the permission when the user comes back from system settings.
class PermissionGate extends ConsumerStatefulWidget {
  const PermissionGate({super.key});

  @override
  ConsumerState<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends ConsumerState<PermissionGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(permissionProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perm = ref.watch(permissionProvider);
    final granted = perm.valueOrNull;

    if (granted == true) return const ReportPage();
    if (granted == false) return const PermissionView();
    if (perm.hasError) {
      return Scaffold(body: Center(child: Text('${perm.error}')));
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
