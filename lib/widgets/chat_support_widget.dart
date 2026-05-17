import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sizer/sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // المكتبة الحديثة لتنسيق الردود بذكاء

class ChatSupportWidget extends StatefulWidget {
  const ChatSupportWidget({super.key});

  @override
  State<ChatSupportWidget> createState() => _ChatSupportWidgetState();
}

class _ChatSupportWidgetState extends State<ChatSupportWidget> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  
  // ✅ الرابط الرسمي والمؤكد المأخوذ من الفايربيس كونسول مباشرة
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
        _messages = List<Map<String, String>>.from(
          json.decode(cachedData).map((item) => Map<String, String>.from(item))
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
          "uid": user.uid, // ✅ حقل برمي أساسي مطابق للباك-إند
          "userName": userDetails['userName'],
          "role": userDetails['role'], 
          "userPhone": userDetails['userPhone'],
          "location": userDetails['location'], 
          "address": userDetails['address'],
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String botReply = data['message'] ?? "أنا هنا لمساعدتك عينات العهدة جاهزة.";
        setState(() => _messages.add({"role": "bot", "text": botReply}));
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), // زيادة التأثير الزجاجي الفخم لمظهر متناسق
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
                    itemBuilder: (context, i) => _buildMessageBubble(_messages[i]['text']!, _messages[i]['role'] == 'user'),
                  ),
                ),
                if (_isTyping) _buildTypingIndicator(),
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
                  Text("شـيرا | Shira AI", style: TextStyle(fontSize: 15.0.sp, fontWeight: FontWeight.w900, color: const Color(0xff1a237e), fontFamily: 'Cairo')),
                  Text("إدارة العهدة والخدمات اللوجستية الذكية", style: TextStyle(fontSize: 8.8.sp, fontWeight: FontWeight.w700, color: Colors.black54, fontFamily: 'Cairo')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) _buildBotAvatar(),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                // مظهر زجاجي كحلي للمستخدم، ومظهر زجاجي أبيض مصنفر لـ شيرا مع ظلال ناعمة
                color: isUser ? const Color(0xff1a237e).withOpacity(0.88) : Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(isUser ? 22 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 22),
                ),
                border: Border.all(
                  color: isUser ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.7),
                  width: 1.2
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03), 
                    blurRadius: 6, 
                    offset: const Offset(0, 3)
                  )
                ],
              ),
              child: isUser 
                  ? Text(
                      text,
                      style: TextStyle(
                        fontSize: 13.5.sp, // تكبير الخط ليكون مريح وواضح جداً للمستخدم
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Cairo',
                        color: Colors.white,
                        height: 1.45,
                      ),
                    )
                  : MarkdownBody( // تحويل رد شيرا لـ Markdown لمعالجة النجوم المزدوجة باحترافية
                      data: text,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(
                          fontSize: 14.0.sp, // خط شيرا كبير ومقروء بوضوح في شاشة الموبايل
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Cairo',
                          color: Colors.black87,
                          height: 1.55, // تباعد أسطر ممتاز ومريح يمنع تداخل الكلمات اللوجستية
                        ),
                        strong: TextStyle(
                          fontSize: 14.5.sp, 
                          fontWeight: FontWeight.w800, // إعطاء سمك ممتاز للكلمات الفنية والعهد اللوجستية
                          fontFamily: 'Cairo',
                          color: const Color(0xff1a237e), // تمييز نقاط التأمين والعهد بلون الهوية الكحلي
                        ),
                      ),
                    ),
            ),
          ),
          if (isUser) const SizedBox(width: 5),
        ],
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

  Widget _buildTypingIndicator() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.2.h),
      child: Row(
        children: [
          const SizedBox(
            width: 16, 
            height: 16, 
            child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xff1a237e))
          ),
          const SizedBox(width: 12),
          Text(
            "تحديث حالة العهدة والبيانات...", 
            style: TextStyle(fontSize: 10.0.sp, fontWeight: FontWeight.w700, color: Colors.blueGrey[800], fontFamily: 'Cairo')
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 3.5.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55), 
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.45), width: 1.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 11.5.sp),
              decoration: InputDecoration(
                hintText: "استفسر عن نقاط التأمين أو حالة الشحنة...",
                hintStyle: TextStyle(color: Colors.black38, fontSize: 10.8.sp),
                filled: true,
                fillColor: Colors.white.withOpacity(0.85), 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xff1a237e).withOpacity(0.92), 
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: const Color(0xff1a237e).withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 25),
            ),
          ),
        ],
      ),
    );
  }
}