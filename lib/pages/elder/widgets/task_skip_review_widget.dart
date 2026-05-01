import 'package:flutter/material.dart';

class TaskSkipReviewWidget extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback? onCaregiverSkip;
  final bool isCaregiverMode;

  const TaskSkipReviewWidget({
    super.key,
    required this.task,
    this.onCaregiverSkip,
    this.isCaregiverMode = true,
  });

  bool get _skipReviewRequired => task['skipReviewRequired'] == true;
  bool get _caregiverSkipNotified => task['caregiverSkipNotified'] == true;

  String get _skipReason {
    final display = (task['skipReasonDisplay'] ?? '').toString().trim();
    if (display.isNotEmpty) return display;

    final reasons = task['skipReasons'] as List<dynamic>?;
    if (reasons != null && reasons.isNotEmpty) {
      return reasons.map((e) => e.toString().replaceAll('_', ' ')).join(', ');
    }

    final r = task['skipReason']?.toString() ?? '';
    return r.isEmpty ? '—' : r.replaceAll('_', ' ');
  }

  String get _lastSkipDecisionBy {
    final display = (task['skipDecisionByDisplay'] ?? '').toString().trim();
    if (display.isNotEmpty) return display;

    final d =
        (task['skipDecisionBy'] ?? task['lastSkipDecisionBy'])?.toString() ?? '';
    return d.isEmpty ? '—' : d;
  }

  String get _skippedAt {
    final display = (task['skippedAtDisplay'] ?? '').toString().trim();
    if (display.isNotEmpty) return display;

    final raw = task['skippedAt']?.toString() ?? '';
    if (raw.isEmpty) return '—';

    try {
      final dt = DateTime.parse(raw).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    } catch (_) {
      return raw;
    }
  }

  String get _caregiverSkipNote {
    return task['caregiverSkipNote']?.toString() ?? '';
  }

  bool get _isSkipped {
    final status = task['status']?.toString() ?? '';
    return status == 'skipped' ||
        status == 'needs_caregiver_review' ||
        status == 'escalated';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSkipped) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_skipReviewRequired)
          _buildBanner(
            icon: Icons.flag_rounded,
            color: Colors.deepOrange,
            message: 'This skipped medication needs caregiver review.',
          ),
        if (!isCaregiverMode && _caregiverSkipNotified)
          _buildBanner(
            icon: Icons.notifications_active,
            color: Colors.blue,
            message: 'Your caregiver has been notified.',
          ),
        if (_lastSkipDecisionBy.toLowerCase() == 'caregiver')
          _buildBanner(
            icon: Icons.manage_accounts,
            color: Colors.purple,
            message: 'Skipped by caregiver.',
          ),
        _buildSkipDetailCard(context),
      ],
    );
  }

  Widget _buildBanner({
    required IconData icon,
    required MaterialColor color,
    required String message,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkipDetailCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.skip_next_rounded, size: 18, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                'Skip Details',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              if (_caregiverSkipNotified)
                Tooltip(
                  message: 'Caregiver was notified',
                  child: Icon(
                    Icons.notifications_active_outlined,
                    size: 16,
                    color: Colors.orange.shade700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _detailRow(
            icon: Icons.comment_outlined,
            label: 'Reason',
            value: _skipReason,
          ),
          const SizedBox(height: 6),
          _detailRow(
            icon: Icons.person_outline,
            label: 'Decision by',
            value: _lastSkipDecisionBy,
          ),
          const SizedBox(height: 6),
          _detailRow(
            icon: Icons.access_time_outlined,
            label: 'Skipped at',
            value: _skippedAt,
          ),
          if (_caregiverSkipNote.isNotEmpty) ...[
            const SizedBox(height: 6),
            _detailRow(
              icon: Icons.note_outlined,
              label: 'Caregiver note',
              value: _caregiverSkipNote,
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12.5),
          ),
        ),
      ],
    );
  }
}
