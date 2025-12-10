import 'package:flutter/material.dart';

class AiMessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;

  const AiMessageBubble({
    super.key,
    required this.text,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    final alignment =
        isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bgColor = isUser
        ? Colors.white.withOpacity(0.14)
        : Colors.white.withOpacity(0.08);
    final borderColor = Colors.white.withOpacity(isUser ? 0.22 : 0.14);

    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
              ),
        ),
      ),
    );
  }
}
