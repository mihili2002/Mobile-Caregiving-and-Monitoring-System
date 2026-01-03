class AllSubmissionModel {
  final String id;
  final DateTime submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String status;

  AllSubmissionModel({
    required this.id,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    required this.status,
  });

  factory AllSubmissionModel.fromJson(Map<String, dynamic> json) {
    return AllSubmissionModel(
      id: json["id"],
      submittedAt: DateTime.parse(json["submitted_at"]),
      reviewedAt: json["reviewed_at"] != null
          ? DateTime.parse(json["reviewed_at"])
          : null,
      reviewedBy: json["reviewed_by"],
      status: json["status"],
    );
  }
}
