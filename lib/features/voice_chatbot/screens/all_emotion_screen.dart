import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

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

  // Brown theme
  static const _brown900 = Color(0xFF3E2723);
  static const _brown700 = Color(0xFF5D4037);
  static const _brown200 = Color(0xFFD7CCC8);
  static const _cream = Color(0xFFF7F3EF);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final url = Uri.parse(
        "${widget.baseUrl}/chatbot/emotions?days=${widget.days}&limit=500",
      );
      final res = await http.get(url);

      if (res.statusCode != 200) {
        setState(() {
          _error = "Server error: ${res.statusCode}";
          _loading = false;
        });
        return;
      }

      final data = jsonDecode(res.body);
      final raw = (data["items"] ?? []) as List<dynamic>;
      final list = raw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // Sort by time ascending for timeline views
      list.sort((a, b) {
        final ta = _parseTime(a);
        final tb = _parseTime(b);
        return ta.compareTo(tb);
      });

      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Error: $e";
        _loading = false;
      });
    }
  }

  // ---------- Helpers ----------
  String _safe(dynamic v) => v == null ? "" : v.toString();

  DateTime _parseTime(Map<String, dynamic> it) {
    // Prefer createdAtIso if present, else parse displayTime fallback
    final iso = it["createdAtIso"];
    if (iso != null && iso.toString().isNotEmpty) {
      return DateTime.tryParse(iso.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    final dt = _safe(it["displayTime"]);
    // displayTime format: "YYYY-MM-DD HH:mm:ss UTC"
    // We'll parse simply: take first 19 chars and treat as UTC
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
    // Numeric mapping for timeline (adjust as you like)
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
        return -2;
      case "fear":
      case "anxiety":
        return -2;
      case "anger":
      case "angry":
        return -3;
      case "disgust":
        return -2;
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
    // day -> (emotion -> count)
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
    // stable order (custom)
    const preferred = ["joy", "happy", "neutral", "surprise", "sadness", "sad", "fear", "anxiety", "anger", "disgust"];
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
    final maxY = (counts.values.fold<int>(0, (m, v) => v > m ? v : m) + 1).toDouble();

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _brown200),
        ),
        child: SizedBox(
          height: 240,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              gridData: const FlGridData(show: true),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= emotions.length) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          emotions[i],
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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

    // x = index, y = emotion score
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
          border: Border.all(color: _brown200),
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
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      // label mood scale
                      String label = value.toInt().toString();
                      if (value == 3) label = "Joy";
                      if (value == 0) label = "Neutral";
                      if (value == -3) label = "Anger";
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      );
                    },
                  ),
                ),
                bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  dotData: const FlDotData(show: true),
                  barWidth: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stackedByDay() {
    final byDay = _countsByDay();
    if (byDay.isEmpty) return const Center(child: Text("No emotions found"));

    final days = byDay.keys.toList()..sort();
    final allEmotions = <String>{};
    for (final m in byDay.values) {
      allEmotions.addAll(m.keys);
    }
    final emotions = _sortedEmotions(allEmotions);

    // Build stacked bars: each day is a bar group with multiple rods
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _brown200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Emotions per day", style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            SizedBox(
              height: 260,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final i = value.toInt();
                          if (i < 0 || i >= days.length) return const SizedBox.shrink();
                          // show MM-DD
                          final d = days[i];
                          final label = d.length >= 10 ? d.substring(5) : d;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(days.length, (i) {
                    final day = days[i];
                    final counts = byDay[day]!;
                    double running = 0;
                    final stacks = <BarChartRodStackItem>[];

                    for (final e in emotions) {
                      final v = (counts[e] ?? 0).toDouble();
                      if (v <= 0) continue;
                      final from = running;
                      running += v;
                      stacks.add(BarChartRodStackItem(from, running, _emotionColor(e)));
                    }

                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: running == 0 ? 0 : running,
                          width: 18,
                          rodStackItems: stacks,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: emotions.map((e) {
                return Chip(
                  label: Text(e, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  backgroundColor: _emotionColor(e),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heatmapGrid() {
    // Optional: heatmap-like grid (day x emotion intensity)
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
          border: Border.all(color: _brown200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Heatmap (day × emotion)", style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // header row
                  Row(
                    children: [
                      const SizedBox(width: 70),
                      ...emotions.map((e) => SizedBox(
                            width: 90,
                            child: Text(e, style: const TextStyle(fontWeight: FontWeight.w700)),
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
                            child: Text(label, style: TextStyle(color: _brown700, fontWeight: FontWeight.w700)),
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
                                border: Border.all(color: _brown200),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                c == 0 ? "" : "$c",
                                style: const TextStyle(fontWeight: FontWeight.w800),
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
            border: Border.all(color: _brown200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Chip(
                label: Text(
                  emotion.isEmpty ? "unknown" : emotion,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                ),
                backgroundColor: _emotionColor(emotion),
              ),
              const SizedBox(height: 6),
              Text(
                time,
                style: TextStyle(color: _brown700.withOpacity(0.75), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Text(text, style: const TextStyle(fontWeight: FontWeight.w600, height: 1.35)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _brown900,
        title: Text("All Emotions (last ${widget.days} days)"),
        actions: [
          IconButton(
            tooltip: "Refresh",
            onPressed: _load,
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
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)))
              : TabBarView(
                  controller: _tab,
                  children: [
                    _barChart(),      // 1) frequency
                    _lineChart(),     // 2) timeline
                    // Choose ONE of these as #3:
                    // _stackedByDay(), // 3) stacked bars per day
                    _heatmapGrid(),   // 3) heatmap-like grid per day
                    _listView(),      // original list
                  ],
                ),
    );
  }
}
