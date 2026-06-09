abstract final class SyncItemType {
  static const maintenanceLog = 'maintenance_log';
  static const faultReport = 'fault_report';
  static const elevatorUpdate = 'elevator_update';
}

const syncQueueBoxName = 'pending_sync';

const syncStatusPending = 'pending';
const syncStatusPdfPending = 'pdf_pending';
const syncStatusSchedulePending = 'schedule_pending';
const syncStatusConflictDetected = 'conflict_detected';
const syncStatusDeadLetter = 'dead_letter';
const syncStatusResolving = 'resolving';

class SyncResult {
  const SyncResult({required this.synced, required this.failed});

  final int synced;
  final int failed;

  bool get hasFailures => failed > 0;

  @override
  String toString() => 'SyncResult(synced: $synced, failed: $failed)';
}

const syncMaxRetries = 5;
const syncBaseRetryDelaySeconds = 30;
