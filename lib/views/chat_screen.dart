import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../controllers/chat_controller.dart';
import 'widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // 리소스 해제 및 화면 종료 시 TTS 중지 기능
  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ChatController>().stopTTS();
    });
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 음성 인식을 시작하거나 중지하는 기능
  void _listen() {
    final controller = context.read<ChatController>();
    if (!controller.isListening) {
      controller.startListening((recognizedText) {
        setState(() {
          if (_textController.text.isNotEmpty) {
            _textController.text += " $recognizedText";
          } else {
            _textController.text = recognizedText;
          }
          _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: _textController.text.length));
        });
      });
    } else {
      controller.stopListening();
    }
  }

  // 채팅 화면의 스크롤을 최하단으로 이동시키는 기능
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // 채팅 화면의 전체 UI 레이아웃 구성 기능
  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ChatController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: Text(controller.modeTitle),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: () {
            controller.stopTTS();
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent),
            onPressed: () => controller.clearChat(),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: controller.messages.length,
              itemBuilder: (ctx, i) => MessageBubble(message: controller.messages[i]),
            ),
          ),
          if (controller.isLoading)
            const Padding(padding: EdgeInsets.all(8), child: CupertinoActivityIndicator()),

          _buildInputArea(controller),
        ],
      ),
    );
  }

  // 메시지 입력창 및 이미지 미리보기 영역을 구성하는 기능
  Widget _buildInputArea(ChatController controller) {
    return Container(
      padding: const EdgeInsets.only(bottom: 30),
      color: Colors.white,
      child: Column(
        children: [
          if (controller.selectedImages.isNotEmpty)
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              margin: const EdgeInsets.only(bottom: 5),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: controller.selectedImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 10, top: 10),
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          image: DecorationImage(
                            image: FileImage(File(controller.selectedImages[index].path)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () => controller.removeImage(index),
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

          Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(CupertinoIcons.add_circled_solid, color: Colors.grey, size: 28),
                  onPressed: () => _showMediaSheet(controller),
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(24)),
                    child: TextField(
                      controller: _textController,
                      minLines: 1,
                      maxLines: 4,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: "메시지 입력..."
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _listen,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: controller.isListening ? Colors.redAccent : Colors.grey[200],
                    child: Icon(
                      controller.isListening ? CupertinoIcons.stop_fill : CupertinoIcons.mic_fill,
                      color: controller.isListening ? Colors.white : Colors.black54,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _send(controller),
                  child: const CircleAvatar(
                    radius: 18,
                    backgroundColor: Color(0xFF34C759),
                    child: Icon(CupertinoIcons.arrow_up, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 메시지 전송 로직을 트리거하는 기능
  void _send(ChatController controller) {
    if (_textController.text.trim().isEmpty && controller.selectedImages.isEmpty) return;
    controller.sendMessage(_textController.text);
    _textController.clear();
  }

  // 카메라 또는 앨범 선택을 위한 액션 시트를 표시하는 기능
  void _showMediaSheet(ChatController controller) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              final img = await ImagePicker().pickImage(source: ImageSource.camera);
              if (img != null) controller.pickImages([img]);
            },
            child: const Text("카메라 촬영"),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              final images = await ImagePicker().pickMultiImage();
              if (images.isNotEmpty) controller.pickImages(images);
            },
            child: const Text("앨범에서 선택"),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(ctx),
          child: const Text("취소"),
        ),
      ),
    );
  }
}