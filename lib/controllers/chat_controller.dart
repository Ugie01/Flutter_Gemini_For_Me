import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';

class ChatController extends ChangeNotifier {
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isListening = false;
  String _currentMode = 'normal';
  String? _playingMessageId;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isListening => _isListening;
  String? get playingMessageId => _playingMessageId;
  String get modeTitle => _currentMode == 'normal' ? '기본 모드' : '영어 튜터';

  late GenerativeModel _model;
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final Uuid _uuid = const Uuid();

  ChatController() {
    _initGemini();
    _initTTS();
    _loadMessages();
    _initSTT(); // STT 초기화 추가
  }

  // STT 상태 리스너 초기화 (아이콘 자동 변경을 위해 필수)
  void _initSTT() async {
    await _speech.initialize(
      onStatus: (status) {
        // 인식이 끝나거나 취소되면 듣기 상태 해제
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
          notifyListeners();
        }
      },
      onError: (error) {
        _isListening = false;
        notifyListeners();
        print('STT Error: $error');
      },
    );
  }

  void _initGemini() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null) return;

    String systemPrompt = "당신은 도움이 되는 AI 비서입니다. 한국어로 대답하세요.";
    if (_currentMode == 'tutor') {
      systemPrompt = "You are a strict English tutor. Only speak English and correct the user's grammar.";
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      systemInstruction: Content.system(systemPrompt),
    );
  }

  void setMode(String mode) {
    if (_currentMode != mode) {
      stopTTS();
      _currentMode = mode;
      _initGemini();
      _loadMessages();
      notifyListeners();
    }
  }

  void _initTTS() async {
    await _flutterTts.setLanguage("ko-KR");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5); // 속도 조절됨

    _flutterTts.setCompletionHandler(() {
      _playingMessageId = null;
      notifyListeners();
    });
  }

  Future<void> toggleTts(String messageId, String text) async {
    if (_playingMessageId == messageId) {
      await _flutterTts.stop();
      _playingMessageId = null;
    } else {
      await _flutterTts.stop();
      _playingMessageId = messageId;
      if (_currentMode == 'tutor') {
        await _flutterTts.setLanguage("en-US");
      } else {
        await _flutterTts.setLanguage("ko-KR");
      }
      await _flutterTts.speak(text);
    }
    notifyListeners();
  }

  Future<void> stopTTS() async {
    await _flutterTts.stop();
    _playingMessageId = null;
    notifyListeners();
  }

  // STT 시작 함수 (결과를 돌려줄 콜백 함수를 받음)
  Future<void> startListening(Function(String) onTextUpdate) async {
    bool available = await _speech.initialize();
    if (available) {
      _isListening = true;
      notifyListeners();

      // 언어 설정: 튜터 모드면 영어 인식, 아니면 한국어 인식
      String localeId = _currentMode == 'tutor' ? 'en_US' : 'ko_KR';

      _speech.listen(
        onResult: (result) {
          // 인식된 단어를 View로 전달
          onTextUpdate(result.recognizedWords);
        },
        localeId: localeId,
        listenFor: const Duration(seconds: 30), // 최대 30초 듣기
        pauseFor: const Duration(seconds: 3),   // 3초 침묵 시 종료
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      );
    }
  }

  Future<void> stopListening() async {
    _isListening = false;
    await _speech.stop();
    notifyListeners();
  }

  Future<void> sendMessage(String text, {XFile? imageFile}) async {
    if ((text.trim().isEmpty && imageFile == null) || _isLoading) return;

    try {
      _isLoading = true;
      final userMsg = ChatMessage(
        id: _uuid.v4(),
        text: text,
        isUser: true,
        imagePath: imageFile?.path,
        time: DateTime.now(),
      );
      _messages.add(userMsg);
      notifyListeners();
      _saveMessages();

      Content content;
      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        content = Content.multi([TextPart(text), DataPart('image/jpeg', bytes)]);
      } else {
        content = Content.text(text);
      }

      final aiMsgId = _uuid.v4();
      _messages.add(ChatMessage(id: aiMsgId, text: "", isUser: false, time: DateTime.now()));
      notifyListeners();

      final responseStream = _model.generateContentStream([content]);
      String fullText = "";

      await for (final chunk in responseStream) {
        if (chunk.text != null) {
          fullText += chunk.text!;
          _messages.last = ChatMessage(
              id: aiMsgId, text: fullText, isUser: false, time: DateTime.now());
          notifyListeners();
        }
      }
      _saveMessages();
    } catch (e) {
      _messages.add(ChatMessage(
          id: _uuid.v4(), text: "오류: $e", isUser: false, time: DateTime.now()));
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearChat() async {
    stopTTS();
    _messages.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_history_$_currentMode');
    notifyListeners();
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_messages.map((m) => m.toJson()).toList());
    await prefs.setString('chat_history_$_currentMode', encoded);
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final String? stored = prefs.getString('chat_history_$_currentMode');
    if (stored != null) {
      final List<dynamic> decoded = jsonDecode(stored);
      _messages = decoded.map((e) => ChatMessage.fromJson(e)).toList();
    } else {
      _messages = [];
    }
    notifyListeners();
  }
}