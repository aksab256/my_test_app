// lib/widgets/chat_support_widget.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sizer/sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final String apiGatewayUrl = "https://st6zcrb8k1.execute-api.us-east-1.amazonaws.com/dev/chat";

  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadChatHistory();
    
    // أنميشن النبض لتعزيز الهوية البصرية لشـيرا
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
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
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $idToken'},
        body: json.encode({
          "message": text, "userId": user.uid, "userName": userDetails['userName'],
          "role": userDetails['role'], "userPhone": userDetails['userPhone'],
          "location": userDetails['location'], "address": userDetails['address'],
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String botReply = data['message'] ?? "أنا هنا لمساعدتك.";
        setState(() => _messages.add({"role": "bot", "text": botReply}));
        _scrollToBottom();
        await _saveChatHistory();
      }
    } catch (e) {
      setState(() => _messages.add({"role": "bot", "text": "عذراً، شـيرا واجهت مشكلة في الاتصال."}));
    } finally {
      setState(() => _isTyping = false);
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        height: 85.h,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 25, spreadRadius: 5)],
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
                    padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
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
      padding: EdgeInsets.symmetric(vertical: 2.5.h),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.black12, width: 0.5)),
      ),
      child: Column(
        children: [
          Container(width: 45, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          SizedBox(height: 2.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: const Color(0xff1a237e).withOpacity(0.15), blurRadius: 10)],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/shira_logo.png',
                      height: 60,
                      width: 60,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: const Color(0xff1a237e).withOpacity(0.1),
                        child: const Icon(Icons.auto_awesome, size: 35, color: Color(0xff1a237e)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("شـيرا | Shira AI", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: const Color(0xff1a237e), fontFamily: 'Cairo')),
                  Text("المساعد الذكي لشركة شـيرا", style: TextStyle(fontSize: 9.sp, color: Colors.grey[600], fontFamily: 'Cairo')),
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
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 5),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xff1a237e).withOpacity(0.1), width: 1),
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/shira_logo.png',
                    height: 35,
                    width: 35,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 35, height: 35,
                      color: const Color(0xff1a237e),
                      child: const Icon(Icons.smart_toy_outlined, size: 20, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xff1a237e) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 5),
                  bottomRight: Radius.circular(isUser ? 5 : 20),
                ),
                boxShadow: [if(!isUser) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 3))],
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11.5.sp, 
                  fontWeight: FontWeight.w600, 
                  fontFamily: 'Cairo', 
                  color: isUser ? Colors.white : Colors.black87,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
      child: Row(
        children: [
          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xff1a237e))),
          const SizedBox(width: 12),
          Text("شـيرا تحلل طلبك الآن...", style: TextStyle(fontSize: 10.sp, color: Colors.grey[500], fontFamily: 'Cairo', fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: EdgeInsets.fromLTRB(4.w, 1.5.h, 4.w, 3.5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: "كيف يمكن لشـيرا مساعدتك؟",
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 11.sp),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _sendMessage,
            child: CircleAvatar(
              backgroundColor: const Color(0xff1a237e),
              radius: 26,
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

