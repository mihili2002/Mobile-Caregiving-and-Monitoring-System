import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/risk_history_point.dart';
import '../../services/risk_history_api.dart';
import '../../auth/auth_service.dart';
import '../../auth/login_page.dart';

// Plan screen
import 'personalized_plan_screen.dart';

class RiskHistoryChartScreen extends StatefulWidget {
  final String residentId;
  final String elderEmail; // ⭐ NEW
  final int days;

  const RiskHistoryChartScreen({
    super.key,
    required this.residentId,
    required this.elderEmail, // ⭐ NEW
    this.days = 30,
  });

  @override
  State<RiskHistoryChartScreen> createState() => _RiskHistoryChartScreenState();
}

class _RiskHistoryChartScreenState extends State<RiskHistoryChartScreen> {
  bool _loading = true;
  String? _error;
  List<RiskHistoryPoint> _points = [];

  String _metric = "Depression";

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final points = await RiskHistoryApi.fetchHistory(
        residentId: widget.residentId,
        days: widget.days,
      );

      setState(() {
        _points = points;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  double _valueFor(RiskHistoryPoint p) {
    switch (_metric) {
      case "Anxiety":
        return p.anxProb;
      case "Insomnia":
        return p.insProb;
      case "Emotional":
        return p.emoProb;
      case "Depression":
      default:
        return p.depProb;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      body: SafeArea(
        child: Column(
          children: [
            // ---------------- HEADER ----------------
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(10, 18, 12, 18),
              decoration: const BoxDecoration(
                color: Color(0xFF11BFA8),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "ElderCare",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Risk Trend (${widget.days} days)",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                  ),
                  IconButton(
                    tooltip: "Logout",
                    onPressed: () async {
                      await AuthService().signOut();
                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout, color: Colors.white),
                  ),
                ],
              ),
            ),

            // ---------------- BODY ----------------
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          )
                        : _points.isEmpty
                            ? const Center(
                                child: Text(
                                  "No history data yet. Submit more assessments.",
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text("Metric: "),
                                      const SizedBox(width: 10),
                                      DropdownButton<String>(
                                        value: _metric,
                                        items: const [
                                          DropdownMenuItem(
                                            value: "Depression",
                                            child: Text("Depression"),
                                          ),
                                          DropdownMenuItem(
                                            value: "Anxiety",
                                            child: Text("Anxiety"),
                                          ),
                                          DropdownMenuItem(
                                            value: "Insomnia",
                                            child: Text("Insomnia"),
                                          ),
                                          DropdownMenuItem(
                                            value: "Emotional",
                                            child: Text("Emotional Wellbeing"),
                                          ),
                                        ],
                                        onChanged: (v) =>
                                            setState(() => _metric = v ?? _metric),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: LineChart(
                                      LineChartData(
                                        minY: 0,
                                        maxY: 1,
                                        gridData: const FlGridData(show: true),
                                        borderData: FlBorderData(show: true),
                                        titlesData: FlTitlesData(
                                          rightTitles: const AxisTitles(
                                            sideTitles:
                                                SideTitles(showTitles: false),
                                          ),
                                          topTitles: const AxisTitles(
                                            sideTitles:
                                                SideTitles(showTitles: false),
                                          ),
                                          leftTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              reservedSize: 40,
                                              getTitlesWidget: (value, meta) =>
                                                  Text(value.toStringAsFixed(1)),
                                            ),
                                          ),
                                          bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              interval: (_points.length / 4)
                                                  .clamp(1, 999)
                                                  .toDouble(),
                                              getTitlesWidget: (value, meta) {
                                                final idx = value.toInt();

                                                if (idx < 0 ||
                                                    idx >= _points.length) {
                                                  return const SizedBox.shrink();
                                                }

                                                final d = _points[idx].createdAt;

                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(top: 6),
                                                  child: Text(
                                                    "${d.month}/${d.day}",
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        lineBarsData: [
                                          LineChartBarData(
                                            isCurved: true,
                                            barWidth: 3,
                                            dotData:
                                                const FlDotData(show: true),
                                            spots:
                                                List.generate(_points.length, (i) {
                                              final v = _valueFor(_points[i]);
                                              return FlSpot(i.toDouble(), v);
                                            }),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "Points: ${_points.length} (newest: ${_points.last.createdAt.toLocal()})",
                                    style: TextStyle(
                                      color: Colors.black.withOpacity(0.6),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    PersonalizedPlanScreen(
                                                  residentId: widget.residentId,
                                                  elderEmail: widget.elderEmail,
                                                  mode: PlanMode.viewOnly,
                                                ),
                                              ),
                                            );
                                          },
                                          icon:
                                              const Icon(Icons.article_outlined),
                                          label: const Text("View Plan"),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    PersonalizedPlanScreen(
                                                  residentId: widget.residentId,
                                                  elderEmail: widget.elderEmail,
                                                  mode: PlanMode.generateEditable,
                                                ),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.auto_fix_high),
                                          label: const Text("Generate Plan"),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}