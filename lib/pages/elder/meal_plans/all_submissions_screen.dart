import 'package:flutter/material.dart';

import '../../../services/meal_plan_service.dart';
import '../../../models/all_submission_model.dart';
import '../../../PatientHealthDetailsScreen.dart';

class AllSubmissionsScreen extends StatefulWidget {
  const AllSubmissionsScreen({super.key});

  @override
  State<AllSubmissionsScreen> createState() => _AllSubmissionsScreenState();
}

class _AllSubmissionsScreenState extends State<AllSubmissionsScreen> {
  final MealPlanService _service = MealPlanService();

  bool _loading = true;
  String? _error;
  List<AllSubmissionModel> _submissions = [];

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
  }

  Future<void> _loadSubmissions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await _service.getAllSubmissions();
      if (!mounted) return;

      setState(() {
        _submissions = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Meal Plan Submissions"),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSubmissions,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Text(
              "Error loading submissions\n$_error",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      );
    }

    if (_submissions.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(
            child: Text(
              "No submissions found.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _submissions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final submission = _submissions[index];

        //THIS IS THE KEY CHANGE
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PatientHealthDetailsScreen(
                  submissionId: submission.id,
                  status: submission.status,
                ),
              ),
            );
          },
          child: _submissionCard(submission),
        );
      },
    );
  }

  // --------------------------------------------------
  // Submission Card UI
  // --------------------------------------------------
  Widget _submissionCard(AllSubmissionModel submission) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // LEFT SIDE → label + value in one row
                Row(
                  children: [
                    Text(
                      "Submitted at ",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 35),
                    Text(
                      _formatDate(submission.submittedAt),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),

                // RIGHT SIDE → status
                _statusChip(submission.status),
              ],
            ),

            // const SizedBox(height: 4),

            // Text(
            //   submission.id,
            //   style: const TextStyle(
            //     fontWeight: FontWeight.w600,
            //     fontSize: 13,
            //   ),
            // ),
            //
            // const SizedBox(height: 12),

            // _infoRow(
            //   label: "Submitted at",
            //   value: _formatDate(submission.submittedAt),
            // ),

            if (submission.reviewedAt != null)
              _infoRow(
                label: "Reviewed at",
                value: _formatDate(submission.reviewedAt!),
              ),

            if (submission.reviewedBy != null)
              _infoRow(
                label: "Reviewed by",
                value: submission.reviewedBy!,
              ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // Helpers
  // --------------------------------------------------
  Widget _infoRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color bg;
    Color fg;

    switch (status.toLowerCase()) {
      case "approved":
        bg = Colors.green.shade100;
        fg = Colors.green.shade800;
        break;
      case "rejected":
        bg = Colors.red.shade100;
        fg = Colors.red.shade800;
        break;
      case "pending":
      default:
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return "${date.year}-${_two(date.month)}-${_two(date.day)} "
        "${_two(date.hour)}:${_two(date.minute)}";
  }

  String _two(int v) => v.toString().padLeft(2, "0");
}
