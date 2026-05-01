import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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

  Future<void> speak(String text) async {
    if (!_isTtsInit) await initTts();

    try {
      await stopListening();
      await _flutterTts.stop();
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("TTS Error: $e");
    }
  }

  Future<void> speakReminder(String taskName, {String? elderName}) async {
    String preamble = "Excuse me";
    if (elderName != null && elderName.isNotEmpty) {
      preamble += " $elderName";
    }

    final message = "$preamble, it is time for your $taskName.";
    await speak(message);
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