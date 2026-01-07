import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_tts/flutter_tts.dart';

class DigitalClockWidget extends StatefulWidget {
  const DigitalClockWidget({super.key});

  @override
  State<DigitalClockWidget> createState() => _DigitalClockWidgetState();
}

class _DigitalClockWidgetState extends State<DigitalClockWidget> with SingleTickerProviderStateMixin {
  late Timer _timer;
  DateTime _now = DateTime.now();
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  
  // Animation for blinking colon
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _startTimer();
    _controller = AnimationController(vsync: this, duration: Duration(seconds: 1))..repeat(reverse: true);
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _speakTime() async {
    setState(() => _isSpeaking = true);
    String timeStr = DateFormat('h:mm a').format(_now);
    await _flutterTts.speak("It is $timeStr");
    await _flutterTts.awaitSpeakCompletion(true);
    if (mounted) setState(() => _isSpeaking = false);
  }

  @override
  Widget build(BuildContext context) {
    final String hours = DateFormat('hh').format(_now);
    final String minutes = DateFormat('mm').format(_now);
    final String seconds = DateFormat('ss').format(_now);
    final String amPm = DateFormat('a').format(_now);

    return GestureDetector(
      onTap: _speakTime,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _isSpeaking ? Colors.teal.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: _isSpeaking ? Border.all(color: Colors.teal, width: 2) : null,
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  hours,
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                FadeTransition(
                  opacity: _controller,
                  child: const Text(':', style: TextStyle(fontSize: 64, color: Colors.teal)),
                ),
                Text(
                  minutes,
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  children: [
                    Text(
                      seconds,
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        amPm,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.volume_up, size: 20, color: Colors.teal.shade300),
                const SizedBox(width: 8),
                Text(
                  "Tap to hear time",
                  style: TextStyle(color: Colors.teal.shade300),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
