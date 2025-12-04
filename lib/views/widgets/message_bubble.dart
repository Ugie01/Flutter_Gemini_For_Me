import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/chat_controller.dart';
import '../../models/chat_message.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const MessageBubble({super.key, required this.message});

  // 개별 메시지 말풍선 UI를 구성하는 기능
  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final controller = context.watch<ChatController>();
    final isPlaying = controller.playingMessageId == message.id;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(right: 8.0, bottom: 2.0),
                child: GestureDetector(
                  onTap: () => controller.toggleTts(message.id, message.text),
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
                      if (message.imagePaths.isNotEmpty)
                        SizedBox(
                          height: 150,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: message.imagePaths.length,
                            shrinkWrap: true,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(File(message.imagePaths[index])),
                                ),
                              );
                            },
                          ),
                        ),
                      if (message.imagePaths.isNotEmpty)
                        const SizedBox(height: 8),

                      if (message.text.isNotEmpty)
                        MarkdownBody(
                          data: message.text,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(fontSize: 16, color: Colors.black),
                            strong: TextStyle(fontWeight: FontWeight.bold),
                          ),
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