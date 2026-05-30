import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.isRead,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      receiverId: json['receiver_id'] as String? ?? '',
      content: json['content'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
    );
  }
}

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  final SupabaseClient _supabase = Supabase.instance.client;
  Timer? _statusTimer;
  StreamSubscription<AuthState>? _authSub;

  // Real-time channel active subscriptions
  RealtimeChannel? _activeChannel;
  final StreamController<ChatMessage> _messageStreamController = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get onMessageReceived => _messageStreamController.stream;

  final StreamController<String> _typingStreamController = StreamController<String>.broadcast();
  Stream<String> get onFriendTyping => _typingStreamController.stream;

  final StreamController<String> _readStatusStreamController = StreamController<String>.broadcast();
  Stream<String> get onMessagesRead => _readStatusStreamController.stream;

  // In-app Foreground message banner trigger
  final StreamController<ChatMessage> _inAppNotificationController = StreamController<ChatMessage>.broadcast();
  Stream<ChatMessage> get onInAppNotification => _inAppNotificationController.stream;

  /// Initialize Firebase messaging and periodic presence updates
  Future<void> init() async {
    // Graceful initialization fallback for Firebase FCM
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _setupFCM();
    } catch (e) {
      debugPrint('FCM configuration skipped/unavailable: $e');
    }

    _authSub?.cancel();
    _authSub = _supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _startPresencePings();
      } else {
        _stopPresencePings();
      }
    });

    if (_supabase.auth.currentUser != null) {
      _startPresencePings();
    }
  }

  void dispose() {
    _statusTimer?.cancel();
    _authSub?.cancel();
    _messageStreamController.close();
    _typingStreamController.close();
    _readStatusStreamController.close();
    _inAppNotificationController.close();
  }

  // --- Realtime Messaging Channel ---

  String getChannelName(String uid1, String uid2) {
    // Lexicographically smaller UUID first
    return uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  Future<void> subscribeToChat(String friendId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    await unsubscribeFromChat();

    final roomName = getChannelName(myId, friendId);
    _activeChannel = _supabase.channel('chat:$roomName');

    _activeChannel!
        .onBroadcast(
          event: 'message',
          callback: (payload) {
            final data = payload['message'];
            if (data != null) {
              final msg = ChatMessage.fromJson(data);
              _messageStreamController.add(msg);
            }
          },
        )
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final sender = payload['sender_id'] as String?;
            if (sender != null && sender != myId) {
              _typingStreamController.add(sender);
            }
          },
        )
        .onBroadcast(
          event: 'read',
          callback: (payload) {
            final reader = payload['reader_id'] as String?;
            if (reader != null && reader != myId) {
              _readStatusStreamController.add(reader);
            }
          },
        );

    _activeChannel!.subscribe();
    
    // Auto-mark incoming messages as read when active chat opens
    await markMessagesAsRead(friendId);
  }

  Future<void> unsubscribeFromChat() async {
    if (_activeChannel != null) {
      await _supabase.removeChannel(_activeChannel!);
      _activeChannel = null;
    }
  }

  // --- Send Message and typing indicator ---

  Future<ChatMessage> sendMessage(String receiverId, String content) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) throw Exception('User not logged in');

    // 1. Insert into database
    final response = await _supabase.from('messages').insert({
      'sender_id': myId,
      'receiver_id': receiverId,
      'content': content,
      'is_read': false,
    }).select().single();

    final msg = ChatMessage.fromJson(response);

    // 2. Broadcast via Supabase channel for sub-millisecond instant UI updates
    if (_activeChannel != null) {
      await _activeChannel!.sendBroadcastMessage(
        event: 'message',
        payload: {'message': response},
      );
    }

    // 3. Store notification record in Supabase to trigger edge-functions
    try {
      final profile = await _supabase.from('users').select('username').eq('id', myId).maybeSingle();
      final senderName = profile?['username'] as String? ?? 'Friend';

      await _supabase.from('notifications').insert({
        'user_id': receiverId,
        'title': '$senderName 💬',
        'body': content.length > 50 ? '${content.substring(0, 47)}...' : content,
        'type': 'message',
        'data': {
          'sender_id': myId,
          'sender_name': senderName,
        },
      });
    } catch (e) {
      debugPrint('Notification trigger insertion error: $e');
    }

    return msg;
  }

  Future<void> sendTypingNotification(String receiverId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null || _activeChannel == null) return;

    await _activeChannel!.sendBroadcastMessage(
      event: 'typing',
      payload: {'sender_id': myId},
    );
  }

  Future<void> markMessagesAsRead(String friendId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    await _supabase
        .from('messages')
        .update({'is_read': true})
        .eq('sender_id', friendId)
        .eq('receiver_id', myId)
        .eq('is_read', false);

    // Broadcast read receipt
    if (_activeChannel != null) {
      await _activeChannel!.sendBroadcastMessage(
        event: 'read',
        payload: {'reader_id': myId},
      );
    }
  }

  Future<List<ChatMessage>> loadMessages(String friendId, {int limit = 50, int offset = 0}) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return [];

    final response = await _supabase
        .from('messages')
        .select()
        .or('and(sender_id.eq.$myId,receiver_id.eq.$friendId),and(sender_id.eq.$friendId,receiver_id.eq.$myId)')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).map((json) => ChatMessage.fromJson(json)).toList();
  }

  // --- Conversations Fetching ---

  Future<List<Map<String, dynamic>>> loadConversations() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return [];

    // Query messages referencing myId
    final response = await _supabase
        .from('messages')
        .select('*, sender:users!messages_sender_id_fkey(id, username, avatar_emoji, last_seen), receiver:users!messages_receiver_id_fkey(id, username, avatar_emoji, last_seen)')
        .or('sender_id.eq.$myId,receiver_id.eq.$myId')
        .order('created_at', ascending: false);

    final conversationsMap = <String, Map<String, dynamic>>{};

    for (final row in (response as List)) {
      final msg = ChatMessage.fromJson(row);
      final isSender = msg.senderId == myId;
      final friendProfile = isSender ? row['receiver'] : row['sender'];
      
      if (friendProfile == null) continue;
      
      final friendId = friendProfile['id'] as String;
      if (conversationsMap.containsKey(friendId)) {
        // Already have a newer message loaded since it is ordered DESC
        continue;
      }

      // Count unread messages
      final unreadCountResponse = await _supabase
          .from('messages')
          .select('id')
          .eq('sender_id', friendId)
          .eq('receiver_id', myId)
          .eq('is_read', false);

      final unreadCount = (unreadCountResponse as List).length;

      conversationsMap[friendId] = {
        'friend': friendProfile,
        'last_message': msg,
        'unread_count': unreadCount,
      };
    }

    return conversationsMap.values.toList();
  }

  // --- Online / Presence Ping logic ---

  void _startPresencePings() {
    _statusTimer?.cancel();
    updateLastSeen(); // Ping immediately on start
    _statusTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      updateLastSeen();
    });
  }

  void _stopPresencePings() {
    _statusTimer?.cancel();
    _statusTimer = null;
  }

  Future<void> updateLastSeen() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;
    try {
      await _supabase
          .from('users')
          .update({'last_seen': DateTime.now().toUtc().toIso8601String()})
          .eq('id', myId);
    } catch (e) {
      debugPrint('Error updating presence: $e');
    }
  }

  bool isOnline(String? lastSeenStr) {
    if (lastSeenStr == null) return false;
    try {
      final lastSeen = DateTime.parse(lastSeenStr).toLocal();
      final diff = DateTime.now().difference(lastSeen);
      return diff.inMinutes <= 5;
    } catch (_) {
      return false;
    }
  }

  // --- Push Notifications Setup ---

  void _setupFCM() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Save token to Supabase users table
    final token = await messaging.getToken();
    if (token != null) {
      _saveFCMToken(token);
    }

    messaging.onTokenRefresh.listen((newToken) {
      _saveFCMToken(newToken);
    });

    // Handle incoming messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final data = message.data;
      if (data['sender_id'] != null) {
        final chatMsg = ChatMessage(
          id: message.messageId ?? '',
          senderId: data['sender_id'] as String? ?? '',
          receiverId: _supabase.auth.currentUser?.id ?? '',
          content: message.notification?.body ?? '',
          isRead: false,
          createdAt: DateTime.now(),
        );
        _inAppNotificationController.add(chatMsg);
      }
    });
  }

  Future<void> _saveFCMToken(String token) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;
    try {
      await _supabase.from('users').update({'fcm_token': token}).eq('id', myId);
    } catch (e) {
      debugPrint('Error updating FCM token: $e');
    }
  }
}
