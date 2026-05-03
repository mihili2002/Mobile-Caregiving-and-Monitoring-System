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
  
  // Debug info
  List<Map<String, dynamic>> _rawItems = [];

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
      
      // Store raw items for debugging
      _rawItems = items.map((e) => e as Map<String, dynamic>).toList();

      final parsed = <_EmotionPoint>[];
      
      for (var item in items) {
        final m = item as Map<String, dynamic>;
        
        // Get raw emotion value from API
        final rawEmotion = m['emotion']?.toString() ?? 'null';
        final journalId = m['journal_id']?.toString() ?? 'unknown';
        final createdAt = m['created_at']?.toString() ?? 'unknown';
        
        print('📊 Journal: $journalId');
        print('   Created: $createdAt');
        print('   Raw emotion from API: "$rawEmotion"');
        
        // Parse date
        DateTime? ts;
        try {
          ts = DateTime.parse(m['created_at']).toLocal();
        } catch (e) {
          print('   ⚠️ Failed to parse date: ${m['created_at']}');
          continue;
        }
        
        // Normalize emotion
        final normalizedEmotion = _normalizeEmotionKey(rawEmotion);
        print('   Normalized emotion: "$normalizedEmotion"');
        print('   Score: ${_emotionScore(normalizedEmotion)}');
        print('---');
        
        parsed.add(_EmotionPoint(
          createdAt: ts,
          emotionKey: normalizedEmotion,
          emotionLabel: _emotionLabel(normalizedEmotion),
          score: _emotionScore(normalizedEmotion),
          rawEmotion: rawEmotion,
          journalId: journalId,
        ));
      }

      parsed.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Count emotions for debugging
      final emotionCounts = <String, int>{};
      for (var p in parsed) {
        emotionCounts[p.emotionKey] = (emotionCounts[p.emotionKey] ?? 0) + 1;
      }
      print('📊 Emotion counts: $emotionCounts');
      print('📊 Total points: ${parsed.length}');

      setState(() {
        _points = parsed;
        _calculateEmotionPercentages();
        _loading = false;
      });
      
      // Show snackbar with summary
      if (mounted && parsed.isNotEmpty) {
        final summary = emotionCounts.entries.map((e) => '${e.key}: ${e.value}').join(', ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded ${parsed.length} entries: $summary')),
        );
      }
      
    } catch (e) {
      print('❌ Error: $e');
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

 String _normalizeEmotionKey(String emotion) {
  if (emotion.isEmpty || emotion == 'null') return 'neutral';

  // 🔥 IMPORTANT: handle Q1–Q4 FIRST
  final key = emotion.trim().toUpperCase();

  if (key == 'Q1') return 'happy';   
  if (key == 'Q2') return 'angry';   
  if (key == 'Q3') return 'sad';   
  if (key == 'Q4') return 'calm';    

  // 🔁 fallback for text-based emotions
  final lower = key.toLowerCase();

  if (lower.contains('happy') || lower.contains('joy')) return 'happy';
  if (lower.contains('angry') || lower.contains('anger')) return 'angry';
  if (lower.contains('fear')) return 'fear';
  if (lower.contains('sad')) return 'sad';
  if (lower.contains('calm') || lower.contains('neutral')) return 'calm';
  if (lower.contains('surprise')) return 'surprise';
  if (lower.contains('disgust')) return 'disgust';

  print('⚠️ Unknown emotion: "$emotion" -> defaulting to neutral');
  return 'neutral';
}

  double _emotionScore(String key) {
    switch (key) {
      case 'sad': return 0.0;
      case 'angry': return 1.0;
      case 'fear': return 1.5;
      case 'neutral': return 2.0;
      case 'calm': return 2.5;
      case 'surprise': return 3.0;
      case 'disgust': return 1.2;
      case 'happy': return 4.0;
      default: return 2.0;
    }
  }

  String _emotionLabel(String key) {
    switch (key) {
      case 'sad': return 'Sad 😔';
      case 'angry': return 'Angry 😠';
      case 'fear': return 'Fear 😨';
      case 'neutral': return 'Neutral 😐';
      case 'calm': return 'Calm 😌';
      case 'surprise': return 'Surprise 😲';
      case 'disgust': return 'Disgust 🤢';
      case 'happy': return 'Happy 😊';
      default: return key;
    }
  }

  void _calculateEmotionPercentages() {
    final counts = <String, int>{};
    for (final p in _points) {
      counts[p.emotionKey] = (counts[p.emotionKey] ?? 0) + 1;
    }
    final total = _points.length;
    if (total > 0) {
      _emotionPercentages = counts.map((k, v) => MapEntry(k, (v / total) * 100));
    } else {
      _emotionPercentages = {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emotion Fluctuations'),
        actions: [
          // Debug button
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _showDebugDialog,
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
                          ? const Center(child: Text("No data found.\nTry recording voice journals with emotions."))
                          : _showPercentages
                              ? _EmotionPercentageView(percentages: _emotionPercentages)
                              : _EmotionLineChart(points: _points, primary: primary),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showDebugDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Info'),
        content: Container(
          width: double.maxFinite,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total entries: ${_rawItems.length}'),
              const SizedBox(height: 8),
              const Text('Raw API response:'),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    JsonEncoder.withIndent('  ').convert(_rawItems),
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
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
    if (points.isEmpty) {
      return const Center(child: Text('No data to display'));
    }
    
    final spots = List.generate(points.length, (i) => FlSpot(i.toDouble(), points[i].score));
    
    // Create custom dot colors based on emotion
    final List<FlDotData> dotDataList = [];
    
    return LineChart(
      LineChartData(
        minY: -0.5,
        maxY: 4.5,
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const Text('Sad', style: TextStyle(fontSize: 11));
                if (value == 1) return const Text('Angry', style: TextStyle(fontSize: 11));
                if (value == 1.5) return const Text('Fear', style: TextStyle(fontSize: 11));
                if (value == 2) return const Text('Neutral', style: TextStyle(fontSize: 11));
                if (value == 2.5) return const Text('Calm', style: TextStyle(fontSize: 11));
                if (value == 3) return const Text('Surprise', style: TextStyle(fontSize: 11));
                if (value == 4) return const Text('Happy', style: TextStyle(fontSize: 11));
                return const Text('');
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) return const Text('');
                final date = points[index].createdAt;
                return Transform.rotate(
                  angle: -0.5,
                  child: Text(
                    '${date.day}/${date.month}',
                    style: const TextStyle(fontSize: 9),
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            color: primary,
            isCurved: true,
            barWidth: 2,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}

class _EmotionPercentageView extends StatelessWidget {
  final Map<String, double> percentages;

  const _EmotionPercentageView({required this.percentages});

  @override
  Widget build(BuildContext context) {
    final items = percentages.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    
    if (items.isEmpty) {
      return const Center(child: Text('No percentage data available'));
    }
    
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final key = items[i].key;
        final value = items[i].value;
        
        Color getColor(String emotion) {
          switch (emotion) {
            case 'happy': return Colors.green;
            case 'sad': return Colors.blue;
            case 'angry': return Colors.red;
            case 'fear': return Colors.deepPurple;
            case 'calm': return Colors.teal;
            case 'surprise': return Colors.orange;
            case 'disgust': return Colors.brown;
            default: return Colors.grey;
          }
        }
        
        String getEmoji(String emotion) {
          switch (emotion) {
            case 'happy': return '😊';
            case 'sad': return '😔';
            case 'angry': return '😠';
            case 'fear': return '😨';
            case 'calm': return '😌';
            case 'surprise': return '😲';
            case 'disgust': return '🤢';
            default: return '😐';
          }
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: getColor(key),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${getEmoji(key)} ${key.toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    const Spacer(),
                    Text(
                      '${value.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: value / 100,
                  backgroundColor: Colors.grey.shade200,
                  color: getColor(key),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
              ],
            ),
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