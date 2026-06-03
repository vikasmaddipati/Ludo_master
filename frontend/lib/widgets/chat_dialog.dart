import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/chat_message.dart';
import '../services/accessibility_service.dart';
import 'package:intl/intl.dart';
import 'dart:math';

class ChatDialog extends StatefulWidget {
  final List<ChatMessage> messages;
  final String myName;
  final Function(String, bool, String) onSendMessage;

  const ChatDialog({
    super.key,
    required this.messages,
    required this.myName,
    required this.onSendMessage,
  });

  @override
  State<ChatDialog> createState() => _ChatDialogState();
}

class _ChatDialogState extends State<ChatDialog> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _quickEmojis = ['😂', '🔥', '😮', '😢', '👍', '👑', '🎉', '🤡', '🎲', '😜', '💪', '😡'];
  final List<String> _quickTexts = [
    'Good game!',
    'Nice move!',
    'Oops! 😅',
    'Roll a six! 🎲',
    'Hurry up! ⏳',
    'Unlucky! 😢',
    'Well played!',
    'OMG!'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 480,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
      ),
      child: Column(
        children: [
          // Premium drag indicator bar
          Center(
            child: Container(
              width: 50,
              height: 5,
              margin: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          
          // Emojis Quick Picker (horizontal premium scroller)
          Container(
            height: 48,
            padding: const EdgeInsets.only(bottom: 6),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickEmojis.length,
              itemBuilder: (context, index) {
                final emoji = _quickEmojis[index];
                return GestureDetector(
                  onTap: () {
                    AccessibilityService.instance.triggerHaptic(intensity: 'light');
                    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
                    widget.onSendMessage(emoji, true, msgId);
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Text(
                      emoji, 
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          
          // Real-time Chat Conversation History list
          Expanded(
            child: widget.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, color: AppColors.textSecondary.withOpacity(0.3), size: 40),
                        const SizedBox(height: 12),
                        const Text(
                          'No messages yet. Start the conversation!',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(18),
                    itemCount: widget.messages.length,
                    itemBuilder: (context, index) {
                      final msg = widget.messages[index];
                      final isMe = msg.senderName == widget.myName;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe) ...[
                              CircleAvatar(
                                radius: 15,
                                backgroundColor: AppColors.primary.withOpacity(0.2),
                                child: Text(
                                  msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : 'P',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Flexible(
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  // Sender Name & Timestamp Details
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          isMe ? 'You' : msg.senderName,
                                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          DateFormat('HH:mm').format(msg.timestamp),
                                          style: TextStyle(fontSize: 9, color: AppColors.textSecondary.withOpacity(0.5)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Chat bubble details
                                  Container(
                                    padding: msg.isEmoji 
                                        ? const EdgeInsets.all(2) 
                                        : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      gradient: msg.isEmoji
                                          ? null
                                          : (isMe
                                              ? const LinearGradient(
                                                  colors: [AppColors.primary, AppColors.secondary],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                              : null),
                                      color: msg.isEmoji
                                          ? Colors.transparent
                                          : (isMe ? null : AppColors.surfaceLight),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                                        bottomRight: Radius.circular(isMe ? 4 : 16),
                                      ),
                                      border: msg.isEmoji
                                          ? null
                                          : Border.all(
                                              color: isMe 
                                                  ? Colors.white.withOpacity(0.15) 
                                                  : Colors.white.withOpacity(0.04),
                                              width: 1,
                                            ),
                                    ),
                                    child: Text(
                                      msg.message,
                                      style: TextStyle(
                                        fontSize: msg.isEmoji ? 42 : 14,
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  
                                  // Delivery Status indicator
                                  if (isMe && !msg.isEmoji) ...[
                                    const SizedBox(height: 2),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          msg.isDelivered ? 'Delivered' : 'Sending...',
                                          style: TextStyle(
                                            fontSize: 8, 
                                            color: msg.isDelivered ? AppColors.secondary : AppColors.textSecondary.withOpacity(0.5)
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Icon(
                                          msg.isDelivered ? Icons.done_all : Icons.done,
                                          size: 10,
                                          color: msg.isDelivered ? AppColors.secondary : AppColors.textSecondary.withOpacity(0.4),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isMe) const SizedBox(width: 6),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          
          // Predefined Quick texts scroller (chips format)
          Container(
            height: 38,
            padding: const EdgeInsets.only(bottom: 4),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _quickTexts.length,
              itemBuilder: (context, index) {
                final txt = _quickTexts[index];
                return GestureDetector(
                  onTap: () {
                    AccessibilityService.instance.triggerHaptic(intensity: 'light');
                    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
                    widget.onSendMessage(txt, false, msgId);
                    _scrollToBottom();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.secondary.withOpacity(0.2)),
                    ),
                    child: Center(
                      child: Text(
                        txt, 
                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Custom Text Chat inputs
          Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      fillColor: AppColors.surfaceLight,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide(color: Colors.white.withOpacity(0.04)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(color: AppColors.secondary, width: 1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    if (_messageController.text.trim().isNotEmpty) {
                      AccessibilityService.instance.triggerHaptic(intensity: 'medium');
                      final text = _messageController.text.trim();
                      final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000)}';
                      widget.onSendMessage(text, false, msgId);
                      _messageController.clear();
                      _scrollToBottom();
                    }
                  },
                  child: CircleAvatar(
                    backgroundColor: AppColors.secondary,
                    radius: 23,
                    child: const Icon(Icons.send, color: Colors.black, size: 20),
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant ChatDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length != oldWidget.messages.length) {
      _scrollToBottom();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
