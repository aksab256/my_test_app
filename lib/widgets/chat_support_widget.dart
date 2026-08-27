import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http_parser/http_parser.dart';

class ChatSupportWidget extends StatefulWidget {
  final String uid;
  final String role;

  const ChatSupportWidget({
    Key? key,
    required this.uid,
    required this.role,
  }) : super(key: key);

  @override
  State<ChatSupportWidget> createState() => _ChatSupportWidgetState();
}

class _ChatSupportWidgetState extends State<ChatSupportWidget> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  final AudioRecorder _audioRecorder = AudioRecorder();
  final FlutterTts _flutterTts = FlutterTts();

  bool _isLoading = false;
  bool _isRecording = false;
  bool _isPlayingAudio = false;
  String? _recordedAudioPath;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  // تهيئة محرك تحويل النص إلى صوت (Text-To-Speech)
  Future<void> _initTts() async {
    await _flutterTts.setLanguage("ar");
    await _flutterTts.setSpeechRate(0.45); // سرعة نطق مناسبة ومفهومة
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      if (mounted) {
        setState(() {
          _isPlayingAudio = true;
        });
      }
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
        });
      }
    });
  }

  // تشغيل أو إيقاف نطق النص صوتياً
  Future<void> _speakText(String text) async {
    if (_isPlayingAudio) {
      await _flutterTts.stop();
      setState(() {
        _isPlayingAudio = false;
      });
    } else {
      if (text.isNotEmpty) {
        // تنظيف النص من أجزاء الروابط والعلامات البرمجية قبل القراءة
        String cleanText = text
            .replaceAll(RegExp(r'https?://[^\s]+'), '')
            .replaceAll(RegExp(r'\[.*?\]'), '')
            .replaceAll('#', '')
            .trim();

        if (cleanText.isNotEmpty) {
          await _flutterTts.speak(cleanText);
        }
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  // التمرير لأسفل القائمة تلقائياً
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // --- إدارة الأذونات والتسجيل الصوتي وفق اشتراطات جوجل ---
  Future<void> _handleMicrophonePermissionAndRecord() async {
    if (_isRecording) {
      // إيقاف التسجيل
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordedAudioPath = path;
      });
      return;
    }

    // فحص إذن الميكروفون
    var status = await Permission.microphone.status;

    if (status.isDenied) {
      bool proceed = await _showPermissionDialog();
      if (!proceed) return;
      status = await Permission.microphone.request();
    }

    if (status.isPermanentlyDenied) {
      _showSettingsDialog();
      return;
    }

    if (status.isGranted) {
      if (await _audioRecorder.hasPermission()) {
        final Directory tempDir = await getTemporaryDirectory();
        final String filePath =
            '${tempDir.path}/shira_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: filePath,
        );

        setState(() {
          _isRecording = true;
          _recordedAudioPath = null;
        });
      }
    }
  }

  Future<bool> _showPermissionDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text("إذن تسجيل الصوت",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            content: const Text(
              "نحتاج الوصول للميكروفون لتتمكن من إرسال الاستفسارات والرسائل الصوتية المباشرة لشيرا.",
              style: TextStyle(fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("إلغاء",
                    style: TextStyle(color: Colors.grey, fontSize: 15)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text("سماح",
                    style: TextStyle(color: Colors.white, fontSize: 15)),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("الميكروفون محظور",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: const Text(
          "يبدو أنك رفضت الإذن بشكل دائم. يمكنك تفعيله يدويًا من إعدادات التطبيق للاستفادة من الميزة الصوتية.",
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("إلغاء",
                style: TextStyle(color: Colors.grey, fontSize: 15)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5)),
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text("الإعدادات",
                style: TextStyle(color: Colors.white, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  // --- إرسال الرسائل (نص أو صوت) ---
  Future<void> _sendMessage() async {
    final textMessage = _messageController.text.trim();
    final hasAudio = _recordedAudioPath != null;

    if (textMessage.isEmpty && !hasAudio) return;

    // إضافة رسالة المستخدم في الواجهة
    setState(() {
      _messages.add({
        "sender": "user",
        "text": hasAudio ? "🎤 [رسالة صوتية]" : textMessage,
        "isAudio": hasAudio,
        "audioPath": _recordedAudioPath,
      });
      _isLoading = true;
    });

    _messageController.clear();
    final audioToSend = _recordedAudioPath;
    setState(() {
      _recordedAudioPath = null;
    });

    _scrollToBottom();

    try {
      final url = Uri.parse("https://shirachat-tmfag3rhdq-uc.a.run.app");
      http.Response response;

      if (hasAudio) {
        // 1. إنشاء MultipartRequest
        var request = http.MultipartRequest("POST", url);
        
        // 2. إضافة Headers صريحة لمنع انقطاع اتصال الـ SSL أثناء المصافحة
        request.headers.addAll({
          'Accept': 'application/json',
        });

        request.fields['uid'] = widget.uid;
        request.fields['role'] = widget.role;
        if (textMessage.isNotEmpty) {
          request.fields['message'] = textMessage;
        }

        // 3. تحديد نوع الملف الصوتي (audio/m4a) بوضوح لضمان قراءته بشكل صحيح في الباك إند
        final file = await http.MultipartFile.fromPath(
          'file', 
          audioToSend!,
          contentType: MediaType('audio', 'm4a'),
        );
        request.files.add(file);

        // 4. إرسال الطلب واستقبال الرد بأمان
        var streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else {
        // إرسال JSON عادي يتضمن uid و role و message
        response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "uid": widget.uid,
            "role": widget.role,
            "message": textMessage,
          }),
        );
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final reply = data["message"] ?? data["reply"] ?? "لم يتم استلام رد من النظام.";

        setState(() {
          _messages.add({
            "sender": "bot",
            "text": reply,
            "file": data["file"], // في حال أرجع الباك إند ملف تقرير
          });
        });

        // إذا أرسل المستخدم بصمة صوتية، ينطق المساعد الذكي الرد تلقائياً
        if (hasAudio) {
          _speakText(reply);
        }
      } else {
        setState(() {
          _messages.add({
            "sender": "bot",
            "text": "حدث خطأ في الاتصال بالخادم (${response.statusCode})."
          });
        });
      }
    } catch (e) {
      setState(() {
        _messages.add({
          "sender": "bot",
          "text": "عذراً، حدث خطأ أثناء إرسال البيانات: $e"
        });
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          elevation: 1,
          backgroundColor: Colors.white,
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF1E88E5).withOpacity(0.1),
                child: const Icon(Icons.smart_toy_outlined, color: Color(0xFF1E88E5)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "المساعد الذكي (شيرا)",
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "إدارة العهدة والاستفسارات",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            // قائمة المحادثات
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg["sender"] == "user";
                  return _buildMessageBubble(
                    text: msg["text"],
                    isUser: isUser,
                    isAudio: msg["isAudio"] ?? false,
                    fileData: msg["file"],
                  );
                },
              ),
            ),

            // مؤشر التحميل
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),

            // شريط إدخال الرسائل والتسجيل
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  // تصميم فقاعة المحادثة
  Widget _buildMessageBubble({
    required String text,
    required bool isUser,
    bool isAudio = false,
    Map<String, dynamic>? fileData,
  }) {
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF1E88E5) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 4 : 16),
            bottomRight: Radius.circular(isUser ? 16 : 4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isAudio) ...[
                  Icon(Icons.mic,
                      size: 18, color: isUser ? Colors.white : const Color(0xFF1E88E5)),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15.0,
                      height: 1.4,
                      color: isUser ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                if (!isUser) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _speakText(text),
                    child: Icon(
                      _isPlayingAudio ? Icons.volume_off : Icons.volume_up_rounded,
                      size: 20,
                      color: const Color(0xFF1E88E5),
                    ),
                  ),
                ],
              ],
            ),
            // عرض رابط التحميل لو الرسال فيها تقرير CSV أو ملف مرفق من السيرفر
            if (fileData != null && fileData["url"] != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.insert_drive_file, color: Color(0xFF1E88E5), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileData["name"] ?? "تحميل التقرير",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // تصميم منطقة الإدخال السفلية
  Widget _buildInputArea() {
    final bool hasText = _messageController.text.trim().isNotEmpty;
    final bool hasAudioReady = _recordedAudioPath != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // زر الميكروفون
            GestureDetector(
              onTap: _handleMicrophonePermissionAndRecord,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red.withOpacity(0.1) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isRecording ? Icons.stop_circle : Icons.mic_rounded,
                  color: _isRecording ? Colors.red : const Color(0xFF5F6368),
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 4),

            // حقل النص أو عرض حالة التسجيل
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F4),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: _isRecording
                    ? Row(
                        children: const [
                          Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
                          SizedBox(width: 8),
                          Text(
                            "جاري التسجيل الصوتي...",
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : hasAudioReady
                        ? Row(
                            children: [
                              const Icon(Icons.audio_file, color: Color(0xFF1E88E5), size: 18),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  "تسجيل صوتي جاهز للإرسال",
                                  style: TextStyle(fontSize: 14, color: Colors.black87),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                                onPressed: () {
                                  setState(() {
                                    _recordedAudioPath = null;
                                  });
                                },
                              ),
                            ],
                          )
                        : TextField(
                            controller: _messageController,
                            onChanged: (_) => setState(() {}),
                            style: const TextStyle(fontSize: 15.0),
                            decoration: const InputDecoration(
                              hintText: "اكتب استفسارك هنا...",
                              hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                              border: InputBorder.none,
                            ),
                          ),
              ),
            ),

            const SizedBox(width: 8),

            // زر الإرسال
            InkWell(
              onTap: (hasText || hasAudioReady) && !_isLoading ? _sendMessage : null,
              borderRadius: BorderRadius.circular(24),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: (hasText || hasAudioReady) && !_isLoading
                    ? const Color(0xFF1E88E5)
                    : Colors.grey.shade300,
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}