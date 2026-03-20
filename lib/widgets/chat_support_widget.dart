import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sizer/sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart'; // مكتبة فتح الروابط

class ChatSupportWidget extends StatefulWidget {
  const ChatSupportWidget({super.key});

  @override
  State<ChatSupportWidget> createState() => _ChatSupportWidgetState();
}

class _ChatSupportWidgetState extends State<ChatSupportWidget> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  final String apiGatewayUrl = "https://st6zcrb8k1.execute-api.us-east-1.amazonaws.com/dev/chat";

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
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
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 🚀 دالة ذكية لجلب بيانات العميل + الإحداثيات من الفايرستور
  Future<Map<String, dynamic>> _getUserDetails(String uid) async {
    Map<String, dynamic> results = {
      "userName": "عميل أكسب",
      "role": "guest",
      "userPhone": "N/A",
      "location": null // سيتم ملؤه من deliverySupermarkets
    };

    try {
      // 1. جلب بيانات الموقع من كولكشن السوبر ماركت
      // التصحيح:
var supermarketDoc = await FirebaseFirestore.instance
    .collection('deliverySupermarkets')
    .where('ownerId', isEqualTo: uid) // استخدم isEqualTo بدل الفواصل و '=='
    .limit(1)
    .get();


      if (supermarketDoc.docs.isNotEmpty) {
        var data = supermarketDoc.docs.first.data();
        results["location"] = data['location']; // يرسل {lat: ..., lng: ...} كما في الصورة
        results["address"] = data['address'];
      }

      // 2. جلب البيانات الشخصية (الاسم والدور)
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
    } catch (e) {
      debugPrint("Error fetching user details: $e");
    }
    return results;
  }

  // 🔗 دالة فتح روابط الواتساب أو المواقع
  Future<void> _launchURL(String text) async {
    final RegExp urlRegExp = RegExp(r'(https?:\/\/[^\s]+)');
    final String? url = urlRegExp.stringMatch(text);
    
    if (url != null) {
      final Uri uri = Uri.parse(url);
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } catch (e) {
        debugPrint("Could not launch $url");
      }
    }
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
        },
        body: json.encode({
          "message": text,
          "userId": user.uid,
          "userName": userDetails['userName'],
          "role": userDetails['role'],
          "userPhone": userDetails['userPhone'],
          "location": userDetails['location'], // إرسال الإحداثيات للامدا
          "address": userDetails['address'], // إرسال العنوان النصي للمساعدة في الفلترة
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String botReply = data['message'] ?? "لا يوجد رد حالياً.";
        
        setState(() {
          _messages.add({"role": "bot", "text": botReply});
        });

        // ⚡ إذا كان الرد يحتوي على رابط واتساب، افتحه تلقائياً
        if (botReply.contains("wa.me") || botReply.contains("wa.link")) {
          _launchURL(botReply);
        }

        await _saveChatHistory();
      }
    } catch (e) {
      setState(() {
        _messages.add({"role": "bot", "text": "عذراً يا فنان، واجهت مشكلة في الاتصال بالسيرفر."});
      });
    } finally {
      setState(() => _isTyping = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88.h,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  color: Colors.grey.withOpacity(0.02),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final msg = _messages[i];
                      return _buildMessageBubble(msg['text']!, msg['role'] == 'user');
                    },
                  ),
                ),
              ),
              if (_isTyping) _buildTypingIndicator(),
              SafeArea(top: false, child: _buildInputSection()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(top: 1.5.h, bottom: 2.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          Container(
            width: 50, height: 6,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
          ),
          SizedBox(height: 2.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xff28a745),
                radius: 14,
                child: Icon(Icons.bolt, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                "دعم أكسب الذكي",
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w900, 
                  color: const Color(0xff1a4d2e),
                  fontFamily: 'Cairo'
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => _launchURL(text), // فتح الروابط عند الضغط على الفقاعة
        child: Container(
          constraints: BoxConstraints(maxWidth: 82.w),
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          decoration: BoxDecoration(
            gradient: isUser 
              ? const LinearGradient(colors: [Color(0xff28a745), Color(0xff218838)])
              : null,
            color: isUser ? null : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(25),
              topRight: const Radius.circular(25),
              bottomLeft: Radius.circular(isUser ? 25 : 5),
              bottomRight: Radius.circular(isUser ? 5 : 25),
            ),
            boxShadow: [
              BoxShadow(
                color: isUser ? Colors.green.withOpacity(0.2) : Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 6)
              ),
            ],
            border: isUser ? null : Border.all(color: Colors.grey.shade100),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15.sp,
              height: 1.4,
              fontWeight: FontWeight.w600,
              fontFamily: 'Cairo',
              color: isUser ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: EdgeInsets.only(left: 6.w, bottom: 2.h),
      child: Row(
        children: [
          const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.green),
          ),
          const SizedBox(width: 12),
          Text("يتم الآن معالجة طلبك...", 
            style: TextStyle(fontSize: 12.sp, color: Colors.grey[700], fontFamily: 'Cairo', fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: EdgeInsets.only(
        left: 5.w, right: 5.w, top: 2.h,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 
            ? MediaQuery.of(context).viewInsets.bottom + 1.h 
            : 2.h, 
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, -5))]
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: TextStyle(fontSize: 15.sp, fontFamily: 'Cairo'),
              decoration: InputDecoration(
                hintText: "اكتب استفسارك هنا...",
                hintStyle: TextStyle(fontSize: 13.sp, color: Colors.grey[400], fontFamily: 'Cairo'),
                filled: true,
                fillColor: Colors.grey[50],
                contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 18),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Color(0xff28a745), width: 2)),
              ),
            ),
          ),
          SizedBox(width: 3.w),
          InkWell(
            onTap: _sendMessage,
            borderRadius: BorderRadius.circular(35),
            child: Container(
              height: 60, width: 60,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xff28a745), Color(0xff1a4d2e)]),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }
}
