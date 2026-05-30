import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../models/chat_message.dart';

class ChatDialog extends StatefulWidget {
  final List<ChatMessage> messages;
  final Function(String, bool) onSendMessage;

  const ChatDialog({
    super.key,
    required this.messages,
    required this.onSendMessage,
  });

  @override
  State<ChatDialog> createState() => _ChatDialogState();
}

class _ChatDialogState extends State<ChatDialog> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _quickEmojis = ['😂', '🔥', '😮', '😢', '👍', '👑', '🎉', '🤡'];
  final List<String> _quickTexts = [
    'Good game!',
    'Nice move!',
    'Oops!',
    'Roll a six!',
    'Hurry up!',
    'Unlucky!'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 450,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Emojis Quick Bar
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _quickEmojis.length,
              itemBuilder: (context, index) {
                final emoji = _quickEmojis[index];
                return GestureDetector(
                  onTap: () {
                    widget.onSendMessage(emoji, true);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, color: AppColors.surfaceLight),
          
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: widget.messages.length,
              itemBuilder: (context, index) {
                final msg = widget.messages[index];
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.surfaceLight,
                        child: Text(msg.senderName[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(msg.senderName, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: msg.isEmoji ? Colors.transparent : AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                msg.message,
                                style: TextStyle(
                                  fontSize: msg.isEmoji ? 36 : 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Quick texts panel
          SizedBox(
            height: 35,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _quickTexts.length,
              itemBuilder: (context, index) {
                final txt = _quickTexts[index];
                return GestureDetector(
                  onTap: () {
                    widget.onSendMessage(txt, false);
                    _scrollToBottom();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                    ),
                    child: Center(
                      child: Text(txt, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          
          // Chat input bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: const TextStyle(color: AppColors.textSecondary),
                      fillColor: AppColors.surfaceLight,
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  radius: 22,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: () {
                      if (_messageController.text.trim().isNotEmpty) {
                        widget.onSendMessage(_messageController.text.trim(), false);
                        _messageController.clear();
                        _scrollToBottom();
                      }
                    },
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
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
