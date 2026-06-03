import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync_service.dart';

class SyncStatusBadge extends ConsumerStatefulWidget {
  const SyncStatusBadge({super.key});

  @override
  ConsumerState<SyncStatusBadge> createState() => _SyncStatusBadgeState();
}

class _SyncStatusBadgeState extends ConsumerState<SyncStatusBadge> with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final syncStatus = ref.watch(syncStatusProvider);
    final isSyncing = syncStatus.status == 'syncing';

    if (isSyncing) {
      _rotationController.repeat();
    } else {
      _rotationController.stop();
    }

    Color badgeColor;
    Color textColor;
    IconData icon;
    String label;

    switch (syncStatus.status) {
      case 'syncing':
        badgeColor = Theme.of(context).primaryColor.withOpacity(0.1);
        textColor = Theme.of(context).primaryColor;
        icon = Icons.sync;
        label = 'Syncing...';
        break;
      case 'failed':
        badgeColor = Colors.redAccent.withOpacity(0.1);
        textColor = Colors.redAccent;
        icon = Icons.sync_problem;
        label = 'Sync failed';
        break;
      case 'success':
      default:
        badgeColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green;
        icon = Icons.cloud_done_outlined;
        label = syncStatus.lastSyncedTime == 'Never'
            ? 'Not Synced'
            : 'Synced: ${syncStatus.lastSyncedTime}';
        break;
    }

    return GestureDetector(
      onTap: isSyncing
          ? null
          : () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Syncing with Google Calendar...'),
                  duration: Duration(seconds: 2),
                ),
              );
              ref.read(syncServiceProvider).syncAll();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: textColor.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: textColor.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSyncing)
              RotationTransition(
                turns: _rotationController,
                child: Icon(icon, size: 14, color: textColor),
              )
            else
              Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
