// lib/models/schedule_model.dart

class Schedule {
  final String userID;
  final String userName;
  final String date;
  final List<ScheduleTask> tasks;

  Schedule({
    required this.userID,
    required this.userName,
    required this.date,
    required this.tasks,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    return Schedule(
      userID: json['UserID'] ?? json['userId'] ?? json['uid'] ?? '',
      userName: json['UserName'] ?? json['userName'] ?? '',
      date: json['Date'] ?? json['date'] ?? '',
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((e) => ScheduleTask.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userID,
      'userName': userName,
      'date': date,
      'tasks': tasks.map((e) => e.toJson()).toList(),
    };
  }
}

class ScheduleTask {
  final String taskId;
  final int taskNumber;
  final String taskName;
  final String time;
  final String type;
  final bool isCompleted;
  final String status;

  final String? scheduledAt;
  final String? validFrom;
  final String? validUntil;

  final int? graceMinutes;
  final int? retryCount;
  final int? maxRetries;
  final int? retryIntervalMinutes;

  final String? lastReminderAt;
  final String? acknowledgedAt;
  final String? startedAt;
  final String? skippedAt;
  final String? skipReason;
  final List<String>? skipReasons;
  final String? skipDecisionBy;
  final String? caregiverSkipNote;
  final String? snoozedUntil;

  final String? completedAt;
  final String? completedBy;

  final String? priority;
  final String? riskLevel;
  final String? recurrenceRule;

  final bool? caregiverNotified;
  final bool? escalateOnMiss;

  // --- skip policy (rule-derived, immutable after creation) ---
  final bool? caregiverSkipNotified;
  final bool? escalateOnSkip;
  final bool? requireSkipConfirmation;
  final bool? allowPreScheduleSkip;
  final bool? notifyCaregiverOnSkip;
  final int? skipLimitWindowDays;
  final int? skipLimitCount;
  final int? skipCount;
  final int? skipCountWindow;
  final bool? skipReviewRequired;
  final String? lastSkipDecisionBy;
  final String? pendingReminderInvalidatedAt;
  final int? reminderVersion;

  final String? createdAt;
  final String? updatedAt;

  ScheduleTask({
    required this.taskId,
    required this.taskNumber,
    required this.taskName,
    required this.time,
    required this.type,
    required this.isCompleted,
    this.status = 'pending',
    this.scheduledAt,
    this.validFrom,
    this.validUntil,
    this.graceMinutes,
    this.retryCount,
    this.maxRetries,
    this.retryIntervalMinutes,
    this.lastReminderAt,
    this.acknowledgedAt,
    this.startedAt,
    this.skippedAt,
    this.skipReason,
    this.skipReasons,
    this.skipDecisionBy,
    this.caregiverSkipNote,
    this.snoozedUntil,
    this.completedAt,
    this.completedBy,
    this.priority,
    this.riskLevel,
    this.recurrenceRule,
    this.caregiverNotified,
    this.escalateOnMiss,
    this.caregiverSkipNotified,
    this.escalateOnSkip,
    this.requireSkipConfirmation,
    this.allowPreScheduleSkip,
    this.notifyCaregiverOnSkip,
    this.skipLimitWindowDays,
    this.skipLimitCount,
    this.skipCount,
    this.skipCountWindow,
    this.skipReviewRequired,
    this.lastSkipDecisionBy,
    this.pendingReminderInvalidatedAt,
    this.reminderVersion,
    this.createdAt,
    this.updatedAt,
  });

  factory ScheduleTask.fromJson(Map<String, dynamic> json) {
    final completed = json['isCompleted'] ?? json['completed'] ?? false;

    return ScheduleTask(
      taskId: json['taskId'] ?? json['id'] ?? '',
      taskNumber: json['taskNumber'] ?? 0,
      taskName: json['taskName'] ?? json['task_name'] ?? '',
      time: json['Time'] ?? json['time'] ?? '',
      type: json['Type'] ?? json['type'] ?? 'common',
      isCompleted: completed,
      status: json['status'] ?? (completed == true ? 'completed_confirmed' : 'scheduled'),
      scheduledAt: json['scheduledAt'],
      validFrom: json['validFrom'],
      validUntil: json['validUntil'],
      graceMinutes: json['graceMinutes'],
      retryCount: json['retryCount'],
      maxRetries: json['maxRetries'],
      retryIntervalMinutes: json['retryIntervalMinutes'],
      lastReminderAt: json['lastReminderAt'],
      acknowledgedAt: json['acknowledgedAt'],
      startedAt: json['startedAt'],
      skippedAt: json['skippedAt'],
      skipReason: json['skipReason'],
      skipReasons: (json['skipReasons'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      skipDecisionBy: json['skipDecisionBy'] as String?,
      caregiverSkipNote: json['caregiverSkipNote'] as String?,
      snoozedUntil: json['snoozedUntil'],
      completedAt: json['completedAt'],
      completedBy: json['completedBy'],
      priority: json['priority'],
      riskLevel: json['riskLevel'],
      recurrenceRule: json['recurrenceRule'],
      caregiverNotified: json['caregiverNotified'],
      escalateOnMiss: json['escalateOnMiss'],
      caregiverSkipNotified: json['caregiverSkipNotified'],
      escalateOnSkip: json['escalateOnSkip'],
      requireSkipConfirmation: json['requireSkipConfirmation'],
      allowPreScheduleSkip: json['allowPreScheduleSkip'] as bool?,
      notifyCaregiverOnSkip: json['notifyCaregiverOnSkip'] as bool?,
      skipLimitWindowDays: json['skipLimitWindowDays'] as int?,
      skipLimitCount: json['skipLimitCount'] as int?,
      skipCount: json['skipCount'] as int?,
      skipCountWindow: json['skipCountWindow'] as int?,
      skipReviewRequired: json['skipReviewRequired'] as bool?,
      lastSkipDecisionBy: json['lastSkipDecisionBy'] as String?,
      pendingReminderInvalidatedAt: json['pendingReminderInvalidatedAt'] as String?,
      reminderVersion: json['reminderVersion'] as int?,
      createdAt: json['createdAt'] as String?,
      updatedAt: json['updatedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': taskId,
      'taskNumber': taskNumber,
      'task_name': taskName,
      'time': time,
      'type': type,
      'completed': isCompleted,
      'status': status,
      'scheduledAt': scheduledAt,
      'validFrom': validFrom,
      'validUntil': validUntil,
      'graceMinutes': graceMinutes,
      'retryCount': retryCount,
      'maxRetries': maxRetries,
      'retryIntervalMinutes': retryIntervalMinutes,
      'lastReminderAt': lastReminderAt,
      'acknowledgedAt': acknowledgedAt,
      'startedAt': startedAt,
      'skippedAt': skippedAt,
      'skipReason': skipReason,
      'skipReasons': skipReasons,
      'skipDecisionBy': skipDecisionBy,
      'caregiverSkipNote': caregiverSkipNote,
      'snoozedUntil': snoozedUntil,
      'completedAt': completedAt,
      'completedBy': completedBy,
      'priority': priority,
      'riskLevel': riskLevel,
      'recurrenceRule': recurrenceRule,
      'caregiverNotified': caregiverNotified,
      'escalateOnMiss': escalateOnMiss,
      'caregiverSkipNotified': caregiverSkipNotified,
      'escalateOnSkip': escalateOnSkip,
      'requireSkipConfirmation': requireSkipConfirmation,
      'allowPreScheduleSkip': allowPreScheduleSkip,
      'notifyCaregiverOnSkip': notifyCaregiverOnSkip,
      'skipLimitWindowDays': skipLimitWindowDays,
      'skipLimitCount': skipLimitCount,
      'skipCount': skipCount,
      'skipCountWindow': skipCountWindow,
      'skipReviewRequired': skipReviewRequired,
      'lastSkipDecisionBy': lastSkipDecisionBy,
      'pendingReminderInvalidatedAt': pendingReminderInvalidatedAt,
      'reminderVersion': reminderVersion,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  bool get isActiveLike => const [
        'scheduled',
        'upcoming',
        'reminder_triggered',
        // 'acknowledged',
        'snoozed',
        'in_progress',
      ].contains(status);

  bool get isFinishedLike => const [
        'completed_confirmed',
        'completed_likely',
        'skipped',
        'missed_likely',
        'missed_confirmed',
        'needs_caregiver_review',
        'escalated',
      ].contains(status);

  bool get needsCaregiverReview =>
      status == 'needs_caregiver_review' || skipReviewRequired == true;
}