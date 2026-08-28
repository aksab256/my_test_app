import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http_parser/http_parser.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audioplayers/audioplayers.dart';

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

class _ChatSupportWidgetState extends State<ChatSupportWidget>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];

  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isLoading = false;
  bool _isFetchingHistory = true;
  bool _isRecording = false;
  bool _isPlayingAudio = false;
  String? _currentlyPlayingUrl;
  String? _recordedAudioPath;

  // أنيميشن التأثير السحري لجيمناي
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
    _fetchChatHistory();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  // تهيئة مشغل الصوت للردود الصوتية المباشرة من Gemini
  void _initAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = (state == PlayerState.playing);
          if (state == PlayerState.completed || state == PlayerState.stopped) {
            _currentlyPlayingUrl = null;
          }
        });
      }
    });
  }

  // تحديد المسار الصحيح للمستخدم حسب نوع حسابه (Role)
  String _getUserCollection() {
    switch (widget.role) {
      case 'seller':
        return 'sellers';
      case 'consumer':
        return 'consumers';
      case 'sales_representative':
        return 'salesRep';
      case 'freelance_agent':
        return 'freeDrivers';
      case 'company_agent':
        return 'deliveryReps';
      case 'sales_supervisor':
      case 'delivery_supervisor':
      case 'sales_manager':
      case 'delivery_manager':
      case 'admin':
      case 'financial':
        return 'managers';
      case 'buyer':
      default:
        return 'users';
    }
  }

  // جلب آخر 15 رسالة فقط من سجل المحادثات
  Future<void> _fetchChatHistory() async {
    try {
      final collectionName = _getUserCollection();
      final snapshot = await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(widget.uid)
          .collection('chats')
          .doc('shira_main')
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(15)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final docs = snapshot.docs.reversed.toList();
        setState(() {
          for (var doc in docs) {
            final data = doc.data();
            _messages.add({
              "sender": data['sender'] ?? 'bot',
              "text": data['text'] ?? '',
              "isAudio": data['isAudio'] ?? false,
              "audioUrl": data['audioUrl'],
              "file": data['file'],
            });
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Error fetching chat history: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingHistory = false;
        });
      }
    }
  }

  // حفظ الرسالة في Firestore لضمان استرجاع التاريخ مستقبلاً
  Future<void> _saveMessageToFirestore({
    required String sender,
    required String text,
    bool isAudio = false,
    String? audioUrl,
    Map<String, dynamic>? file,
  }) async {
    try {
      final collectionName = _getUserCollection();
      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(widget.uid)
          .collection('chats')
          .doc('shira_main')
          .collection('messages')
          .add({
        "sender": sender,
        "text": text,
        "isAudio": isAudio,
        "audioUrl": audioUrl,
        "file": file,
        "timestamp": FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error saving message to Firestore: $e");
    }
  }

  // تشغيل أو إيقاف المقطع الصوتي القادم من Gemini TTS
  Future<void> _playGeminiAudio(String? url) async {
    if (url == null || url.isEmpty) return;

    if (_isPlayingAudio && _currentlyPlayingUrl == url) {
      await _audioPlayer.stop();
      setState(() {
        _isPlayingAudio = false;
        _currentlyPlayingUrl = null;
      });
    } else {
      await _audioPlayer.stop();
      setState(() {
        _currentlyPlayingUrl = url;
      });
      await _audioPlayer.play(UrlSource(url));
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _glowController.dispose();
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
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordedAudioPath = path;
      });
      return;
    }

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

  // --- إرسال الرسائل (نص أو صوت) مع تأمين الاستلام ومعالجة الـ Timeout ---
  Future<void> _sendMessage() async {
    final textMessage = _messageController.text.trim();
    final hasAudio = _recordedAudioPath != null;

    if (textMessage.isEmpty && !hasAudio) return;

    final userMsgText = hasAudio ? "🎤 [رسالة صوتية]" : textMessage;

    setState(() {
      _messages.add({
        "sender": "user",
        "text": userMsgText,
        "isAudio": hasAudio,
        "audioPath": _recordedAudioPath,
      });
      _isLoading = true;
    });

    // حفظ رسالة المستخدم في الهيستوري
    _saveMessageToFirestore(
      sender: "user",
      text: userMsgText,
      isAudio: hasAudio,
    );

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
        var request = http.MultipartRequest("POST", url);
        request.headers.addAll({
          'Accept': 'application/json',
        });

        request.fields['uid'] = widget.uid;
        request.fields['role'] = widget.role;
        if (textMessage.isNotEmpty) {
          request.fields['message'] = textMessage;
        }

        final file = await http.MultipartFile.fromPath(
          'file',
          audioToSend!,
          contentType: MediaType('audio', 'm4a'),
        );
        request.files.add(file);

        var streamedResponse = await request.send().timeout(
          const Duration(seconds: 45),
          onTimeout: () {
            throw TimeoutException("استغرقت الاستجابة وقتاً أطول من المتوقع.");
          },
        );
        response = await http.Response.fromStream(streamedResponse);
      } else {
        response = await http.post(
          url,
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "uid": widget.uid,
            "role": widget.role,
            "message": textMessage,
          }),
        ).timeout(
          const Duration(seconds: 45),
          onTimeout: () {
            throw TimeoutException("استغرقت الاستجابة وقتاً أطول من المتوقع.");
          },
        );
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // تأمين وتصفية الاستجابة لمنع عرض نصوص الأخطاء الخام
        String reply = data["message"] ?? data["reply"] ?? "";
        if (reply.isEmpty) {
  reply = "تم استلام الطلب وبانتظار رد المساعد، يرجى المحاولة مرة أخرى.";
}

        final audioUrl = data["audioUrl"];
        final fileData = data["file"];

        setState(() {
          _messages.add({
            "sender": "bot",
            "text": reply,
            "audioUrl": audioUrl,
            "file": fileData,
          });
        });

        // حفظ رد الباك إند في الهيستوري
        _saveMessageToFirestore(
          sender: "bot",
          text: reply,
          audioUrl: audioUrl,
          file: fileData,
        );

        // تشغيل صوت Gemini TTS الأصلي القادم من الخادم فور استلامه
        if (audioUrl != null && audioUrl.toString().isNotEmpty) {
          _playGeminiAudio(audioUrl);
        }
      } else if (response.statusCode == 504) {
        setState(() {
          _messages.add({
            "sender": "bot",
            "text": "انتهت مهلة الاتصال بالخادم (504). جاري معالجة الطلب، يرجى إعادة المحاولة."
          });
        });
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
          "text": "عذراً، حدث خطأ أثناء الاتصال: ${e is TimeoutException ? 'استغرقت الاستجابة وقتاً طويلاً' : 'تعذر الاتصال بالخادم'}"
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
    // زيادة المسافة العلوية لتقصير النافذة وإظهار جزء واضح من هيدر التطبيق الأصلي
    final topPadding = MediaQuery.of(context).size.height * 0.18;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black.withOpacity(0.4), // خلفية شبه شفافة لخلق انطباع Sheet
        body: Padding(
          padding: EdgeInsets.only(top: topPadding),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0F131C), // خلفية جيمناي المظلمة الفاخرة
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 25,
                  spreadRadius: 5,
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              child: Stack(
                children: [
                  // خلفية إضاءة جيمناي المتدرجة الحركية (Gemini Mesh Glow Effect)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment(
                                0.7 * (1 - _glowController.value * 2),
                                -0.8,
                              ),
                              radius: 1.2,
                              colors: const [
                                Color(0x334285F4), // جوجل أزرق شفاف
                                Color(0x229B51E0), // بنفسجي متوهج
                                Color(0x000F131C), // دمج مع الخلفية
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  Column(
                    children: [
                      // مقبض السحب وتكتيك الهيدر المزدوج
                      _buildHeader(context),

                      // منطقة المحادثات والأصناف
                      Expanded(
                        child: _isFetchingHistory
                            ? const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF8AB4F8)),
                                ),
                              )
                            : _messages.isEmpty
                                ? _buildGeminiWelcomeState()
                                : ListView.builder(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    itemCount: _messages.length,
                                    itemBuilder: (context, index) {
                                      final msg = _messages[index];
                                      final isUser = msg["sender"] == "user";
                                      return _buildMessageBubble(
                                        text: msg["text"],
                                        isUser: isUser,
                                        isAudio: msg["isAudio"] ?? false,
                                        audioUrl: msg["audioUrl"],
                                        fileData: msg["file"],
                                      );
                                    },
                                  ),
                      ),

                      // مؤشر التحميل بتأثير توهج ذكي
                      if (_isLoading)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF8AB4F8)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [Color(0xFF8AB4F8), Color(0xFFC084FC)],
                                ).createShader(bounds),
                                child: const Text(
                                  "شيرا تفكر الآن...",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),

                      // شريط الإدخال العائم الأنيق
                      _buildInputArea(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // هيدر بمقبض سحب علوي وأزرار تحكم متميزة
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0x1FA0AAB8), width: 0.8),
        ),
      ),
      child: Column(
        children: [
          // مقبض السحب العلوي (Sheet Handle Bar)
          Container(
            width: 38,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.grey.shade600.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // آيكون الأيقونة النجمية لجيمناي
              AnimatedBuilder(
                animation: _glowController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: const [Color(0xFF1E88E5), Color(0xFF9C27B0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        transform: GradientRotation(_glowController.value * 6.28),
                      ),
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  );
                },
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    "شيرا الذكية (Shira AI)",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    "مساعد إدارة العهدة والاستفسارات",
                    style: TextStyle(color: Color(0xFF9AA0A6), fontSize: 11.5),
                  ),
                ],
              ),
              const Spacer(),
              // زر إغلاق شيك وأنيق للعودة للتطبيق
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFFE8EAED), size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // واجهة الترحيب الخاطفة عند فتح الشات لأول مرة (Gemini Intro)
  Widget _buildGeminiWelcomeState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF4285F4), Color(0xFF9B51E0), Color(0xFFE91E63)],
              ).createShader(bounds),
              child: const Icon(Icons.auto_awesome, size: 56, color: Colors.white),
            ),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.white, Color(0xFFC8D6E5)],
              ).createShader(bounds),
              child: const Text(
                "أهلاً بك، أنا شيرا!",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "كيف يمكنني مساعدتك في متابعة عهدتك أو الاستفسار عن المنتجات اليوم؟",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9AA0A6), fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 24),
            // مقترحات نقر سريعة Quick Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickActionChip("ما هي العروض المتاحة؟"),
                _buildQuickActionChip("استفسار عن الكاش باك"),
                _buildQuickActionChip("مراجعة حالة العهدة"),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionChip(String label) {
    return InkWell(
      onTap: () {
        _messageController.text = label;
        _sendMessage();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2330),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x28A0AAB8)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Color(0xFFE8EAED), fontSize: 12.5),
        ),
      ),
    );
  }

  // تصميم فقاعة المحادثة المستقبلية
  Widget _buildMessageBubble({
    required String text,
    required bool isUser,
    bool isAudio = false,
    String? audioUrl,
    Map<String, dynamic>? fileData,
  }) {
    final bool isThisPlaying = _isPlayingAudio && _currentlyPlayingUrl == audioUrl;

    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                )
              : null,
          color: isUser ? null : const Color(0xFF1E2330),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 4 : 20),
            bottomRight: Radius.circular(isUser ? 20 : 4),
          ),
          border: isUser ? null : Border.all(color: const Color(0x1FA0AAB8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(0, 3),
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
                      size: 18, color: isUser ? Colors.white : const Color(0xFF8AB4F8)),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.45,
                      color: isUser ? Colors.white : const Color(0xFFE8EAED),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                if (!isUser && audioUrl != null && audioUrl.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _playGeminiAudio(audioUrl),
                    child: Icon(
                      isThisPlaying ? Icons.stop_circle_rounded : Icons.play_circle_fill_rounded,
                      size: 24,
                      color: const Color(0xFF8AB4F8),
                    ),
                  ),
                ],
              ],
            ),
            if (fileData != null && fileData["url"] != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x1F8AB4F8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.insert_drive_file, color: Color(0xFF8AB4F8), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileData["name"] ?? "تحميل التقرير",
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8AB4F8),
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

  // تصميم منطقة الإدخال السفلية العائمة بأسلوب جيمناي الحديث
  Widget _buildInputArea() {
    final bool hasText = _messageController.text.trim().isNotEmpty;
    final bool hasAudioReady = _recordedAudioPath != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF0F131C),
      ),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1E2330),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x28A0AAB8)),
          ),
          child: Row(
            children: [
              // زر الميكروفون
              GestureDetector(
                onTap: _handleMicrophonePermissionAndRecord,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.red.withOpacity(0.2) : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_circle : Icons.mic_rounded,
                    color: _isRecording ? Colors.redAccent : const Color(0xFF8AB4F8),
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 4),

              // حقل النص أو حالة التسجيل
              Expanded(
                child: _isRecording
                    ? Row(
                        children: const [
                          Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 12),
                          SizedBox(width: 8),
                          Text(
                            "جاري تسجيل الصوت...",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : hasAudioReady
                        ? Row(
                            children: [
                              const Icon(Icons.audio_file, color: Color(0xFF8AB4F8), size: 18),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  "صوت جاهز للإرسال",
                                  style: TextStyle(fontSize: 13.5, color: Colors.white),
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
                            style: const TextStyle(fontSize: 14.5, color: Colors.white),
                            decoration: const InputDecoration(
                              hintText: "اسأل شيرا أي شيء...",
                              hintStyle: TextStyle(color: Color(0xFF9AA0A6), fontSize: 13.5),
                              border: InputBorder.none,
                            ),
                          ),
              ),

              const SizedBox(width: 6),

              // زر الإرسال المتوهج
              InkWell(
                onTap: (hasText || hasAudioReady) && !_isLoading ? _sendMessage : null,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: (hasText || hasAudioReady) && !_isLoading
                        ? const LinearGradient(
                            colors: [Color(0xFF4285F4), Color(0xFF9B51E0)],
                          )
                        : null,
                    color: (hasText || hasAudioReady) && !_isLoading
                        ? null
                        : const Color(0xFF2D323F),
                  ),
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}