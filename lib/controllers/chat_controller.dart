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

  List<XFile> _selectedImages = [];
  List<XFile> get selectedImages => _selectedImages;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isListening => _isListening;
  String? get playingMessageId => _playingMessageId;
  String get modeTitle => _currentMode == 'normal' ? '기본 모드' : '영어 튜터';

  late GenerativeModel _model;
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final Uuid _uuid = const Uuid();

  // 컨트롤러 초기화 및 주요 서비스 시작 기능
  ChatController() {
    _initGemini();
    _initTTS();
    _loadMessages();
    _initSTT();
  }

  // 음성 인식(STT) 엔진 초기화 및 상태 리스너 설정 기능
  void _initSTT() async {
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
          notifyListeners();
        }
      },
      onError: (error) {
        _isListening = false;
        notifyListeners();
      },
    );
  }

  // Gemini API 모델 초기화 및 프롬프트 설정 기능
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

  // 대화 모드를 변경하고 관련 설정을 재초기화하는 기능
  void setMode(String mode) {
    if (_currentMode != mode) {
      stopTTS();
      _currentMode = mode;
      _initGemini();
      _loadMessages();
      notifyListeners();
    }
  }

  // 음성 합성(TTS) 엔진 초기화 및 언어 설정 기능
  void _initTTS() async {
    await _flutterTts.setLanguage("ko-KR");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
    _flutterTts.setCompletionHandler(() {
      _playingMessageId = null;
      notifyListeners();
    });
  }

  // 특정 메시지의 TTS 재생 또는 중지를 토글하는 기능
  Future<void> toggleTts(String messageId, String text) async {
    if (_playingMessageId == messageId) {
      await _flutterTts.stop();
      _playingMessageId = null;
    } else {
      await _flutterTts.stop();
      _playingMessageId = messageId;
      if (_currentMode == 'tutor') await _flutterTts.setLanguage("en-US");
      else await _flutterTts.setLanguage("ko-KR");
      await _flutterTts.speak(text);
    }
    notifyListeners();
  }

  // 현재 재생 중인 TTS를 즉시 중지하는 기능
  Future<void> stopTTS() async {
    await _flutterTts.stop();
    _playingMessageId = null;
    notifyListeners();
  }

  // 마이크를 통해 음성을 텍스트로 변환하기 시작하는 기능
  Future<void> startListening(Function(String) onTextUpdate) async {
    bool available = await _speech.initialize();
    if (available) {
      _isListening = true;
      notifyListeners();
      String localeId = _currentMode == 'tutor' ? 'en_US' : 'ko_KR';
      _speech.listen(
        onResult: (result) => onTextUpdate(result.recognizedWords),
        localeId: localeId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      );
    }
  }

  // 음성 인식을 중지하는 기능
  Future<void> stopListening() async {
    _isListening = false;
    await _speech.stop();
    notifyListeners();
  }

  // 갤러리나 카메라에서 가져온 이미지를 전송 목록에 추가하는 기능
  void pickImages(List<XFile> images) {
    _selectedImages.addAll(images);
    notifyListeners();
  }

  // 전송 목록에서 특정 이미지를 제거하는 기능
  void removeImage(int index) {
    _selectedImages.removeAt(index);
    notifyListeners();
  }

  // 텍스트와 이미지를 포함하여 메시지를 전송하고 AI 응답을 받는 기능
  Future<void> sendMessage(String text) async {
    if ((text.trim().isEmpty && _selectedImages.isEmpty) || _isLoading) return;

    try {
      _isLoading = true;

      final userMsg = ChatMessage(
        id: _uuid.v4(),
        text: text,
        isUser: true,
        imagePaths: _selectedImages.map((e) => e.path).toList(),
        time: DateTime.now(),
      );
      _messages.add(userMsg);

      final imagesToSend = List<XFile>.from(_selectedImages);
      _selectedImages.clear();

      notifyListeners();
      _saveMessages();

      final List<Part> parts = [];

      if (text.isNotEmpty) parts.add(TextPart(text));

      for (var img in imagesToSend) {
        final bytes = await img.readAsBytes();
        parts.add(DataPart('image/jpeg', bytes));
      }

      final content = Content.multi(parts);

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

  // 현재 대화 내용과 선택된 이미지를 모두 초기화하는 기능
  void clearChat() async {
    stopTTS();
    _messages.clear();
    _selectedImages.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_history_$_currentMode');
    notifyListeners();
  }

  // 대화 내용을 로컬 저장소에 저장하는 기능
  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_messages.map((m) => m.toJson()).toList());
    await prefs.setString('chat_history_$_currentMode', encoded);
  }

  // 로컬 저장소에서 대화 내용을 불러오는 기능
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