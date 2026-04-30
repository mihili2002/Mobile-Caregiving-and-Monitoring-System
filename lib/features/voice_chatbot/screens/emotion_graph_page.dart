import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class EmotionGraphPage extends StatefulWidget {
  final String elderId;
  final String apiBaseUrl;

  const EmotionGraphPage({
    super.key,
    required this.elderId,
    required this.apiBaseUrl,
  });

  @override
  State<EmotionGraphPage> createState() => _EmotionGraphPageState();
}

class _EmotionGraphPageState extends State<EmotionGraphPage> {
  bool _loading = true;
  String? _error;
  List<_EmotionPoint> _points = [];
  int _days = 7;

  bool _showPercentages = false;
  Map<String, double> _emotionPercentages = {};

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
      final token = await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (token == null) {
        throw Exception('Not logged in');
      }

      final uri = Uri.parse(
        '${widget.apiBaseUrl}/chatbot/journals/emotion-trend'
        '?elder_uid=${Uri.encodeComponent(widget.elderId)}'
        '&days=$_days',
      );

      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Server error ${res.statusCode}: ${res.body}');
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? []);

      final parsed = items.map((e) {
        final m = e as Map<String, dynamic>;
        final ts = DateTime.parse(m['created_at']).toLocal();

        final emotion = _normalizeEmotionKey((m['emotion'] ?? '').toString());

        final confidence = (m['confidence'] is num)
            ? (m['confidence'] as num).toDouble()
            : null;

        return _EmotionPoint(
          createdAt: ts,
          emotionKey: emotion,
          emotionLabel: _emotionLabel(emotion),
          confidence: confidence,
          score: _emotionScore(emotion),
        );
      }).toList();

      parsed.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final aggregated = _aggregateByDay(parsed);

      setState(() {
        _points = aggregated;
        _calculateEmotionPercentages();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _calculateEmotionPercentages() {
    if (_points.isEmpty) {
      _emotionPercentages = {};
      return;
    }

    final counts = <String, int>{
      'happy': 0,
      'calm': 0,
      'angry': 0,
      'sad': 0,
    };

    for (final p in _points) {
      counts[p.emotionKey] = (counts[p.emotionKey] ?? 0) + 1;
    }

    final total = _points.length;

    _emotionPercentages =
        counts.map((k, v) => MapEntry(k, (v / total) * 100));
  }

  String _normalizeEmotionKey(String emotion) {
    final key = emotion.trim().toUpperCase();

    if (key == 'Q1' || key.contains('HAPPY')) return 'happy';
    if (key == 'Q4' || key.contains('CALM')) return 'calm';
    if (key == 'Q2' || key.contains('ANGRY') || key.contains('FEAR'))
      return 'angry';
    if (key == 'Q3' || key.contains('SAD')) return 'sad';

    return 'calm';
  }

  double _emotionScore(String key) {
    switch (key) {
      case 'sad':
        return 0;
      case 'angry':
        return 1;
      case 'calm':
        return 2;
      case 'happy':
        return 3;
      default:
        return 2;
    }
  }

  String _emotionLabel(String key) {
    switch (key) {
      case 'sad':
        return 'Sad / Depressed';
      case 'angry':
        return 'Angry / Fearful';
      case 'calm':
        return 'Calm / Relaxed';
      case 'happy':
        return 'Happy / Excited';
      default:
        return 'Calm / Relaxed';
    }
  }

  List<_EmotionPoint> _aggregateByDay(List<_EmotionPoint> raw) {
    if (raw.isEmpty) return [];

    final grouped = <String, List<_EmotionPoint>>{};

    for (final p in raw) {
      final d = p.createdAt;
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(p);
    }

    final keys = grouped.keys.toList()..sort();

    final result = <_EmotionPoint>[];

    for (final k in keys) {
      final items = grouped[k]!;

      final counts = <String, int>{};
      for (final i in items) {
        counts[i.emotionKey] = (counts[i.emotionKey] ?? 0) + 1;
      }

      String dominant = items.first.emotionKey;
      int max = 0;

      counts.forEach((emotion, c) {
        if (c > max) {
          max = c;
          dominant = emotion;
        }
      });

      final d = items.first.createdAt;

      result.add(
        _EmotionPoint(
          createdAt: DateTime(d.year, d.month, d.day),
          emotionKey: dominant,
          emotionLabel: _emotionLabel(dominant),
          score: _emotionScore(dominant),
        ),
      );
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Emotion Fluctuations')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Text('Range:'),
                const SizedBox(width: 10),
                DropdownButton<int>(
                  value: _days,
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('7 Days')),
                    DropdownMenuItem(value: 30, child: Text('30 Days')),
                    DropdownMenuItem(value: 90, child: Text('90 Days')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _days = v);
                    _load();
                  },
                ),
                const Spacer(),
                ElevatedButton(
  onPressed: () {
    setState(() {
      _showPercentages = !_showPercentages;
    });
  },
  child: Text(
    _showPercentages ? "Show Graph" : "Percentages",
  ),
),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _load,
                )
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _points.isEmpty
                          ? const Center(child: Text("No data found"))
                          : _showPercentages
                              ? _EmotionPercentageView(
                                  percentages: _emotionPercentages)
                              : _EmotionLineChart(
                                  points: _points,
                                  primary: primary,
                                ),
            )
          ],
        ),
      ),
    );
  }
}

class _EmotionLineChart extends StatelessWidget {
  final List<_EmotionPoint> points;
  final Color primary;

  const _EmotionLineChart({
    required this.points,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (int i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].score)
    ];

    return LineChart(
      LineChartData(
        minY: -0.2,
        maxY: 3.2,
        titlesData: FlTitlesData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: primary,
            barWidth: 3,
            dotData: FlDotData(show: true),
          )
        ],
      ),
    );
  }
}

class _EmotionPercentageView extends StatelessWidget {
  final Map<String, double> percentages;

  const _EmotionPercentageView({required this.percentages});

  String label(String key) {
    switch (key) {
      case 'happy':
        return 'Happy / Excited';
      case 'calm':
        return 'Calm / Relaxed';
      case 'angry':
        return 'Angry / Fearful';
      case 'sad':
        return 'Sad / Depressed';
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = percentages.entries.toList();

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final key = items[i].key;
        final value = items[i].value;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("${label(key)} (${value.toStringAsFixed(1)}%)"),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: value / 100)
            ],
          ),
        );
      },
    );
  }
}

class _EmotionPoint {
  final DateTime createdAt;
  final String emotionKey;
  final String emotionLabel;
  final double? confidence;
  final double score;

  _EmotionPoint({
    required this.createdAt,
    required this.emotionKey,
    required this.emotionLabel,
    required this.score,
    this.confidence,
  });
}