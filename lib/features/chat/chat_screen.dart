import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/services/chat_service.dart';
import 'package:game_forge/core/services/sound_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String friendId;

  const ChatScreen({
    super.key,
    required this.friendId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  Map<String, dynamic>? _friendProfile;
  final List<ChatMessage> _messages = [];
  bool _isLoading = true;
  bool _isFriendOnline = false;
  bool _isFriendTyping = false;
  Timer? _typingTimer;
  Timer? _localTypingDebounce;
  bool _showEmojiPicker = false;
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  StreamSubscription? _msgSub;
  StreamSubscription? _typingSub;
  StreamSubscription? _readSub;
  Timer? _presenceTimer;

  // Typing animation controller
  late AnimationController _typingAnimationController;

  @override
  void initState() {
    super.initState();
    _typingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _loadFriendAndMessages();
    _setupRealtime();
  }

  Future<void> _loadFriendAndMessages() async {
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', widget.friendId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _friendProfile = res;
          _isFriendOnline = ChatService.instance.isOnline(res?['last_seen'] as String?);
        });
      }
    } catch (e) {
      debugPrint('Error loading friend profile: $e');
    }

    await _fetchMessages(refresh: true);
    
    // Periodically refresh friend's online status
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_friendProfile != null) {
        final res = await Supabase.instance.client
            .from('users')
            .select('last_seen')
            .eq('id', widget.friendId)
            .maybeSingle();
        if (mounted && res != null) {
          setState(() {
            _isFriendOnline = ChatService.instance.isOnline(res['last_seen'] as String?);
          });
        }
      }
    });
  }

  Future<void> _fetchMessages({bool refresh = false}) async {
    if (refresh) {
      _offset = 0;
      _hasMore = true;
    }
    if (!_hasMore) return;

    if (refresh) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final fetched = await ChatService.instance.loadMessages(widget.friendId, offset: _offset);
      if (mounted) {
        setState(() {
          if (refresh) {
            _messages.clear();
          }
          _messages.addAll(fetched);
          _offset += fetched.length;
          if (fetched.length < 50) {
            _hasMore = false;
          }
          _isLoading = false;
          _isLoadingMore = false;
        });
        if (refresh) {
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _setupRealtime() async {
    await ChatService.instance.subscribeToChat(widget.friendId);

    _msgSub = ChatService.instance.onMessageReceived.listen((msg) {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      final isRelevant = (msg.senderId == widget.friendId && msg.receiverId == myId) ||
          (msg.senderId == myId && msg.receiverId == widget.friendId);
      if (!isRelevant) return;

      if (mounted) {
        setState(() {
          // Check if already in list to avoid duplicates
          if (!_messages.any((m) => m.id == msg.id)) {
            _messages.insert(0, msg);
          }
        });
        _scrollToBottom();
        if (msg.senderId == widget.friendId) {
          ChatService.instance.markMessagesAsRead(widget.friendId);
        }
      }
    });

    _typingSub = ChatService.instance.onFriendTyping.listen((senderId) {
      if (senderId == widget.friendId) {
        if (mounted) {
          setState(() => _isFriendTyping = true);
        }
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() => _isFriendTyping = false);
          }
        });
      }
    });

    _readSub = ChatService.instance.onMessagesRead.listen((readerId) {
      if (readerId == widget.friendId) {
        if (mounted) {
          setState(() {
            for (var i = 0; i < _messages.length; i++) {
              final m = _messages[i];
              if (m.senderId != widget.friendId) {
                _messages[i] = ChatMessage(
                  id: m.id,
                  senderId: m.senderId,
                  receiverId: m.receiverId,
                  content: m.content,
                  isRead: true,
                  createdAt: m.createdAt,
                );
              }
            }
          });
        }
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onTextChanged(String text) {
    if (text.isEmpty) return;
    if (_localTypingDebounce?.isActive ?? false) return;

    ChatService.instance.sendTypingNotification(widget.friendId);
    _localTypingDebounce = Timer(const Duration(seconds: 2), () {});
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();
    SoundService.instance.play(SoundType.buttonTap);

    try {
      final msg = await ChatService.instance.sendMessage(widget.friendId, text);
      if (mounted) {
        setState(() {
          if (!_messages.any((m) => m.id == msg.id)) {
            _messages.insert(0, msg);
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _typingSub?.cancel();
    _readSub?.cancel();
    _typingTimer?.cancel();
    _localTypingDebounce?.cancel();
    _presenceTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    _typingAnimationController.dispose();
    ChatService.instance.unsubscribeFromChat();
    super.dispose();
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _getDateDivider(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(dt.year, dt.month, dt.day);

    if (checkDate == today) return 'Today';
    if (checkDate == yesterday) return 'Yesterday';

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final username = _friendProfile?['username'] as String? ?? 'Friend';
    final avatar = _friendProfile?['avatar_emoji'] as String? ?? '🎮';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1218),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () {
            SoundService.instance.play(SoundType.buttonBack);
            context.pop();
          },
        ),
        title: Row(
          children: [
            Text(avatar, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: GoogleFonts.rajdhani(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isFriendOnline ? AppColors.success : AppColors.muted,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isFriendOnline ? 'Online' : 'Offline',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: _isFriendOnline ? AppColors.success : AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _messages.isEmpty
                      ? _buildEmptyState(username, avatar)
                      : NotificationListener<ScrollNotification>(
                          onNotification: (ScrollNotification scrollInfo) {
                            if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 200 &&
                                !_isLoadingMore &&
                                _hasMore) {
                              _fetchMessages();
                            }
                            return true;
                          },
                          child: ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final msg = _messages[index];
                              
                              // Check if we need to show date divider
                              bool showDivider = false;
                              if (index == _messages.length - 1) {
                                showDivider = true;
                              } else {
                                final prevMsg = _messages[index + 1];
                                final diff = msg.createdAt.difference(prevMsg.createdAt).inDays.abs();
                                if (diff >= 1 || msg.createdAt.day != prevMsg.createdAt.day) {
                                  showDivider = true;
                                }
                              }

                              final isMe = msg.senderId != widget.friendId;

                              return Column(
                                children: [
                                  if (showDivider) ...[
                                    const SizedBox(height: 12),
                                    _buildDateDivider(msg.createdAt),
                                    const SizedBox(height: 12),
                                  ],
                                  _buildMessageBubble(msg, isMe, avatar),
                                ],
                              );
                            },
                          ),
                        ),
            ),
            
            if (_isFriendTyping) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(avatar, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    _buildTypingIndicator(),
                  ],
                ),
              ),
            ],

            _buildInputBar(username),

            if (_showEmojiPicker) _buildEmojiPicker(),
          ],
        ),
      ),
    );
  }

  Widget _buildDateDivider(DateTime date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Text(
        _getDateDivider(date),
        style: GoogleFonts.shareTechMono(
          color: AppColors.textSecondary,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isMe, String friendAvatar) {
    final timeStr = _formatTime(msg.createdAt);

    if (isMe) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0, left: 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  msg.content,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeStr,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    msg.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: msg.isRead ? Colors.cyan : AppColors.textSecondary,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } else {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8.0, right: 60),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.card2,
                child: Text(friendAvatar, style: const TextStyle(fontSize: 16)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        color: AppColors.card2,
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        msg.content,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildEmptyState(String username, String avatar) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(avatar, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'Start chatting with $username! 👋',
            style: GoogleFonts.rajdhani(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Say hello 🎮',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card2,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _typingAnimationController,
            builder: (context, child) {
              final double delay = index * 0.2;
              final double animValue = (sin((_typingAnimationController.value * 2 * pi) - delay) + 1.0) / 2.0;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3 + 0.7 * animValue),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }

  Widget _buildInputBar(String username) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1218),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
              color: AppColors.textSecondary,
            ),
            onPressed: () {
              SoundService.instance.play(SoundType.buttonTap);
              setState(() {
                _showEmojiPicker = !_showEmojiPicker;
                if (_showEmojiPicker) {
                  FocusScope.of(context).unfocus();
                }
              });
            },
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.card2,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _inputController,
                style: GoogleFonts.inter(color: Colors.white),
                maxLines: 4,
                minLines: 1,
                keyboardType: TextInputType.multiline,
                onChanged: _onTextChanged,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Message $username...',
                  hintStyle: GoogleFonts.inter(color: AppColors.textSecondary),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _inputController,
            builder: (context, value, child) {
              final hasText = value.text.trim().isNotEmpty;
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasText ? AppColors.primary : AppColors.card2,
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  onPressed: hasText ? _sendMessage : null,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPicker() {
    final categories = {
      'Smileys': ['😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣', '😊', '😇', '🙂', '🙃', '😉', '😌', '😍', '🥰'],
      'Gaming': ['🎮', '🕹️', '👾', '🎲', '🃏', '🧩', '🏆', '🥇', '🥈', '🥉', '👑', '⚔️', '🛡️', '🏹', '🔫', '🚀'],
      'Sports': ['⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🏉', '🥏', '🎱', '🪀', '🏓', '🏸', '🏒', '🏑', '🥍'],
      'Food': ['🍎', '🍌', '🍉', '🍇', '🍓', '🍒', '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑', '🥦', '🥬'],
    };

    return Container(
      height: 240,
      color: const Color(0xFF0F1218),
      child: DefaultTabController(
        length: categories.length,
        child: Column(
          children: [
            TabBar(
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              tabs: categories.keys.map((name) => Tab(text: name)).toList(),
            ),
            Expanded(
              child: TabBarView(
                children: categories.values.map((emojis) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 8,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: emojis.length,
                    itemBuilder: (context, index) {
                      final emoji = emojis[index];
                      return GestureDetector(
                        onTap: () {
                          SoundService.instance.play(SoundType.buttonTap);
                          final text = _inputController.text;
                          final selection = _inputController.selection;
                          final newText = text.replaceRange(selection.start, selection.end, emoji);
                          _inputController.value = TextEditingValue(
                            text: newText,
                            selection: TextSelection.collapsed(offset: selection.start + emoji.length),
                          );
                        },
                        child: Center(
                          child: Text(emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      );
                    },
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
