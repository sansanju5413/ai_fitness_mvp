import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../widgets/fitness_page.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isSending = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _offline = false;
  bool _limitReached = false;
  String? _error;
  Timer? _typingTimer;
  bool _aiTyping = false;

  @override
  void initState() {
    super.initState();
    _seedHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _seedHistory() {
    final now = DateTime.now();
    final sample = List.generate(6, (i) {
      return _ChatMessage(
        id: 'h$i',
        text: i.isEven
            ? 'User message sample #$i'
            : 'Coach tip #$i: Keep core tight during lifts.',
        isUser: i.isEven,
        type: i.isEven ? MessageType.text : MessageType.nutrition,
        timestamp: now.subtract(Duration(minutes: 40 - i * 2)),
      );
    });
    _messages.insertAll(0, sample);
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    await Future.delayed(const Duration(milliseconds: 600));
    final more = List.generate(4, (i) {
      return _ChatMessage(
        id: 'old$i',
        text: 'Earlier session note #$i: hydrate and warm up.',
        isUser: i.isOdd,
        type: MessageType.text,
        timestamp: DateTime.now().subtract(Duration(hours: 5 + i)),
      );
    });
    setState(() {
      _messages.insertAll(0, more);
      _hasMore = false;
      _loadingMore = false;
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    final outgoing = _buildMessage(text, isUser: true);
    _controller.clear();
    setState(() {
      _messages.add(outgoing);
      _isSending = true;
      _error = null;
      _aiTyping = true;
    });
    _scrollToBottom();
    _startTypingIndicator();
    try {
      final appState = context.read<AppState>();
      final replyText = await appState.askAi(text);
      _typingTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _aiTyping = false;
        _messages.add(_buildMessage(
          _decorateReply(replyText),
          isUser: false,
          type: _inferType(replyText),
        ));
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiTyping = false;
        _error = e.toString();
        _offline = false;
        _limitReached = false;
      });
    } finally {
      if (!mounted) return;
      setState(() => _isSending = false);
    }
  }

  void _startTypingIndicator() {
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _aiTyping = false);
    });
  }

  _ChatMessage _buildMessage(
    String text, {
    required bool isUser,
    MessageType type = MessageType.text,
  }) {
    return _ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      isUser: isUser,
      type: type,
      timestamp: DateTime.now(),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _clearChat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text('This will remove all messages in this session.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _messages.clear();
      });
    }
  }

  MessageType _inferType(String reply) {
    if (reply.toLowerCase().contains('plan')) return MessageType.workoutPlan;
    if (reply.toLowerCase().contains('squat') ||
        reply.toLowerCase().contains('exercise')) {
      return MessageType.exerciseList;
    }
    if (reply.toLowerCase().contains('protein') ||
        reply.toLowerCase().contains('calorie')) {
      return MessageType.nutrition;
    }
    if (reply.length > 240) return MessageType.longText;
    return MessageType.text;
  }

  String _decorateReply(String reply) {
    final encouragements = [
      'You\'re crushing it! 💪',
      'Great question, let me help...',
      'Based on your goals...',
    ];
    final prefix = encouragements[DateTime.now().second % encouragements.length];
    return '$prefix\n$reply';
  }

  void _onChipTap(String prompt) {
    _controller.text = prompt;
    _send();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final suggestions = _suggestionsByTime();
    return FitnessPage(
      appBar: AppBar(
        title: const Text('AI Coach'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            onPressed: _messages.isEmpty ? null : _clearChat,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      scrollable: false,
      child: Column(
        children: [
          _HeroBanner(),
          const SizedBox(height: 8),
          _QuickPrompts(
            prompts: suggestions,
            onTap: _onChipTap,
            disabled: _isSending,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              children: [
                if (_hasMore || _loadingMore)
                  TextButton(
                    onPressed: _loadingMore ? null : _loadMore,
                    child: _loadingMore
                        ? const Text('Loading history...')
                        : const Text('Load more'),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.only(bottom: 12),
                    itemCount: _messages.length + (_aiTyping ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_aiTyping && index == _messages.length) {
                        return const _TypingIndicator();
                      }
                      final msg = _messages[index];
                      return _ChatBubble(message: msg);
                    },
                  ),
                ),
                if (_error != null)
                  SelectableText.rich(
                    TextSpan(
                      text: 'Error: ',
                      style: const TextStyle(color: Colors.redAccent),
                      children: [
                        TextSpan(
                          text: _error!,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                    ),
                  ),
                if (_offline)
                  const Text(
                    'Offline. Check your connection.',
                    style: TextStyle(color: Colors.orangeAccent),
                  ),
                if (_limitReached)
                  const Text(
                    'Daily limit reached. Upgrade to continue.',
                    style: TextStyle(color: Colors.amber),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _MessageInput(
            controller: _controller,
            isSending: _isSending,
            onSend: _send,
          ),
        ],
      ),
    );
  }

  List<String> _suggestionsByTime() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return const [
        'Generate workout plan',
        'Meal ideas for today',
        'Form tips for squats',
        'Recovery strategies',
      ];
    }
    if (hour < 18) {
      return const [
        'Upper body pump in 30 mins',
        'High-protein lunch ideas',
        'Form tips for squats',
        'Desk mobility routine',
      ];
    }
    return const [
      'Evening stretch & recovery',
      'Low-carb dinner ideas',
      'Core finisher workout',
      'Sleep routine for gains',
    ];
  }
}

class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  const _MessageInput({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.mic_none_rounded, color: Colors.white70),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: 4,
                  minLines: 1,
                  enabled: !isSending,
                  decoration: const InputDecoration(
                    hintText: 'Ask anything...',
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => onSend(),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: isSending ? null : onSend,
                child: AnimatedScale(
                  scale: isSending ? 0.9 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  child: const CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.send, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          if (isSending)
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 8, top: 4),
                child: Text(
                  'AI is thinking...',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickPrompts extends StatelessWidget {
  final List<String> prompts;
  final void Function(String) onTap;
  final bool disabled;

  const _QuickPrompts({
    required this.prompts,
    required this.onTap,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: prompts
            .map(
              (p) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(p),
                  onPressed: disabled ? null : () => onTap(p),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ChatBubble extends StatefulWidget {
  final _ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  State<_ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<_ChatBubble> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    final alignment =
        msg.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = msg.isUser
        ? Colors.blueAccent.withOpacity(0.9)
        : Colors.white.withOpacity(0.08);
    final border = msg.isUser
        ? Colors.blueAccent
        : Colors.white.withOpacity(0.14);
    return Align(
      alignment: alignment,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment:
              msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            _RichBody(
              message: msg,
              expanded: _expanded,
              onToggle: () => setState(() => _expanded = !_expanded),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(msg.timestamp),
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime ts) {
    final hh = ts.hour.toString().padLeft(2, '0');
    final mm = ts.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _RichBody extends StatelessWidget {
  final _ChatMessage message;
  final bool expanded;
  final VoidCallback onToggle;

  const _RichBody({
    required this.message,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    switch (message.type) {
      case MessageType.workoutPlan:
        return _WorkoutCard(text: message.text, expanded: expanded, onToggle: onToggle);
      case MessageType.exerciseList:
        return _ExerciseList(text: message.text);
      case MessageType.nutrition:
        return _BulletList(text: message.text);
      case MessageType.longText:
        return _ExpandableText(
          text: message.text,
          expanded: expanded,
          onToggle: onToggle,
        );
      case MessageType.text:
      default:
        return Text(
          message.text,
          style: const TextStyle(color: Colors.white),
        );
    }
  }
}

class _WorkoutCard extends StatelessWidget {
  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  const _WorkoutCard({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Workout plan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        _ExpandableText(text: text, expanded: expanded, onToggle: onToggle),
      ],
    );
  }
}

class _ExerciseList extends StatelessWidget {
  final String text;

  const _ExerciseList({required this.text});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n').where((e) => e.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...lines.asMap().entries.map(
              (e) => Row(
                children: [
                  Checkbox(
                    value: false,
                    onChanged: (_) {},
                    visualDensity: VisualDensity.compact,
                    side: const BorderSide(color: Colors.white38),
                  ),
                  Expanded(
                    child: Text(
                      '${e.key + 1}. ${e.value}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class _BulletList extends StatelessWidget {
  final String text;

  const _BulletList({required this.text});

  @override
  Widget build(BuildContext context) {
    final bullets = text.split('\n').where((e) => e.trim().isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: bullets
          .map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(color: Colors.white)),
                  Expanded(
                    child: Text(
                      b,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ExpandableText extends StatelessWidget {
  final String text;
  final bool expanded;
  final VoidCallback onToggle;

  const _ExpandableText({
    required this.text,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final display = expanded ? text : (text.length > 140 ? '${text.substring(0, 140)}...' : text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(display, style: const TextStyle(color: Colors.white)),
        if (text.length > 140)
          TextButton(
            onPressed: onToggle,
            child: Text(expanded ? 'Read less' : 'Read more'),
          ),
      ],
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          SizedBox(width: 12),
          _Dot(),
          _Dot(delay: 150),
          _Dot(delay: 300),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({this.delay = 0});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: CircleAvatar(
          radius: 4,
          backgroundColor: Colors.white70,
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Color(0xFF22c55e), Color(0xFF3b82f6)],
              ),
            ),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'WhatsApp-style AI coach. Ask for workouts, meals, or recovery tips.',
              style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

enum MessageType { text, workoutPlan, exerciseList, nutrition, longText }

class _ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final MessageType type;
  final DateTime timestamp;

  _ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    this.type = MessageType.text,
    required this.timestamp,
  });
}