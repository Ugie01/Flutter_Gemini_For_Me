import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/chat_controller.dart';
import '../../models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    // 실시간 아이콘 변경을 위해 watch 사용
    final controller = context.watch<ChatController>();
    final isPlaying = controller.playingMessageId == message.id;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
        // 버튼 공간을 위해 최대 폭 조절
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end, // 말풍선 하단 정렬
          children: [
            // AI 메시지면 왼쪽에 스피커 버튼 추가
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(right: 8.0, bottom: 2.0),
                child: GestureDetector(
                  onTap: () {
                    // TTS 토글 (재생/정지)
                    controller.toggleTts(message.id, message.text);
                  },
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey[200],
                    child: Icon(
                      isPlaying ? CupertinoIcons.stop_fill : CupertinoIcons.speaker_2_fill,
                      size: 18,
                      color: isPlaying ? Colors.redAccent : Colors.black54,
                    ),
                  ),
                ),
              ),

            // [기존 말풍선]
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: isUser ? const Color(0xFF34C759) : const Color(0xFFE5E5EA),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(5),
                    bottomRight: isUser ? const Radius.circular(5) : const Radius.circular(20),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.imagePath != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(File(message.imagePath!)),
                          ),
                        ),
                      Text(
                        message.text,
                        style: TextStyle(
                            color: isUser ? Colors.white : Colors.black87,
                            fontSize: 16, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}