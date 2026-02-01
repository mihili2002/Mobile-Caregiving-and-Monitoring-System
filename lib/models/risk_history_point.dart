class RiskHistoryPoint {
  final DateTime createdAt;
  final double depProb;
  final double anxProb;
  final double insProb;
  final double emoProb;

  RiskHistoryPoint({
    required this.createdAt,
    required this.depProb,
    required this.anxProb,
    required this.insProb,
    required this.emoProb,
  });

  static double _toDouble(dynamic v) {
    if (v == null) return double.nan;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? double.nan;
  }

  factory RiskHistoryPoint.fromJson(Map<String, dynamic> json) {
    // backend returns createdAt like "2026-01-04 11:38:43.840000+00:00"
    // DateTime.parse can handle ISO strings. If it ever fails, adjust backend to return ISO.
    final createdAt = DateTime.parse(json['createdAt']);

    return RiskHistoryPoint(
      createdAt: createdAt,
      depProb: _toDouble(json['depProb']),
      anxProb: _toDouble(json['anxProb']),
      insProb: _toDouble(json['insProb']),
      emoProb: _toDouble(json['emoProb']),
    );
  }

  bool get hasValidNumbers =>
      depProb.isFinite && anxProb.isFinite && insProb.isFinite && emoProb.isFinite;
}