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

  static const _green900 = Color(0xFF00A693);
  static const _mint = Color(0xFFF2FBF7);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
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

  // =========================
  // ✅ ONLY CHANGE IS HERE
  // =========================
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

      // ✅ NEW ADDED COLOR
      case "surprise":
        return Colors.orange;

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

  List<String> _sortedEmotions(Set<String> emotions) {
    final list = emotions.toList()..sort();
    return list;
  }

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
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  axisNameWidget: const Text(
                    "Count / %",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  sideTitles: SideTitles(showTitles: true),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: const Text(
                    "Emotions",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() >= emotions.length) {
                        return const SizedBox();
                      }
                      return Text(
                        emotions[value.toInt()],
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
              ),
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

  Widget _percentagePerDayChart() {
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

        final Map<String, int> counts = {};
        for (final it in items) {
          final e = _safe(it["emotion"]).toLowerCase();
          if (e.isEmpty) continue;
          counts[e] = (counts[e] ?? 0) + 1;
        }

        final total = counts.values.fold<int>(0, (a, b) => a + b);

        final Map<String, double> percentages = {};
        counts.forEach((k, v) {
          percentages[k] = (v / total) * 100;
        });

        return Card(
          margin: const EdgeInsets.all(10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(day,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Column(
                  children: percentages.entries.map((entry) {
                    final emotion = entry.key;
                    final percent = entry.value;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(width: 80, child: Text(emotion)),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: percent / 100,
                              color: _emotionColor(emotion),
                              backgroundColor: Colors.grey.shade300,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text("${percent.toStringAsFixed(1)}%"),
                        ],
                      ),
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

  Widget _listView() {
    if (_items.isEmpty) {
      return const Center(child: Text("No emotion data"));
    }

    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final it = _items[i];
        final emotion = _safe(it["emotion"]);
        final text = _safe(it["text"]);
        final time = _parseTime(it);

        final formattedDate =
            "${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} "
            "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _emotionColor(emotion), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 60,
                decoration: BoxDecoration(
                  color: _emotionColor(emotion),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      emotion.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _emotionColor(emotion),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (text.isNotEmpty) Text(text),
                    const SizedBox(height: 6),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
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
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "Bar"),
            Tab(text: "Percentage"),
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
                    _percentagePerDayChart(),
                    _listView(),
                  ],
                ),
    );
  }
}