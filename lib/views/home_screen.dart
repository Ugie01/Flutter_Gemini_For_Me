import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../controllers/chat_controller.dart';
import 'chat_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 80),
              const Text("Hello,\nMy Gemini",
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: -1.0)),
              const SizedBox(height: 10),
              const Text("대화할 AI 페르소나를 선택해주세요.",
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 50),
              // 기본 모드 버튼
              _buildCard(context, "기본 모드", "친절한 AI 비서", "🤖", const Color(0xFF34C759), 'normal'),
              const SizedBox(height: 20),
              // 튜터 모드 버튼
              _buildCard(context, "영어 튜터", "엄격한 문법 선생님", "🎓", const Color(0xFF007AFF), 'tutor'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, String title, String sub, String icon, Color color, String mode) {
    return GestureDetector(
      onTap: () {
        // 모드 설정 -> Controller가 내부에서 채팅방 데이터를 교체함
        context.read<ChatController>().setMode(mode);
        Navigator.push(context, CupertinoPageRoute(builder: (_) => const ChatScreen()));
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3))),
        child: Row(
          children: [
            Container(
                width: 60, height: 60,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
                alignment: Alignment.center,
                child: Text(icon, style: const TextStyle(fontSize: 30))),
            const SizedBox(width: 20),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(sub, style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.6))),
            ]),
            const Spacer(),
            Icon(CupertinoIcons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}