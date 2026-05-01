import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // Unused
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
  bool _isRecallMode = false; // NEW
  String _statusText = "Alex is listening...";
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
    
    // Auto-greet logic
    Future.delayed(const Duration(milliseconds: 500), () async {
        await _voiceService.init();
        if (widget.initialPrompt != null) {
            await _voiceService.speak(widget.initialPrompt!);
            if (mounted) _startListening();
        } else {
            await _fetchGreeting();
        }
    });
  }

  String _getGreetingPhrase() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "Good morning";
    } else if (hour < 15) {
      return "Good afternoon";
    } else {
      return "Good evening";
    }
  }

  Future<void> _fetchGreeting() async {
    try {
      final baseUrl = UserService.getApiUrl(context);
      final response = await http.get(Uri.parse('$baseUrl/api/ai/greet?uid=${widget.user.uid}'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String reply = data['reply'] ?? "Hello! I'm Alex.";
        
        // Ensure the reply starts with the real-time greeting
        final greeting = _getGreetingPhrase();
        if (!reply.toLowerCase().startsWith(greeting.toLowerCase())) {
          reply = "$greeting! $reply";
        }

        if (mounted) {
          setState(() {
            _aiReply = reply;
          });
          await _voiceService.speak(reply);
          _startListening();
        }
      }
    } catch (e) {
      debugPrint("Error fetching greeting: $e");
      final greeting = _getGreetingPhrase();
      if (mounted) {
        setState(() {
          _aiReply = "$greeting! How can I help you today?";
        });
        await _voiceService.speak(_aiReply);
        _startListening();
      }
    }
  }
  
  void _initVoice() async {
    await _voiceService.init();

    bool available = await _speech.initialize(
      onStatus: (status) {
        debugPrint("STT Status: $status");
        if (!mounted) return;

        // Just update UI state, do NOT call stop here
        if (status == "notListening" || status == "done") {
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (error) {
        debugPrint("STT Error: $error");
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

  Future<void> _startListening({bool isRecall = false}) async {
    if (_isSpeaking) return; // don't listen while speaking

    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission needed')),
        );
      }
      return;
    }

    if (!_speech.isAvailable) {
      await _speech.initialize();
    }

    setState(() {
      _isListening = true;
      _isRecallMode = isRecall;
      _statusText = isRecall ? "Alex is focusing on your memories..." : "Listening...";
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

    debugPrint("Captured final: '$capturedText'");

    if (capturedText.isNotEmpty) {
      if (_isRecallMode) {
        await _processRecallCommand(capturedText);
      } else {
        await _processVoiceCommand(capturedText);
      }
    } else {
      setState(() => _statusText = "Alex is waiting for you...");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("I didn't hear anything. Please try again.")),
        );
      }
    }
  }

  Future<void> _processRecallCommand(String text) async {
    try {
      setState(() {
        _isSpeaking = true;
        _statusText = "Analyzing memories...";
      });
      await _speech.stop();
      
      final baseUrl = UserService.getApiUrl(context);
      final response = await http.post(
        Uri.parse('$baseUrl/api/ai/recall_memory'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
            'uid': widget.user.uid,
            'text': text,
            'session_id': "${_sessionId}_recall",
            'local_time': DateTime.now().toIso8601String(), // NEW
        })
      );
      
      if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final reply = data['reply'] ?? "";

          if (mounted) {
            setState(() {
              _aiReply = reply;
              _statusText = "Speaking...";
              _isConfirmation = false;
              _taskPreview = null;
            });
          }

          _voiceService.setCompletionHandler(() async {
              if (!mounted) return;
              setState(() {
                _isSpeaking = false;
                _statusText = "Alex is listening...";
              });
              _startListening(isRecall: true); // Stay in recall mode loop for companion experience
          });

          await _voiceService.speak(reply);
      } else {
        setState(() => _isSpeaking = false);
      }
    } catch (e) {
      debugPrint("Error processing recall: $e");
      setState(() => _isSpeaking = false);
    }
  }

  Future<void> _processVoiceCommand(String text) async {
      try {
          setState(() {
            _isSpeaking = true;
            _isRecallMode = false;
          });
          await _speech.stop();
          
          final baseUrl = UserService.getApiUrl(context);
          final response = await http.post(
            Uri.parse('$baseUrl/api/ai/process_voice_command'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
                'uid': widget.user.uid,
                'text': text,
                'session_id': _sessionId,
                'local_time': DateTime.now().toIso8601String(), // NEW
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
                         _statusText = "Alex is listening...";
                      }
                    });

                  if (action == 'close') {
                      await Future.delayed(const Duration(seconds: 2));
                      if (mounted) Navigator.pop(context);
                  } else {
                      _startListening();
                  }
              });

              await _voiceService.speak(reply);
              
               if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Alex: $reply'),
                    backgroundColor: Colors.teal,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
          } else {
            setState(() => _isSpeaking = false);
          }
      } catch (e) {
          debugPrint("Error processing voice: $e");
          setState(() => _isSpeaking = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
      }
      
      if (mounted) {
        setState(() {
            _liveWords = "";
            _finalWords = "";
            _textController.clear();
        });
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alex - Routine Coach', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const SizedBox(height: 20),
                   // Transcript Box
                   Container(
                     padding: const EdgeInsets.all(16),
                     width: double.infinity,
                     decoration: BoxDecoration(
                       color: Colors.grey.shade100,
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(color: Colors.grey.shade300),
                     ),
                      child: Text(
                        _aiReply.isNotEmpty ? "Alex: $_aiReply" : (_liveWords.isNotEmpty ? "You: $_liveWords" : "Let's talk..."),
                        style: TextStyle(
                           fontSize: 18, 
                           color: _aiReply.isNotEmpty ? Colors.teal[800] : Colors.black87
                        ),
                      ),
                   ),
                   
                   const SizedBox(height: 12),
                   Text(
                     _statusText,
                     textAlign: TextAlign.center,
                     style: TextStyle(
                       fontSize: 16, 
                       color: _isRecallMode ? Colors.purple : Colors.blueGrey,
                       fontWeight: _isRecallMode ? FontWeight.bold : FontWeight.normal,
                     ),
                   ),
                   
                   const SizedBox(height: 20),
      
                   // Task Preview Card (when confirmed)
                   if (_taskPreview != null)
                      Card(
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

                   // Split Microphones
                   Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 1. General Coach Mic
                      Column(
                        children: [
                          GestureDetector(
                              onLongPressStart: (_) => _startListening(isRecall: false),
                              onLongPressEnd: (_) => _stopListening(),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: (_isListening && !_isRecallMode) ? 110 : 90,
                                height: (_isListening && !_isRecallMode) ? 110 : 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (_isListening && !_isRecallMode) ? Colors.redAccent : Colors.teal,
                                  boxShadow: [
                                    BoxShadow(
                                      color: ((_isListening && !_isRecallMode) ? Colors.redAccent : Colors.teal).withOpacity(0.4),
                                      blurRadius: 15,
                                      spreadRadius: 5,
                                    )
                                  ],
                                ),
                                child: const Icon(Icons.mic, size: 40, color: Colors.white),
                              ),
                          ),
                          const SizedBox(height: 12),
                          const Text("Alex", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                        ],
                      ),
                      
                      const SizedBox(width: 40),

                      // 2. Memory Recall Mic
                      Column(
                        children: [
                          GestureDetector(
                              onLongPressStart: (_) => _startListening(isRecall: true),
                              onLongPressEnd: (_) => _stopListening(),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: (_isListening && _isRecallMode) ? 110 : 90,
                                height: (_isListening && _isRecallMode) ? 110 : 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: (_isListening && _isRecallMode) ? Colors.redAccent : Colors.purple,
                                  boxShadow: [
                                    BoxShadow(
                                      color: ((_isListening && _isRecallMode) ? Colors.redAccent : Colors.purple).withOpacity(0.4),
                                      blurRadius: 15,
                                      spreadRadius: 5,
                                    )
                                  ],
                                ),
                                child: const Icon(Icons.psychology, size: 40, color: Colors.white),
                              ),
                          ),
                          const SizedBox(height: 12),
                          const Text("Memory", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                        ],
                      ),
                    ],
                   ),
                   
                   const SizedBox(height: 20),
                   if (_isListening) 
                      const Text("Listening...", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      
                   const SizedBox(height: 30),
                   
                    const Text(
                      "Hold 'Alex' to plan tasks.\nHold 'Memory' to recall past activities.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, height: 1.5),
                    ),
                ],
              ),
            ),
          ),
          
          // Bottom Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
               color: Colors.white,
               boxShadow: [
                 BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, -2))
               ]
            ),
            child: SafeArea(
              child: Row(
                children: [
                   Expanded(
                     child: TextField(
                       controller: _textController,
                       decoration: InputDecoration(
                         hintText: "Type your message...",
                         border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                         filled: true,
                         fillColor: const Color(0xFFF5F5F5)
                       ),
                     ),
                   ),
                   const SizedBox(width: 8),
                   IconButton(
                     onPressed: () {
                        if (_textController.text.trim().isNotEmpty) {
                           _processVoiceCommand(_textController.text.trim());
                        }
                     }, 
                     icon: const Icon(Icons.send, color: Colors.teal),
                     tooltip: "Send",
                   ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
