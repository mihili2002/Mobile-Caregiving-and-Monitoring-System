import 'package:cloud_firestore/cloud_firestore.dart';

class CaregiverNotification {
  final String id;
  final String type;
  final String elderUid;
  final String taskId;
  final String taskName;
  final String taskType;
  final String reason;
  final String status;
  final String date;
  final DateTime createdAt;
  final bool needsReview;
  final DateTime? reviewedAt;

  CaregiverNotification({
    required this.id,
    required this.type,
    required this.elderUid,
    required this.taskId,
    required this.taskName,
    required this.taskType,
    required this.reason,
    required this.status,
    required this.date,
    required this.createdAt,
    required this.needsReview,
    this.reviewedAt,
  });

  factory CaregiverNotification.fromMap(Map<String, dynamic> map, String id) {
    return CaregiverNotification(
      id: id,
      type: map['type'] ?? 'unknown',
      elderUid: map['elderUid'] ?? '',
      taskId: map['taskId'] ?? '',
      taskName: map['taskName'] ?? 'Task',
      taskType: map['taskType'] ?? 'common',
      reason: map['reason'] ?? 'None',
      status: map['status'] ?? 'skipped',
      date: map['date'] ?? '',
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
      needsReview: map['needsReview'] ?? false,
      reviewedAt: map['reviewedAt'] != null 
          ? DateTime.parse(map['reviewedAt']) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'elderUid': elderUid,
      'taskId': taskId,
      'taskName': taskName,
      'taskType': taskType,
      'reason': reason,
      'status': status,
      'date': date,
      'createdAt': createdAt.toIso8601String(),
      'needsReview': needsReview,
      'reviewedAt': reviewedAt?.toIso8601String(),
    };
  }
}
