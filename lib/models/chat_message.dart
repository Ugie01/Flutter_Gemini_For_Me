class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final List<String> imagePaths;
  final DateTime time;

  // 메시지 객체 생성자 정의
  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.imagePaths = const [],
    required this.time,
  });

  // 객체를 JSON 맵 형태로 변환하는 기능
  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'isUser': isUser,
    'imagePaths': imagePaths,
    'time': time.toIso8601String(),
  };

  // JSON 맵을 객체로 변환하는 기능
  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'],
    text: json['text'],
    isUser: json['isUser'],
    imagePaths: List<String>.from(json['imagePaths'] ?? []),
    time: DateTime.parse(json['time']),
  );
}