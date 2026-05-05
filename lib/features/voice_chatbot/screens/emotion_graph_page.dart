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

  Map<String, Map<String, double>> _dailyEmotionPercentages = {};

  List<Map<String, dynamic>> _rawItems = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  // =========================
  // COLOR SYSTEM FOR EMOTIONS
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

      case "surprise":
        return Colors.orange;

      case "calm":
      case "neutral":
        return Colors.teal;

      case "disgust":
        return Colors.brown;

      default:
        return Colors.grey;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken(true);
      if (token == null) throw Exception('Not logged in');

      final uri = Uri.parse(
        '${widget.apiBaseUrl}/chatbot/journals/emotion-trend'
        '?elder_uid=${Uri.encodeComponent(widget.elderId)}'
        '&days=$_days',
      );

      print('📡 API URL: $uri');
      
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      print('📡 Response status: ${res.statusCode}');
      print('📡 Response body: ${res.body}');

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('Server error ${res.statusCode}: ${res.body}');
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>? ?? []);

      _rawItems = items.map((e) => e as Map<String, dynamic>).toList();

      final parsed = <_EmotionPoint>[];

      for (var item in items) {
        final m = item as Map<String, dynamic>;

        final rawEmotion = m['emotion']?.toString() ?? 'null';
        final journalId = m['journal_id']?.toString() ?? 'unknown';

        DateTime ts;
        try {
          ts = DateTime.parse(m['created_at']).toLocal();
        } catch (_) {
          continue;
        }

        final normalized = _normalizeEmotionKey(rawEmotion);

        parsed.add(_EmotionPoint(
          createdAt: ts,
          emotionKey: normalized,
          emotionLabel: _getEmotionLabel(normalized),
          score: _emotionScore(normalized),
          rawEmotion: rawEmotion,
          journalId: journalId,
        ));
      }

      parsed.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      print('📊 Loaded ${parsed.length} emotion points');
      for (var p in parsed) {
        print('   ${p.createdAt}: ${p.emotionKey} (score: ${p.score})');
      }

      setState(() {
        _points = parsed;
        _calculateDailyPercentages();
        _loading = false;
      });
    } catch (e) {
      print('❌ Error: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _calculateDailyPercentages() {
    final Map<String, Map<String, int>> dailyCounts = {};

    for (final p in _points) {
      final dateKey =
          "${p.createdAt.year}-${p.createdAt.month.toString().padLeft(2, '0')}-${p.createdAt.day.toString().padLeft(2, '0')}";

      dailyCounts.putIfAbsent(dateKey, () => {});
      dailyCounts[dateKey]![p.emotionKey] =
          (dailyCounts[dateKey]![p.emotionKey] ?? 0) + 1;
    }

    final Map<String, Map<String, double>> result = {};

    dailyCounts.forEach((date, emotions) {
      final total = emotions.values.fold(0, (a, b) => a + b);

      result[date] = emotions.map((emotion, count) {
        return MapEntry(emotion, (count / total) * 100);
      });
    });

    _dailyEmotionPercentages = result;
  }

  String _normalizeEmotionKey(String emotion) {
    final key = emotion.trim().toLowerCase();

    if (key.contains('happy') || key == 'q1') return 'happy';
    if (key.contains('angry') || key == 'q2') return 'angry';
    if (key.contains('sad') || key == 'q3') return 'sad';
    if (key.contains('calm') || key == 'q4') return 'calm';
    if (key.contains('fear')) return 'fear';
    if (key.contains('surprise')) return 'surprise';
    if (key.contains('disgust')) return 'disgust';

    return 'neutral';
  }

  double _emotionScore(String key) {
    switch (key) {
      case 'sad':
        return 0;
      case 'angry':
        return 1;
      case 'fear':
        return 1.5;
      case 'neutral':
        return 2;
      case 'calm':
        return 2.5;
      case 'surprise':
        return 3;
      case 'happy':
        return 4;
      default:
        return 2;
    }
  }

  String _getEmotionLabel(String key) {
    switch (key) {
      case 'sad':
        return 'Sad 😔';
      case 'angry':
        return 'Angry 😠';
      case 'fear':
        return 'Fear 😨';
      case 'neutral':
        return 'Neutral 😐';
      case 'calm':
        return 'Calm 😌';
      case 'surprise':
        return 'Surprise 😲';
      case 'disgust':
        return 'Disgust 🤢';
      case 'happy':
        return 'Happy 😊';
      default:
        return key;
    }
  }

  String _getEmotionEmoji(String key) {
    switch (key) {
      case 'sad':
        return '😔';
      case 'angry':
        return '😠';
      case 'fear':
        return '😨';
      case 'neutral':
        return '😐';
      case 'calm':
        return '😌';
      case 'surprise':
        return '😲';
      case 'disgust':
        return '🤢';
      case 'happy':
        return '😊';
      default:
        return '😐';
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emotion Fluctuations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
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
                  child: Text(_showPercentages ? "Show Graph" : "Percentages"),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(child: Text(_error!))
                      : _points.isEmpty
                          ? const Center(
                              child: Text(
                                "No data found for the selected date range.\nTry recording voice journals with emotions.",
                                textAlign: TextAlign.center,
                              ),
                            )
                          : _showPercentages
                              ? _DailyEmotionView(
                                  data: _dailyEmotionPercentages,
                                  colorFn: _emotionColor,
                                )
                              : _EmotionLineChart(
                                  points: _points,
                                  primary: primary,
                                  colorFn: _emotionColor,
                                  emojiFn: _getEmotionEmoji,
                                  labelFn: _getEmotionLabel,
                                ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================
// 📊 DAILY PERCENTAGE VIEW
// =========================
class _DailyEmotionView extends StatelessWidget {
  final Map<String, Map<String, double>> data;
  final Color Function(String) colorFn;

  const _DailyEmotionView({
    required this.data,
    required this.colorFn,
  });

  @override
  Widget build(BuildContext context) {
    final dates = data.keys.toList()..sort();

    if (dates.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    return ListView.builder(
      itemCount: dates.length,
      itemBuilder: (context, index) {
        final date = dates[index];
        final emotions = data[date]!;
        
        // Sort emotions by percentage (highest first)
        final sortedEmotions = emotions.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(
              "📅 $date",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text("${emotions.length} emotion${emotions.length > 1 ? 's' : ''}"),
            children: sortedEmotions.map((e) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: colorFn(e.key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.key.toUpperCase(),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorFn(e.key).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${e.value.toStringAsFixed(1)}%",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: colorFn(e.key),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

// =========================
// 📈 LINE CHART WITH DATE AXIS (FIXED)
// =========================
class _EmotionLineChart extends StatelessWidget {
  final List<_EmotionPoint> points;
  final Color primary;
  final Color Function(String) colorFn;
  final String Function(String) emojiFn;
  final String Function(String) labelFn;

  const _EmotionLineChart({
    required this.points,
    required this.primary,
    required this.colorFn,
    required this.emojiFn,
    required this.labelFn,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Center(child: Text('No data to display'));
    }

    final spots = List.generate(
      points.length,
      (i) => FlSpot(i.toDouble(), points[i].score),
    );

    // Calculate optimal interval for X-axis labels based on data points count
    int getXAxisInterval(int totalPoints) {
      if (totalPoints <= 7) return 1;
      if (totalPoints <= 14) return 2;
      if (totalPoints <= 21) return 3;
      if (totalPoints <= 30) return 4;
      return 5;
    }

    final xInterval = getXAxisInterval(points.length);

    return LineChart(
      LineChartData(
        minY: -0.5,
        maxY: 4.5,
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          drawVerticalLine: true,
          horizontalInterval: 0.5,
          verticalInterval: points.length > 10 ? (points.length / 10) : 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.3),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.3),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          // LEFT TITLES (Emotion labels on Y-axis)
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 70,
              interval: 0.5,
              getTitlesWidget: (value, meta) {
                String getEmotionText(double score) {
                  if (score == 0) return 'Sad';
                  if (score == 1) return 'Angry';
                  if (score == 1.5) return 'Fear';
                  if (score == 2) return 'Neutral';
                  if (score == 2.5) return 'Calm';
                  if (score == 3) return 'Surprise';
                  if (score == 4) return 'Happy';
                  return '';
                }
                
                String getEmotionEmoji(double score) {
                  if (score == 0) return '😔';
                  if (score == 1) return '😠';
                  if (score == 1.5) return '😨';
                  if (score == 2) return '😐';
                  if (score == 2.5) return '😌';
                  if (score == 3) return '😲';
                  if (score == 4) return '😊';
                  return '😐';
                }

                final text = getEmotionText(value);
                if (text.isEmpty) return const Text('');
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    '$text ${getEmotionEmoji(value)}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                );
              },
            ),
          ),
          // BOTTOM TITLES (Dates on X-axis)
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              interval: xInterval.toDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) return const Text('');
                
                // Only show labels at the specified interval
                if (index % xInterval != 0 && index != points.length - 1) {
                  return const Text('');
                }
                
                final date = points[index].createdAt;
                final day = date.day.toString().padLeft(2, '0');
                final month = date.month.toString().padLeft(2, '0');
                final hour = date.hour.toString().padLeft(2, '0');
                final minute = date.minute.toString().padLeft(2, '0');
                
                // If it's the same day as previous, show only time
                String displayText;
                if (index > 0 && points[index - 1].createdAt.day == date.day) {
                  displayText = '$hour:$minute';
                } else {
                  displayText = '$day/$month\n$hour:$minute';
                }
                
                return Transform.rotate(
                  angle: -0.3,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      displayText,
                      style: const TextStyle(fontSize: 9),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: primary,
            isCurved: true,
            curveSmoothness: 0.3,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final emotion = points[index.toInt()].emotionKey;
                return FlDotCirclePainter(
                  radius: 6,
                  color: colorFn(emotion),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: primary.withOpacity(0.1),
            ),
            aboveBarData: BarAreaData(show: false),
          ),
        ],
        // Touch tooltips for better interaction (FIXED)
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((touchedSpot) {
                final index = touchedSpot.x.toInt();
                if (index >= points.length) return null;
                
                final point = points[index];
                final date = point.createdAt;
                final formattedDate = '${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
                
                return LineTooltipItem(
                  '${point.emotionLabel}\n$formattedDate\nScore: ${point.score.toStringAsFixed(1)}',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList();
            },
            tooltipRoundedRadius: 8,
            tooltipMargin: 8,
          ),
          handleBuiltInTouches: true,
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
        ),
        clipData: const FlClipData.all(),
      ),
    );
  }
}

// =========================
// MODEL CLASS
// =========================
class _EmotionPoint {
  final DateTime createdAt;
  final String emotionKey;
  final String emotionLabel;
  final double score;
  final String rawEmotion;
  final String journalId;

  _EmotionPoint({
    required this.createdAt,
    required this.emotionKey,
    required this.emotionLabel,
    required this.score,
    required this.rawEmotion,
    required this.journalId,
  });
}