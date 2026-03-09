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
        final ts = DateTime.parse(m['created_at'] as String).toLocal();
        final rawEmotion = (m['emotion'] ?? '').toString();
        final normalizedEmotion = _normalizeEmotionKey(rawEmotion);
        final confidence = (m['confidence'] is num)
            ? (m['confidence'] as num).toDouble()
            : null;

        return _EmotionPoint(
          createdAt: ts,
          emotionKey: normalizedEmotion,
          emotionLabel: _emotionLabel(normalizedEmotion),
          confidence: confidence,
          score: _emotionScore(normalizedEmotion),
        );
      }).toList();

      parsed.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      final aggregated = _aggregateByDay(parsed);

      setState(() {
        _points = aggregated;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _normalizeEmotionKey(String emotion) {
    final key = emotion.trim().toUpperCase();

    if (key == 'Q1' ||
        key.contains('HAPPY') ||
        key.contains('EXCITED') ||
        key.contains('POSITIVE')) {
      return 'happy';
    }

    if (key == 'Q4' ||
        key.contains('CALM') ||
        key.contains('RELAXED')) {
      return 'calm';
    }

    if (key == 'Q2' ||
        key.contains('ANGRY') ||
        key.contains('FEARFUL') ||
        key.contains('FEAR') ||
        key.contains('ANX')) {
      return 'angry';
    }

    if (key == 'Q3' ||
        key.contains('SAD') ||
        key.contains('DEPRESSED') ||
        key.contains('NEGATIVE')) {
      return 'sad';
    }

    return 'calm';
  }

  double _emotionScore(String emotionKey) {
    switch (emotionKey) {
      case 'sad':
        return 0.0;
      case 'angry':
        return 1.0;
      case 'calm':
        return 2.0;
      case 'happy':
        return 3.0;
      default:
        return 2.0;
    }
  }

  String _emotionLabel(String emotionKey) {
    switch (emotionKey) {
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

    for (final point in raw) {
      final d = point.createdAt;
      final key =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(point);
    }

    final keys = grouped.keys.toList()..sort();
    final result = <_EmotionPoint>[];

    for (final key in keys) {
      final items = grouped[key]!;

      final counts = <String, int>{};
      for (final item in items) {
        counts[item.emotionKey] = (counts[item.emotionKey] ?? 0) + 1;
      }

      String dominantEmotionKey = items.first.emotionKey;
      int maxCount = 0;

      counts.forEach((emotionKey, count) {
        if (count > maxCount) {
          maxCount = count;
          dominantEmotionKey = emotionKey;
        }
      });

      final avgConfidenceValues = items
          .where((e) => e.confidence != null)
          .map((e) => e.confidence!)
          .toList();

      final avgConfidence = avgConfidenceValues.isEmpty
          ? null
          : avgConfidenceValues.reduce((a, b) => a + b) /
              avgConfidenceValues.length;

      final date = DateTime(
        items.first.createdAt.year,
        items.first.createdAt.month,
        items.first.createdAt.day,
      );

      result.add(
        _EmotionPoint(
          createdAt: date,
          emotionKey: dominantEmotionKey,
          emotionLabel: _emotionLabel(dominantEmotionKey),
          confidence: avgConfidence,
          score: _emotionScore(dominantEmotionKey),
        ),
      );
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emotion Fluctuations'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('Range:'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _days,
                    items: const [
                      DropdownMenuItem(value: 7, child: Text('Last 7 days')),
                      DropdownMenuItem(value: 30, child: Text('Last 30 days')),
                      DropdownMenuItem(value: 90, child: Text('Last 90 days')),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _days = v);
                      _load();
                    },
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.black.withOpacity(0.08)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : _error != null
                          ? _ErrorView(message: _error!, onRetry: _load)
                          : _points.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No emotion data found for this range.',
                                  ),
                                )
                              : _EmotionLineChart(
                                  points: _points,
                                  primary: primary,
                                ),
                ),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Daily emotion score: Sad/Depressed = 0, Angry/Fearful = 1, Calm/Relaxed = 2, Happy/Excited = 3',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ],
          ),
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
    final spots = <FlSpot>[
      for (int i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i].score),
    ];

    final bottomInterval =
        points.length <= 7 ? 1.0 : (points.length / 5).ceilToDouble();

    return LineChart(
      LineChartData(
        minY: -0.2,
        maxY: 3.2,
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.25),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(
            color: Colors.grey.withOpacity(0.3),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Emotion',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 110,
              interval: 1,
              getTitlesWidget: (value, meta) {
                String label = '';
                if ((value - 0).abs() < 0.1) label = 'Sad / Depressed';
                if ((value - 1).abs() < 0.1) label = 'Angry / Fearful';
                if ((value - 2).abs() < 0.1) label = 'Calm / Relaxed';
                if ((value - 3).abs() < 0.1) label = 'Happy / Excited';

                if (label.isEmpty) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black87,
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Date',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: bottomInterval,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= points.length) {
                  return const SizedBox.shrink();
                }

                final dt = points[i].createdAt;
                final label = '${dt.month}/${dt.day}';

                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black54,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final i = spot.x.toInt();
                if (i < 0 || i >= points.length) return null;

                final p = points[i];
                final dt = p.createdAt;
                final date = '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';

                final confidenceText = p.confidence != null
                    ? '\nConfidence: ${(p.confidence! * 100).toStringAsFixed(0)}%'
                    : '';

                return LineTooltipItem(
                  '$date\nEmotion: ${p.emotionLabel}\nScore: ${p.score.toStringAsFixed(1)}$confidenceText',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList();
            },
          ),
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                FlLine(
                  color: primary.withOpacity(0.25),
                  strokeWidth: 1.5,
                ),
                FlDotData(
                  getDotPainter: (spot, percent, bar, i) {
                    return FlDotCirclePainter(
                      radius: 5,
                      color: primary,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
              );
            }).toList();
          },
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: primary,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: primary,
                  strokeWidth: 1.5,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }

  static String _two(int x) => x.toString().padLeft(2, '0');
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
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