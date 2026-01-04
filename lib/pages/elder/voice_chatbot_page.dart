import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../../models/user_model.dart';
import '../../services/voice_service.dart';
import '../../services/user_service.dart'; 

class VoiceChatbotPage extends StatefulWidget {
  final AppUser user;
  final String? initialPrompt;
  
  const VoiceChatbotPage({super.key, required this.user, this.initialPrompt});

  @override
  State<VoiceChatbotPage> createState() => _VoiceChatbotPageState();
}

class _VoiceChatbotPageState extends State<VoiceChatbotPage> {
  final TextEditingController _textController = TextEditingController();
  final VoiceService _voiceService = VoiceService();
  final stt.SpeechToText _speech = stt.SpeechToText();
  late String _sessionId;
  
  bool _isListening = false;
  bool _isSpeaking = false;
  String _statusText = "Hold to record your thoughts";
  String _liveWords = "";
  String _finalWords = "";

  // New structured state
  String _aiReply = "";
  bool _isConfirmation = false;
  Map<String, dynamic>? _taskPreview;

  @override
  void initState() {
    super.initState();
    _sessionId = const Uuid().v4();
    _initVoice();
    
    // Auto-prompt logic
    if (widget.initialPrompt != null) {
       Future.delayed(const Duration(milliseconds: 500), () async {
          await _voiceService.init(); // ensure init
          await _voiceService.speak(widget.initialPrompt!);
          if (mounted) _startListening();
       });
    }
  }
  
  void _initVoice() async {
    await _voiceService.init();

    bool available = await _speech.initialize(
      onStatus: (status) {
        print("STT Status: $status");
        if (!mounted) return;

        // Just update UI state, do NOT call stop here
        if (status == "notListening" || status == "done") {
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (error) {
        print("STT Error: $error");
        if (!mounted) return;
        setState(() {
          _isListening = false;
          _statusText = "Error: ${error.errorMsg}";
        });
      },
    );

    if (!available && mounted) {
      setState(() => _statusText = "Voice recognition not available");
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _speech.cancel();
    _voiceService.stop();
    super.dispose();
  }



  Future<void> _startListening() async {
    if (_isSpeaking) return; // don't listen while speaking

    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission needed')),
      );
      return;
    }

    if (!_speech.isAvailable) {
      await _speech.initialize();
    }

    setState(() {
      _isListening = true;
      _statusText = "Listening...";
      _liveWords = "";
      _finalWords = "";
      _textController.clear();
    });

    await _speech.listen(
      localeId: "en_US",
      cancelOnError: true,
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 10),
      partialResults: true,
      onResult: (val) {
        if (!mounted) return;

        setState(() {
          _liveWords = val.recognizedWords;
          _textController.text = _liveWords;

          if (val.finalResult) {
            _finalWords = val.recognizedWords;
          }
        });
      },
    );
  }

  Future<void> _stopListening() async {
    if (!_isListening) return; // prevents double call
    await _speech.stop();

    setState(() {
      _isListening = false;
      _statusText = "Processing...";
    });

    final capturedText = (_finalWords.trim().isNotEmpty)
        ? _finalWords.trim()
        : _liveWords.trim();

    print("Captured final: '$capturedText'");

    if (capturedText.isNotEmpty) {
      await _processVoiceCommand(capturedText);
    } else {
      setState(() => _statusText = "Hold to record your thoughts");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("I didn't hear anything. Please try again.")),
        );
      }
    }
  }

  Future<void> _processVoiceCommand(String text) async {
      try {
          setState(() {
            _isSpeaking = true;
          });
          await _speech.stop();
          
          final baseUrl = UserService.getApiUrl(context);
          final response = await http.post(
            Uri.parse('$baseUrl/api/ai/process_voice_command'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
                'uid': widget.user.uid,
                'text': text,
                'session_id': _sessionId
            })
          );
          
          if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              final reply = data['reply'] ?? "";
              final action = data['action'] ?? "reply";
              final isConfirmation = data['is_confirmation'] == true;
              final taskPreview = data['task'];

              if (mounted) {
                setState(() {
                  _aiReply = reply;
                  _isConfirmation = isConfirmation;
                  _taskPreview = taskPreview != null ? Map<String, dynamic>.from(taskPreview) : null;
                  _statusText = isConfirmation ? "Checking details..." : "Speaking...";
                });
              }

              _voiceService.setCompletionHandler(() async {
                  if (!mounted) return;
                  
                  setState(() {
                    _isSpeaking = false;
                    if (!_isConfirmation) {
                       _statusText = "Hold to record your thoughts";
                    }
                  });

                  if (action == 'close') {
                      await Future.delayed(const Duration(seconds: 2));
                      if (mounted) Navigator.pop(context);
                  } else {
                      _startListening();
                  }
              });

              // Construct spoken reply
              String spokenReply = reply;
              if (isConfirmation) {
                  spokenReply = "I heard you say: '$text'. $reply";
              }

              await _voiceService.speak(spokenReply);
              
               if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('AI: $reply'),
                    backgroundColor: Colors.blue,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
          } else {
            setState(() => _isSpeaking = false);
          }
      } catch (e) {
          print("Error processing voice: $e");
          setState(() => _isSpeaking = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
      }
      
      setState(() {
          _liveWords = "";
          _finalWords = "";
          _textController.clear();
      });
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Assistant', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             // Current Status / Last Reply
             // Transcript Box
             Container(
               margin: const EdgeInsets.symmetric(horizontal: 24),
               padding: const EdgeInsets.all(16),
               width: double.infinity,
               decoration: BoxDecoration(
                 color: Colors.grey.shade100,
                 borderRadius: BorderRadius.circular(12),
                 border: Border.all(color: Colors.grey.shade300),
               ),
               child: Text(
                 _liveWords.isEmpty ? "Your spoken text will appear here..." : _liveWords,
                 style: const TextStyle(fontSize: 18),
               ),
             ),
             
             const SizedBox(height: 12),
             Text(
               _statusText,
               textAlign: TextAlign.center,
               style: const TextStyle(fontSize: 16, color: Colors.blueGrey),
             ),
             
             const SizedBox(height: 20),

             // Task Preview Card (when confirmed)
             if (_taskPreview != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.event_note, color: Colors.teal),
                              SizedBox(width: 8),
                              Text("Task Preview", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            ],
                          ),
                          const Divider(),
                          const SizedBox(height: 8),
                          Text("Task: ${_taskPreview!['name']}", style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 4),
                          Text("Time: ${_taskPreview!['time']}", style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 4),
                          Text("Day: ${_taskPreview!['day_phrase']}", style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                ),

             if (_isConfirmation)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _processVoiceCommand("yes"),
                        icon: const Icon(Icons.check),
                        label: const Text("Yes"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () => _processVoiceCommand("no"),
                        icon: const Icon(Icons.close),
                        label: const Text("No"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),

             const SizedBox(height: 40),

             // Voice button
             GestureDetector(
                onLongPressStart: (_) => _startListening(),
                onLongPressEnd: (_) => _stopListening(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isListening ? 150 : 120,
                  height: _isListening ? 150 : 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? Colors.redAccent : Colors.teal,
                    boxShadow: [
                      BoxShadow(
                        color: (_isListening ? Colors.redAccent : Colors.teal).withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 10,
                      )
                    ],
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
             ),
             
             const SizedBox(height: 20),
             if (_isListening) 
                const Text("Listening...", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                
             const SizedBox(height: 40),
             
              const Padding(
               padding: EdgeInsets.symmetric(horizontal: 32),
               child: Text(
                 "Tap and hold to add a task or ask a question.\n\nExamples:\n• 'Remind me to take my medicine at 2 PM'\n• 'Remind me to drink water'",
                 textAlign: TextAlign.center,
                 style: TextStyle(color: Colors.grey, height: 1.5),
               ),
             )
          ],
        ),
      ),
    );
  }
}

