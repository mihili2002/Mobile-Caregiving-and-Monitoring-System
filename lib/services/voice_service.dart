import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'user_service.dart';

class VoiceService {
  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isTtsInit = false;
  bool _isSpeechInit = false;
  bool _isListening = false;

  Future<void> init() async {
    await initTts();
    await initSpeech();
  }

  Future<void> initTts() async {
    if (_isTtsInit) return;

    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.4);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(0.9);
    await _flutterTts.awaitSpeakCompletion(true);

    _isTtsInit = true;
  }

  Future<bool> initSpeech() async {
    if (_isSpeechInit) return true;

    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          debugPrint("VoiceService STT status: $status");
          if (status == "done" || status == "notListening") {
            _isListening = false;
          }
        },
        onError: (errorNotification) {
          debugPrint("VoiceService STT error: $errorNotification");
          _isListening = false;
        },
      );

      _isSpeechInit = available;
      return available;
    } catch (e) {
      debugPrint("VoiceService.initSpeech error: $e");
      _isSpeechInit = false;
      return false;
    }
  }

  bool get isListening => _isListening;

  void setCompletionHandler(Function handler) {
    _flutterTts.setCompletionHandler(() => handler());
  }

  Future<String?> getAudioUrl(String text, {String category = "common"}) async {
    final baseUrl = UserService().baseUrl;
    final encodedText = Uri.encodeComponent(text);
    return "$baseUrl/api/audio/generate?text=$encodedText&category=$category";
  }

  Future<void> speak(String text, {String category = 'common'}) async {
    if (!_isTtsInit) await initTts();

    try {
      await stopListening();
      await _flutterTts.stop();

      // Apply different voice patterns according to task category
      double targetPitch = 0.9;
      double targetRate = 0.4;
      
      switch (category.toLowerCase()) {
        case 'health':
        case 'medication':
          targetPitch = 1.1; 
          targetRate = 0.42;
          break;
        case 'meal':
        case 'meals':
          targetPitch = 0.9; 
          targetRate = 0.4;
          break;
        case 'social':
          targetPitch = 1.2; 
          targetRate = 0.48;
          break;
        case 'leisure':
        case 'therapy':
          targetPitch = 0.85; 
          targetRate = 0.35;
          break;
        case 'urgent':
          targetPitch = 0.95; 
          targetRate = 0.55; 
          break;
        case 'common':
        default:
          targetPitch = 0.9; 
          targetRate = 0.4;
          break;
      }

      await _flutterTts.setPitch(targetPitch);
      await _flutterTts.setSpeechRate(targetRate);
      
      debugPrint("🔊 FlutterTTS: Speaking as '$category' [Pitch: $targetPitch, Rate: $targetRate]");
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("TTS Error: $e");
    }
  }

  Future<void> speakReminder(String taskName, {String? elderName, String category = 'common'}) async {
    String preamble = "Excuse me";
    if (elderName != null && elderName.isNotEmpty) {
      preamble += " $elderName";
    }

    final message = "$preamble, it is time for your $taskName.";
    await speak(message, category: category);
  }

  /// Listen once and return the recognized text.
  /// This is ideal for your "Later" mini-conversation.
  Future<String?> listenOnce({
    Duration listenFor = const Duration(seconds: 8),
    Duration pauseFor = const Duration(seconds: 3),
    String localeId = "en_US",
  }) async {
    final ready = await initSpeech();
    if (!ready) {
      debugPrint("VoiceService.listenOnce: speech recognition unavailable");
      return null;
    }

    final completer = Completer<String?>();
    String lastWords = "";

    try {
      await _flutterTts.stop();

      _isListening = true;

      await _speech.listen(
        localeId: localeId,
        listenFor: listenFor,
        pauseFor: pauseFor,
        partialResults: true,
        cancelOnError: true,
        onResult: (result) {
          lastWords = result.recognizedWords.trim();

          if (result.finalResult && !completer.isCompleted) {
            _isListening = false;
            completer.complete(lastWords.isEmpty ? null : lastWords);
          }
        },
      );

      // Fallback timeout in case finalResult never arrives cleanly
      Future.delayed(listenFor + const Duration(seconds: 2), () async {
        if (!completer.isCompleted) {
          await stopListening();
          completer.complete(lastWords.isEmpty ? null : lastWords);
        }
      });

      return await completer.future;
    } catch (e) {
      debugPrint("VoiceService.listenOnce error: $e");
      _isListening = false;
      return null;
    }
  }

  Future<void> stopListening() async {
    if (!_isSpeechInit) return;
    try {
      if (_speech.isListening) {
        await _speech.stop();
      }
    } catch (e) {
      debugPrint("VoiceService.stopListening error: $e");
    } finally {
      _isListening = false;
    }
  }

  Future<void> stop() async {
    try {
      await stopListening();
      await _flutterTts.stop();
    } catch (e) {
      debugPrint("VoiceService.stop error: $e");
    }
  }
}