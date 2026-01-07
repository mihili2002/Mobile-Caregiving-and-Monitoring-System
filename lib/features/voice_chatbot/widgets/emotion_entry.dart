class EmotionEntry {
  final DateTime time;
  final String userText;
  final String emotion;
  final String intent;

  EmotionEntry({
    required this.time,
    required this.userText,
    required this.emotion,
    required this.intent,
  });
}
