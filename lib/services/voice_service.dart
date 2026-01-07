import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInit = false;

  Future<void> init() async {
    if (_isInit) return;
    
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.4); // Slower for elders
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(0.9); // Slightly deeper/calmer
    
    _isInit = true;
  }

  Future<void> speak(String text) async {
    if (!_isInit) await init();
    try {
      await _flutterTts.stop(); // Stop any previous speech
      await _flutterTts.speak(text);
    } catch (e) {
      print("TTS Error: $e");
    }
  }

  Future<void> speakReminder(String taskName, {String? elderName}) async {
    String preamble = "Excuse me";
    if (elderName != null && elderName.isNotEmpty) {
      preamble += " $elderName";
    }
    
    String message = "$preamble, it is time for your $taskName.";
    await speak(message);
  }
  
  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
