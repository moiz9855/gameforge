import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:game_forge/core/constants/app_colors.dart';
import 'package:game_forge/core/services/chat_service.dart';
import 'package:game_forge/core/services/sound_service.dart';

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _filteredConversations = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription? _msgSub;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    
    // Refresh conversations on new messages
    _msgSub = ChatService.instance.onMessageReceived.listen((_) {
      _loadConversations();
    });
  }

  Future<void> _loadConversations() async {
    try {
      final data = await ChatService.instance.loadConversations();
      if (mounted) {
        setState(() {
          _conversations = data;
          _filterConversations(_searchController.text);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading conversations: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterConversations(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredConversations = List.from(_conversations);
      });
      return;
    }

    final lowercaseQuery = query.toLowerCase();
    setState(() {
      _filteredConversations = _conversations.where((conv) {
        final friend = conv['friend'] as Map<String, dynamic>?;
        final username = friend?['username'] as String? ?? '';
        return username.toLowerCase().contains(lowercaseQuery);
      }).toList();
    });
  }

  String _formatMessageTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final checkDate = DateTime(dt.year, dt.month, dt.day);

    if (checkDate == today) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    if (checkDate == yesterday) {
      return 'Yesterday';
    }
    
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          'MESSAGES',
          style: GoogleFonts.pressStart2p(
            fontSize: 14,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.inter(color: Colors.white),
                  onChanged: _filterConversations,
                  decoration: InputDecoration(
                    hintText: 'Search conversations...',
                    hintStyle: GoogleFonts.inter(color: AppColors.textSecondary),
                    icon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _filteredConversations.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredConversations.length,
                          itemBuilder: (context, index) {
                            final conv = _filteredConversations[index];
                            final friend = conv['friend'] as Map<String, dynamic>?;
                            final lastMsg = conv['last_message'] as ChatMessage?;
                            final unreadCount = conv['unread_count'] as int? ?? 0;

                            if (friend == null) return const SizedBox.shrink();

                            final friendId = friend['id'] as String;
                            final username = friend['username'] as String? ?? 'Friend';
                            final avatar = friend['avatar_emoji'] as String? ?? '🎮';
                            final lastSeen = friend['last_seen'] as String?;
                            final isOnline = ChatService.instance.isOnline(lastSeen);

                            final preview = lastMsg?.content ?? '';
                            final truncatedPreview = preview.length > 30 
                                ? '${preview.substring(0, 27)}...' 
                                : preview;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: AppColors.card,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: Colors.white10),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  SoundService.instance.play(SoundType.buttonTap);
                                  await context.push('/chat/$friendId');
                                  _loadConversations(); // Reload when returning
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    children: [
                                      // Avatar + Online status indicator
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          CircleAvatar(
                                            radius: 26,
                                            backgroundColor: AppColors.card2,
                                            child: Text(avatar, style: const TextStyle(fontSize: 24)),
                                          ),
                                          Positioned(
                                            right: -2,
                                            bottom: -2,
                                            child: Container(
                                              width: 14,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                color: isOnline ? AppColors.success : AppColors.muted,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: AppColors.card,
                                                  width: 2,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              username,
                                              style: GoogleFonts.rajdhani(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 17,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              truncatedPreview,
                                              style: GoogleFonts.inter(
                                                color: unreadCount > 0 ? Colors.white : AppColors.textSecondary,
                                                fontSize: 13,
                                                fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          if (lastMsg != null)
                                            Text(
                                              _formatMessageTime(lastMsg.createdAt),
                                              style: GoogleFonts.inter(
                                                color: AppColors.textSecondary,
                                                fontSize: 11,
                                              ),
                                            ),
                                          if (unreadCount > 0) ...[
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: const BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Text(
                                                '$unreadCount',
                                                style: GoogleFonts.shareTechMono(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💬', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'No messages yet!',
              style: GoogleFonts.rajdhani(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Start chatting with your friends 💬',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
