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

  @override
  void dispose() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ChatController>().stopTTS();
      }
    });
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _listen() {
    final controller = context.read<ChatController>();

    if (!controller.isListening) {
      controller.startListening((recognizedText) {
        setState(() {
          _textController.text = recognizedText;
          _textController.selection = TextSelection.fromPosition(
              TextPosition(offset: _textController.text.length));
        });
      });
    } else {
      controller.stopListening();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

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

  Widget _buildInputArea(ChatController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 30),
      color: Colors.white,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.add_circled_solid, color: Colors.grey, size: 28),
            onPressed: () => _showMediaSheet(controller),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(24)),
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(border: InputBorder.none, hintText: "메시지 입력..."),
                onSubmitted: (_) => _send(controller),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // [STT 버튼]
          GestureDetector(
            onTap: _listen, // 위에서 정의한 _listen 함수 호출
            child: CircleAvatar(
              radius: 18,
              // 듣는 중이면 빨간색, 아니면 회색
              backgroundColor: controller.isListening ? Colors.redAccent : Colors.grey[200],
              child: Icon(
                // 듣는 중이면 정지 아이콘, 아니면 마이크 아이콘
                controller.isListening ? CupertinoIcons.stop_fill : CupertinoIcons.mic_fill,
                color: controller.isListening ? Colors.white : Colors.black54,
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 8),

          // [전송 버튼]
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
    );
  }

  void _send(ChatController controller) {
    if (_textController.text.trim().isEmpty) return;
    controller.sendMessage(_textController.text);
    _textController.clear();
  }

  void _showMediaSheet(ChatController controller) {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              final img = await ImagePicker().pickImage(source: ImageSource.camera);
              if (img != null) controller.sendMessage("이 사진 설명해줘", imageFile: img);
            },
            child: const Text("카메라 촬영"),
          ),
          CupertinoActionSheetAction(
            onPressed: () async {
              Navigator.pop(ctx);
              final img = await ImagePicker().pickImage(source: ImageSource.gallery);
              if (img != null) controller.sendMessage("이 사진 분석해줘", imageFile: img);
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