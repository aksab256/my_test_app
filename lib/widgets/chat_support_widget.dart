import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sizer/sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart'; // مكتبة فتح رابط الملف (فتح/تحميل التقرير)

class ChatSupportWidget extends StatefulWidget {
  const ChatSupportWidget({super.key});

  @override
  State<ChatSupportWidget> createState() => _ChatSupportWidgetState();
}

class _ChatSupportWidgetState extends State<ChatSupportWidget> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ✅ Map<String, dynamic> بدل String عشان تقدر تحمل بيانات ملف (fileUrl/fileName) لرسائل شيرا
  List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  final String apiGatewayUrl = "https://shirachat-tmfag3rhdq-uc.a.run.app";

  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _saveChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('chat_cache', json.encode(_messages));
  }

  Future<void> _loadChatHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('chat_cache');
    if (cachedData != null) {
      setState(() {
        _messages = List<Map<String, dynamic>>.from(
          json.decode(cachedData).map((item) => Map<String, dynamic>.from(item)),
        );
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutQuart,
        );
      }
    });
  }

  Future<Map<String, dynamic>> _getUserDetails(String uid) async {
    Map<String, dynamic> results = {"userName": "عميل شـيرا", "role": "guest", "userPhone": "N/A", "location": null};
    try {
      var supermarketDoc = await FirebaseFirestore.instance.collection('deliverySupermarkets').where('ownerId', isEqualTo: uid).limit(1).get();
      if (supermarketDoc.docs.isNotEmpty) {
        var data = supermarketDoc.docs.first.data();
        results["location"] = data['location'];
        results["address"] = data['address'];
      }
      List<String> collections = ['consumers', 'sellers', 'users'];
      for (var col in collections) {
        var doc = await FirebaseFirestore.instance.collection(col).doc(uid).get();
        if (doc.exists) {
          var data = doc.data()!;
          results["userName"] = data['fullname'] ?? data['merchantName'] ?? results["userName"];
          results["role"] = data['role'] ?? col;
          results["userPhone"] = data['phone'] ?? "N/A";
          break;
        }
      }
    } catch (e) { debugPrint("Error: $e"); }
    return results;
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _messages.add({"role": "user", "text": text});
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();
    await _saveChatHistory();

    try {
      final userDetails = await _getUserDetails(user.uid);
      final idToken = await user.getIdToken();

      final response = await http.post(
        Uri.parse(apiGatewayUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
          'X-User-UID': user.uid
        },
        body: json.encode({
          "message": text,
          "uid": user.uid,
          "userName": userDetails['userName'],
          "role": userDetails['role'],
          "userPhone": userDetails['userPhone'],
          "location": userDetails['location'],
          "address": userDetails['address'],
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String botReply = data['message'] ?? "أنا هنا لمساعدتك، عمليات العهدة جاهزة.";

        // ✅ لو الباك إند رجع بيانات ملف (تقرير Excel/CSV)، نضيفها لنفس الرسالة
        final Map<String, dynamic>? fileData = data['file'];

        setState(() => _messages.add({
              "role": "bot",
              "text": botReply,
              if (fileData != null) "fileUrl": fileData['url'],
              if (fileData != null) "fileName": fileData['name'],
              if (fileData != null) "fileType": fileData['type'],
            }));
        _scrollToBottom();
        await _saveChatHistory();
      } else {
        setState(() => _messages.add({"role": "bot", "text": "شـيرا تواجه صعوبة في تحليل البيانات حالياً."}));
      }
    } catch (e) {
      setState(() => _messages.add({"role": "bot", "text": "عذراً يا غالي، واجهت مشكلة في الاتصال بالسيرفر."}));
    } finally {
      setState(() => _isTyping = false);
      _scrollToBottom();
    }
  }

  Future<void> _openFile(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("تعذر فتح رابط الملف: $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        height: 88.h,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.72),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
          border: Border.all(color: Colors.white.withOpacity(0.45), width: 1.5),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 35, spreadRadius: 5)
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final msg = _messages[i];
                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutBack,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, (1 - value) * 15),
                              child: child,
                            ),
                          );
                        },
                        child: _buildMessageBubble(msg),
                      );
                    },
                  ),
                ),
                if (_isTyping) _buildCustomTypingIndicator(),
                _buildInputSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 1.8.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.35),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.4), width: 1.2)),
      ),
      child: Column(
        children: [
          Container(width: 45, height: 5, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10))),
          SizedBox(height: 1.5.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 58, height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xff1a237e).withOpacity(0.12), blurRadius: 12)],
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/images/shira_logo.png', fit: BoxFit.contain),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("شـيرا | Shira AI", style: TextStyle(fontSize: 16.0.sp, fontWeight: FontWeight.w900, color: const Color(0xff1a237e), fontFamily: 'Cairo')),
                  Text("إدارة العهدة والخدمات اللوجستية الذكية", style: TextStyle(fontSize: 9.5.sp, fontWeight: FontWeight.w700, color: Colors.black54, fontFamily: 'Cairo')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final bool isUser = msg['role'] == 'user';
    final String text = msg['text'] ?? '';
    final String? fileUrl = msg['fileUrl'];
    final String? fileName = msg['fileName'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) _buildBotAvatar(),
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  decoration: BoxDecoration(
                    color: isUser ? const Color(0xff1a237e).withOpacity(0.88) : Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(22),
                      topRight: const Radius.circular(22),
                      bottomLeft: Radius.circular(isUser ? 22 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 22),
                    ),
                    border: Border.all(
                      color: isUser ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.7),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 3))
                    ],
                  ),
                  child: isUser
                      ? Text(
                          text,
                          style: TextStyle(
                            fontSize: 14.5.sp,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Cairo',
                            color: Colors.white,
                            height: 1.45,
                          ),
                        )
                      : MarkdownBody(
                          data: text,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              fontSize: 15.0.sp,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Cairo',
                              color: Colors.black87,
                              height: 1.55,
                            ),
                            strong: TextStyle(
                              fontSize: 15.5.sp,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Cairo',
                              color: const Color(0xff1a237e),
                            ),
                          ),
                        ),
                ),
                // ✅ بطاقة الملف (File Chip) - بتظهر بس لو الرسالة معاها تقرير جاهز
                if (fileUrl != null) ...[
                  const SizedBox(height: 6),
                  _buildFileChip(fileUrl, fileName ?? 'التقرير'),
                ],
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 5),
        ],
      ),
    );
  }

  // بطاقة ملف تفاعلية لعرض التقرير القابل للتحميل/الفتح
  Widget _buildFileChip(String url, String fileName) {
    return GestureDetector(
      onTap: () => _openFile(url),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.table_view_rounded, color: Colors.green, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.download_rounded, color: Colors.green, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBotAvatar() {
    return Padding(
      padding: const EdgeInsets.only(left: 0, right: 10, bottom: 2),
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xff1a237e).withOpacity(0.18)),
        ),
        child: ClipOval(
          child: Image.asset('assets/images/shira_logo.png', fit: BoxFit.contain),
        ),
      ),
    );
  }

  Widget _buildCustomTypingIndicator() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildBotAvatar(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: const BorderRadius.all(Radius.circular(20)),
              border: Border.all(color: Colors.white.withOpacity(0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2.0, color: Color(0xff1a237e)),
                ),
                const SizedBox(width: 12),
                Text(
                  "شـيرا تحلل وتحدث بيانات العهدة...",
                  style: TextStyle(fontSize: 11.5.sp, fontWeight: FontWeight.w700, color: const Color(0xff1a237e), fontFamily: 'Cairo'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      margin: EdgeInsets.only(left: 4.w, right: 4.w, bottom: 3.0.h, top: 0.8.h),
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(35),
        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textDirection: TextDirection.rtl,
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 15.0, color: Colors.black87),
              decoration: InputDecoration(
                hintText: "استفسر عن نقاط التأمين أو حالة الشحنة...",
                hintTextDirection: TextDirection.rtl,
                hintStyle: const TextStyle(color: Colors.black38, fontSize: 13.5, fontFamily: 'Cairo'),
                filled: true,
                fillColor: Colors.transparent,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, child) {
              final hasText = value.text.trim().isNotEmpty;
              return AnimatedScale(
                scale: hasText ? 1.0 : 0.9,
                duration: const Duration(milliseconds: 200),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    color: hasText ? const Color(0xff1a237e) : Colors.grey[400],
                    shape: BoxShape.circle,
                    boxShadow: hasText
                        ? [BoxShadow(color: const Color(0xff1a237e).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                        : [],
                  ),
                  child: GestureDetector(
                    onTap: _sendMessage,
                    child: const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Icon(Icons.send_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}