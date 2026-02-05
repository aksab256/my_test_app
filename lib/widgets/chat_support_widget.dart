import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sizer/sizer.dart';

class ChatSupportWidget extends StatefulWidget {
  const ChatSupportWidget({super.key});

  @override
  State<ChatSupportWidget> createState() => _ChatSupportWidgetState();
}

class _ChatSupportWidgetState extends State<ChatSupportWidget> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _isTyping = false;
  final String apiGatewayUrl = "https://st6zcrb8k1.execute-api.us-east-1.amazonaws.com/dev/chat";

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

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"role": "user", "text": text});
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      final response = await http.post(
        Uri.parse(apiGatewayUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: json.encode({"message": text}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _messages.add({"role": "bot", "text": data['message'] ?? "لا يوجد رد حالياً."});
        });
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
      height: 88.h, // زيادة الارتفاع قليلاً لشكل أفضل
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
              _buildInputSection(),
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
            width: 50,
            height: 6,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
          ),
          SizedBox(height: 2.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                backgroundColor: Color(0xff28a745),
                radius: 12,
                child: Icon(Icons.bolt, color: Colors.white, size: 15),
              ),
              const SizedBox(width: 10),
              Text(
                "دعم أكسب الذكي",
                style: TextStyle(
                  fontSize: 16.sp, 
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
      child: Container(
        constraints: BoxConstraints(maxWidth: 80.w),
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          gradient: isUser 
            ? const LinearGradient(colors: [Color(0xff28a745), Color(0xff218838)])
            : null,
          color: isUser ? null : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(isUser ? 22 : 5),
            bottomRight: Radius.circular(isUser ? 5 : 22),
          ),
          boxShadow: [
            BoxShadow(
              color: isUser ? Colors.green.withOpacity(0.2) : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5)
            ),
          ],
          border: isUser ? null : Border.all(color: Colors.grey.shade100),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13.sp, // خط كبير وواضح
            height: 1.5,
            fontWeight: FontWeight.w600,
            fontFamily: 'Cairo',
            color: isUser ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: EdgeInsets.only(left: 6.w, bottom: 1.5.h),
      child: Row(
        children: [
          const SizedBox(
            width: 12, height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
          ),
          const SizedBox(width: 10),
          Text("يتم الآن معالجة طلبك...", 
            style: TextStyle(fontSize: 10.sp, color: Colors.grey[600], fontFamily: 'Cairo', fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildInputSection() {
    return Container(
      padding: EdgeInsets.only(
        left: 5.w, right: 5.w, top: 2.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 3.h,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, -5))]
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, spreadRadius: 1)]
              ),
              child: TextField(
                controller: _controller,
                style: TextStyle(fontSize: 13.sp, fontFamily: 'Cairo'),
                decoration: InputDecoration(
                  hintText: "اكتب استفسارك هنا...",
                  hintStyle: TextStyle(fontSize: 12.sp, color: Colors.grey[400], fontFamily: 'Cairo'),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: const BorderSide(color: Color(0xff28a745), width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 3.w),
          InkWell(
            onTap: _sendMessage,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              height: 55, width: 55,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xff28a745), Color(0xff1a4d2e)]),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}
