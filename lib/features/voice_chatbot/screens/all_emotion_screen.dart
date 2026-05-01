import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import './api.dart';

class AllEmotionsScreen extends StatefulWidget {
  final String baseUrl;
  final String? elderUid;
  final int days;

  const AllEmotionsScreen({
    super.key,
    required this.baseUrl,
    this.elderUid,
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

  bool _showPercentage = false;

  Map<String, double> _percentages = {};

  static const _green900 = Color(0xFF00A693);
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
      final uid = widget.elderUid?.trim() ?? "";

      final String url = uid.isNotEmpty
          ? "/chatbot/emotions?elder_uid=${Uri.encodeComponent(uid)}&days=${widget.days}&limit=500"
          : "/chatbot/emotions?days=${widget.days}&limit=500";

      final data = await api.getJson(url);

      final raw = (data["items"] ?? []) as List<dynamic>;
      final list =
          raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      list.sort((a, b) => _parseTime(a).compareTo(_parseTime(b)));

      setState(() {
        _items = list;
        _calculatePercentages();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = "Error: $e";
        _loading = false;
      });
    }
  }

  String _safe(dynamic v) => v == null ? "" : v.toString();

  DateTime _parseTime(Map<String, dynamic> it) {
    final iso = it["createdAtIso"];
    if (iso != null && iso.toString().isNotEmpty) {
      return DateTime.tryParse(iso.toString()) ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Color _emotionColor(String emotion) {
    switch (emotion.toLowerCase()) {
      case "joy":
      case "happy":
        return Colors.green;
      case "sad":
      case "sadness":
        return Colors.blue;
      case "anger":
      case "angry":
        return Colors.red;
      case "fear":
        return Colors.purple;
      default:
        return Colors.grey;
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

  void _calculatePercentages() {
    final Map<String, int> counts = _emotionCounts();

    final total = counts.values.fold<int>(0, (a, b) => a + b);

    if (total == 0) {
      _percentages = {};
      return;
    }

    _percentages = counts.map(
      (k, v) => MapEntry(k, (v / total) * 100),
    );
  }

  List<String> _sortedEmotions(Set<String> emotions) {
    final list = emotions.toList()..sort();
    return list;
  }

  // =========================
  // GROUP BY DATE
  // =========================

  Map<String, List<Map<String, dynamic>>> _groupByDay() {
    final Map<String, List<Map<String, dynamic>>> result = {};

    for (final item in _items) {
      final time = _parseTime(item);

      final day =
          "${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}";

      result.putIfAbsent(day, () => []);

      result[day]!.add(item);
    }

    return result;
  }

  // =========================
  // BAR CHART
  // =========================

  Widget _barChart() {
    final counts = _emotionCounts();

    if (counts.isEmpty) {
      return const Center(child: Text("No emotions found"));
    }

    final emotions = _sortedEmotions(counts.keys.toSet());
    final total = counts.values.fold<int>(0, (a, b) => a + b);

    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _showPercentage = !_showPercentage;
            });
          },
          icon: const Icon(Icons.percent),
          label: Text(_showPercentage ? "Show Count" : "Show %"),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: BarChart(
            BarChartData(
              maxY: _showPercentage ? 100 : null,
              barGroups: List.generate(emotions.length, (i) {
                final e = emotions[i];
                final count = counts[e] ?? 0;

                final value =
                    _showPercentage ? (count / total) * 100 : count.toDouble();

                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: value,
                      width: 18,
                      color: _emotionColor(e),
                    )
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  // =========================
  // PER DAY VIEW
  // =========================

  Widget _perDayChart() {
    final grouped = _groupByDay();

    if (grouped.isEmpty) {
      return const Center(child: Text("No emotion data"));
    }

    final days = grouped.keys.toList()..sort();

    return ListView.builder(
      itemCount: days.length,
      itemBuilder: (_, i) {
        final day = days[i];
        final items = grouped[day]!;

        return Card(
          margin: const EdgeInsets.all(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: items.map((it) {
                    final emotion = _safe(it["emotion"]);

                    return Chip(
                      label: Text(
                        emotion,
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: _emotionColor(emotion),
                    );
                  }).toList(),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================
  // LIST VIEW
  // =========================

  Widget _listView() {
    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final it = _items[i];
        final time = _parseTime(it);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _emotionColor(_safe(it["emotion"])),
          ),
          title: Text(_safe(it["emotion"])),
          subtitle: Text(_safe(it["text"])),
          trailing: Text(
              "${time.year}-${time.month}-${time.day} ${time.hour}:${time.minute}"),
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
        title: const Text("Emotion Analytics"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _hasLoaded = false;
              _loadOnce();
            },
          )
        ],
        bottom: TabBar(
          controller: _tab,
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
          : _error != null
              ? Center(child: Text(_error!))
              : TabBarView(
                  controller: _tab,
                  children: [
                    _barChart(),
                    const Center(child: Text("Trend Chart Coming Soon")),
                    _perDayChart(),
                    _listView(),
                  ],
                ),
    );
  }
}