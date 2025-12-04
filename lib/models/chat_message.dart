class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final String? imagePath;
  final DateTime time;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.imagePath,
    required this.time,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isUser': isUser,
    'imagePath': imagePath,
    'time': time.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'],
    text: json['text'],
    isUser: json['isUser'],
    imagePath: json['imagePath'],
    time: DateTime.parse(json['time']),
  );
}