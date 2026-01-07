import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  
  bool _isListening = false;
  String _statusText = "Hold to record your thoughts";

  @override
  void initState() {
    super.initState();
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
      onStatus: (status) => print('STT Status: $status'),
      onError: (errorNotification) => print('STT Error: $errorNotification'),
    );
    if (!available) {
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
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission needed')));
         return;
    }

    if (!_speech.isAvailable) {
        await _speech.initialize();
    }

    setState(() {
      _isListening = true;
      _statusText = "Listening...";
    });
    
    _speech.listen(
      onResult: (val) {
        setState(() {
          _textController.text = val.recognizedWords;
        });
      },
      localeId: "en_US",
      cancelOnError: true,
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> _stopListening() async {
    _speech.stop();
    setState(() {
      _isListening = false;
      _statusText = "Processing...";
    });
    
    if (_textController.text.isNotEmpty) {
        await _processVoiceCommand(_textController.text);
    } else {
        setState(() => _statusText = "Hold to record your thoughts");
    }
  }

  Future<void> _processVoiceCommand(String text) async {
      try {
          final baseUrl = UserService.getApiUrl(context);
          final response = await http.post(
            Uri.parse('$baseUrl/api/ai/process_voice_command'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
                'uid': widget.user.uid,
                'text': text
            })
          );
          
          if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              final reply = data['reply'];
              
              // Speak the reply
              await _voiceService.speak(reply);
              
              // If it was just a recall query, maybe we don't save it as a journal entry?
              // But for now, let's look at the action.
              // If action is "complete_task", we might want to refresh something?
              
              // Only save to journal if it looks like a journal entry, 
              // BUT the requirements say "Memory Recall Chatbot".
              // So maybe we don't AUTO-SAVE everything to the journal UI list unless it's a "log" type.
              // For simplicity, we can just clear the text and show the reply in a snackbar/toast
              
               if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('AI: $reply'),
                    backgroundColor: Colors.blue,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
              
          }
      } catch (e) {
          print("Error processing voice: $e");
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
      }
      
      setState(() {
          _statusText = "Hold to record your thoughts";
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
             Padding(
               padding: const EdgeInsets.all(24.0),
               child: Text(
                 _statusText,
                 textAlign: TextAlign.center,
                 style: const TextStyle(fontSize: 18, color: Colors.blueGrey),
               ),
             ),
             
             const SizedBox(height: 40),

             // Voice button
             GestureDetector(
                onTapDown: (_) => _startListening(),
                onTapUp: (_) => _stopListening(),
                onTapCancel: () => _stopListening(),
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
             
             // Instructions
             const Padding(
               padding: EdgeInsets.symmetric(horizontal: 32),
               child: Text(
                 "Tap and hold to add a task or ask a question.\nExample: 'Remind me to call Nikeshi at 5 PM'",
                 textAlign: TextAlign.center,
                 style: TextStyle(color: Colors.grey),
               ),
             )
          ],
        ),
      ),
    );
  }
}

