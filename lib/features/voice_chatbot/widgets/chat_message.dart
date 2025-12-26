class ChatMessage {
  final String text;
  final bool isUser;
  final String? emotion;
  final String? intent;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.emotion,
    this.intent,
  });
}
