import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import './api.dart';

class AllEmotionsScreen extends StatefulWidget {
  final String baseUrl;
  final int days;
  const AllEmotionsScreen({
    super.key,
    required this.baseUrl,
    this.days = 7,
  });

  @override
  State<AllEmotionsScreen> createState() => _AllEmotionsScreenState();
}

class _AllEmotionsScreenState extends State<AllEmotionsScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  late TabController _tab;

  bool _hasLoaded = false;

  // GREEN THEME
  static const _green900 = Color(0xFF00A693);
  static const _green700 = Color(0xFF00A693);
  static const _green200 = Color(0xFFA7DCCB);
  static const _mint = Color(0xFFF2FBF7);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOnce());
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadOnce() async {
    if (_hasLoaded) return;
    _hasLoaded = true;
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = Api(widget.baseUrl);

      final data = await api.getJson(
        "/chatbot/emotions?days=${widget.days}&limit=500",
      );

      final raw = (data["items"] ?? []) as List<dynamic>;
      final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      list.sort((a, b) {
        final ta = _parseTime(a);
        final tb = _parseTime(b);
        return ta.compareTo(tb);
      });

      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = "Error: $e";
        _loading = false;
      });
    }
  }

  // ---------- Helpers ----------
  String _safe(dynamic v) => v == null ? "" : v.toString();

  DateTime _parseTime(Map<String, dynamic> it) {
    final iso = it["createdAtIso"];
    if (iso != null && iso.toString().isNotEmpty) {
      return DateTime.tryParse(iso.toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    final dt = _safe(it["displayTime"]);
    if (dt.length >= 19) {
      final s = dt.substring(0, 19).replaceFirst(' ', 'T') + 'Z';
      return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _dayKey(DateTime t) =>
      "${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}";

  Color _emotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case "joy":
      case "happy":
        return Colors.green.shade400;
      case "sad":
      case "sadness":
        return Colors.blue.shade400;
      case "anger":
      case "angry":
        return Colors.red.shade400;
      case "fear":
      case "anxiety":
        return Colors.deepPurple.shade400;
      case "surprise":
        return Colors.orange.shade400;
      case "disgust":
        return Colors.brown.shade400;
      case "neutral":
        return Colors.grey.shade500;
      default:
        return Colors.grey.shade400;
    }
  }

  int _emotionScore(String emotion) {
    switch (emotion.toLowerCase()) {
      case "joy":
      case "happy":
        return 3;
      case "surprise":
        return 2;
      case "neutral":
        return 0;
      case "sad":
      case "sadness":
      case "fear":
      case "anxiety":
      case "disgust":
        return -2;
      case "anger":
      case "angry":
        return -3;
      default:
        return 0;
    }
  }

  Map<String, int> _emotionCounts() {
    final Map<String, int> c = {};
    for (final it in _items) {
      final e = _safe(it["emotion"]).toLowerCase();
      if (e.isEmpty) continue;
      c[e] = (c[e] ?? 0) + 1;
    }
    return c;
  }

  Map<String, Map<String, int>> _countsByDay() {
    final out = <String, Map<String, int>>{};
    for (final it in _items) {
      final e = _safe(it["emotion"]).toLowerCase();
      if (e.isEmpty) continue;
      final t = _parseTime(it);
      final day = _dayKey(t);
      out.putIfAbsent(day, () => <String, int>{});
      out[day]![e] = (out[day]![e] ?? 0) + 1;
    }
    return out;
  }

  List<String> _sortedEmotions(Set<String> emotions) {
    const preferred = [
      "joy",
      "happy",
      "neutral",
      "surprise",
      "sadness",
      "sad",
      "fear",
      "anxiety",
      "anger",
      "disgust"
    ];
    final list = emotions.toList();
    list.sort((a, b) {
      final ia = preferred.indexOf(a);
      final ib = preferred.indexOf(b);
      if (ia == -1 && ib == -1) return a.compareTo(b);
      if (ia == -1) return 1;
      if (ib == -1) return -1;
      return ia.compareTo(ib);
    });
    return list;
  }

  // ---------- Charts ----------
  Widget _barChart() {
    final counts = _emotionCounts();
    if (counts.isEmpty) return const Center(child: Text("No emotions found"));

    final emotions = _sortedEmotions(counts.keys.toSet());

    final maxCount = counts.values.fold<int>(0, (m, v) => v > m ? v : m);
    final maxY = (maxCount + 1).toDouble();
    final double interval = (maxCount <= 6) ? 1 : (maxCount <= 20) ? 2 : 5;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _green200),
        ),
        child: SizedBox(
          height: 260,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              minY: 0,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: interval,
              ),
              borderData: FlBorderData(show: false),
              alignment: BarChartAlignment.spaceAround,
              groupsSpace: 12,
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: interval,
                    reservedSize: 42,
                    getTitlesWidget: (value, meta) {
                      if (value % interval != 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= emotions.length) {
                        return const SizedBox.shrink();
                      }
                      final label = emotions[i];
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 8,
                        child: Transform.rotate(
                          angle: label.length > 7 ? -0.35 : 0,
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barGroups: List.generate(emotions.length, (i) {
                final e = emotions[i];
                final v = (counts[e] ?? 0).toDouble();
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: v,
                      width: 18,
                      borderRadius: BorderRadius.circular(6),
                      color: _emotionColor(e),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lineChart() {
    if (_items.isEmpty) return const Center(child: Text("No emotions found"));

    final spots = <FlSpot>[];
    for (int i = 0; i < _items.length; i++) {
      final e = _safe(_items[i]["emotion"]);
      spots.add(FlSpot(i.toDouble(), _emotionScore(e).toDouble()));
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _green200),
        ),
        child: SizedBox(
          height: 260,
          child: LineChart(
            LineChartData(
              minY: -3,
              maxY: 3,
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      String label = value.toInt().toString();
                      if (value == 3) label = "Joy";
                      if (value == 0) label = "Neutral";
                      if (value == -3) label = "Anger";
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(label,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700)),
                      );
                    },
                  ),
                ),
                bottomTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  dotData: const FlDotData(show: true),
                  barWidth: 3,
                  color: _green700,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _heatmapGrid() {
    final byDay = _countsByDay();
    if (byDay.isEmpty) return const Center(child: Text("No emotions found"));

    final days = byDay.keys.toList()..sort();
    final allEmotions = <String>{};
    for (final m in byDay.values) {
      allEmotions.addAll(m.keys);
    }
    final emotions = _sortedEmotions(allEmotions);

    int maxCount = 1;
    for (final m in byDay.values) {
      for (final v in m.values) {
        if (v > maxCount) maxCount = v;
      }
    }

    Color cellColor(String emotion, int count) {
      final base = _emotionColor(emotion);
      final t = (count / maxCount).clamp(0.0, 1.0);
      return Color.lerp(Colors.white, base, 0.2 + 0.8 * t)!;
    }

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _green200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Heatmap (day × emotion)",
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 70),
                      ...emotions.map((e) => SizedBox(
                            width: 90,
                            child: Text(e,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                          )),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...days.map((d) {
                    final label = d.length >= 10 ? d.substring(5) : d;
                    final counts = byDay[d]!;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 70,
                            child: Text(label,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: _green700)),
                          ),
                          ...emotions.map((e) {
                            final c = counts[e] ?? 0;
                            return Container(
                              width: 90,
                              height: 28,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: cellColor(e, c),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _green200),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                c == 0 ? "" : "$c",
                                style:
                                    const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _listView() {
    if (_items.isEmpty) return const Center(child: Text("No emotions found"));

    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: _items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final it = _items[i];
        final emotion = _safe(it["emotion"]);
        final text = _safe(it["text"]);
        final time = _safe(it["displayTime"] ?? it["createdAtIso"]);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _green200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Chip(
                label: Text(
                  emotion.isEmpty ? "unknown" : emotion,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.white),
                ),
                backgroundColor: _emotionColor(emotion),
              ),
              const SizedBox(height: 6),
              Text(
                time,
                style: TextStyle(
                    color: _green900.withOpacity(0.75),
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(text,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, height: 1.35)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _mint,
      appBar: AppBar(
        backgroundColor: _green900,
        title: Text("All Emotions (last ${widget.days} days)"),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: () {
              _hasLoaded = false;
              _loadOnce();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "Bar"),
            Tab(text: "Trend"),
            Tab(text: "Per-day"),
            Tab(text: "List"),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_error != null)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!),
                  ),
                )
              : TabBarView(
                  controller: _tab,
                  children: [
                    _barChart(),
                    _lineChart(),
                    _heatmapGrid(),
                    _listView(),
                  ],
                ),
    );
  }
}
