class UiMessage {
  final String? messageBody;
  final bool fromMe;
  final DateTime timestamp;
  String? fromJid;

  UiMessage({
    this.messageBody,
    required this.fromMe,
    required this.timestamp,
    this.fromJid,
  });
}

enum UiMessageType { TEXT, DATE }
