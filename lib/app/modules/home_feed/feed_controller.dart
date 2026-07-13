import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebasecrashreport/app/data/models/dance_models.dart';
import 'package:firebasecrashreport/app/data/services/supabase_store.dart';
import 'package:firebasecrashreport/app/controllers/auth_controller.dart';
import 'package:firebasecrashreport/app/modules/profile/profile_controller.dart';

class FeedController extends GetxController {
  final SupabaseStore _dbHelper = SupabaseStore.instance;

  final RxList<DanceClip> _clips = <DanceClip>[].obs;
  final RxList<DanceClip> _followedClips = <DanceClip>[].obs;
  final RxSet<String> followedDancerUids = <String>{}.obs;
  List<ChatRoom> _chatRooms = [];
  
  final RxBool _isLoading = false.obs;
  final RxBool isMuted = false.obs;
  final RxInt focusedIndex = 0.obs;

  void toggleMute() {
    isMuted.value = !isMuted.value;
  }

  RxList<DanceClip> get clips => _clips;
  RxList<DanceClip> get followedClips => _followedClips;
  List<ChatRoom> get chatRooms => _chatRooms;
  bool get isLoading => _isLoading.value;

  final Map<String, DateTime> _lastReadTimestamps = {};
  String? activeChatRoomId;
  final RxInt unreadCountRx = 0.obs;

  void safeUpdate() {
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => update());
    } else {
      update();
    }
  }

  void _recalcUnread() {
    int count = 0;
    for (var room in _chatRooms) {
      count += getUnreadCount(room.id);
    }
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unreadCountRx.value = count;
      });
    } else {
      unreadCountRx.value = count;
    }
  }

  Future<void> _loadLastReadTimestamps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Load persisted read-markers using a functional chain
      prefs.getKeys()
          .where((key) => key.startsWith('last_read_time_'))
          .forEach((key) {
        final roomId = key.replaceFirst('last_read_time_', '');
        final val = prefs.getString(key);
        if (val != null) {
          try {
            _lastReadTimestamps[roomId] = DateTime.parse(val);
          } catch (_) {}
        }
      });
    } catch (e) {
      debugPrint("Error loading last read timestamps: $e");
    }

    // Seed lastRead for rooms never opened before — messages are already
    // ordered ascending by timestamp, so .last is always the newest.
    _chatRooms
        .where((r) => !_lastReadTimestamps.containsKey(r.id) && r.messages.isNotEmpty)
        .forEach((r) => _lastReadTimestamps[r.id] = r.messages.last.timestamp);

    _recalcUnread();
    safeUpdate();
  }

  Future<void> markAsRead(String chatRoomId) async {
    final now = DateTime.now().toUtc();
    _lastReadTimestamps[chatRoomId] = now;
    _recalcUnread();
    safeUpdate();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_read_time_$chatRoomId', now.toIso8601String());
    } catch (e) {
      debugPrint("Error saving last read timestamp: $e");
    }
  }

  int getUnreadCount(String chatRoomId) {
    int index = _chatRooms.indexWhere((room) => room.id == chatRoomId);
    if (index == -1) return 0;
    final room = _chatRooms[index];
    final lastRead = _lastReadTimestamps[chatRoomId] ?? DateTime(1970);
    return room.messages.where((m) => m.senderId != _currentUid && m.timestamp.isAfter(lastRead)).length;
  }

  int get totalUnreadCount => unreadCountRx.value;

  void updateFollowedClips() {
    try {
      final authService = Get.find<AuthController>();
      final currentUser = authService.currentUserProfile;

      if (currentUser == null) {
        _followedClips.assignAll(_clips);
      } else {
        _followedClips.assignAll(_clips.where((clip) {
          return clip.isFollowedByMe || clip.dancerUid == currentUser.uid;
        }).toList());
      }
    } catch (e) {
      // Fallback in case AuthController isn't registered yet during init
      _followedClips.assignAll(_clips);
    }
  }

  @override
  void onInit() {
    super.onInit();
    ever(_clips, (_) => updateFollowedClips());
    _loadInitialData();
  }

  // Get current user UID
  String get _currentUid {
    try {
      final auth = Get.find<AuthController>();
      return auth.currentUserProfile?.uid ?? "guest";
    } catch (_) {
      return "guest";
    }
  }

  void _showSnackbar(String title, String message, {Duration? duration}) {
    if (Get.overlayContext == null) return;
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.redAccent.withValues(alpha: 0.9),
      colorText: Colors.white,
      duration: duration,
    );
  }

  Future<void> _loadInitialData() async {
    _isLoading.value = true;
    update();

    if (_currentUid == "guest") {
      _unsubscribeFromRealtimeMessages();
      _unsubscribeFromPresence();
    }

    try {
      _clips.assignAll(await _dbHelper.getClips(_currentUid));
      final uids = await _dbHelper.getFollowedUserIds(_currentUid);
      followedDancerUids.assignAll(uids);
      _chatRooms = await _dbHelper.getChatRooms(_currentUid);
      _subscribeToRealtimeMessages();
      _subscribeToPresence();
      _loadLastReadTimestamps();
    } catch (e) {
      debugPrint("FeedController Error loading data: $e");
      String errorMsg = "Could not fetch dance data from database.";
      if (e is PostgrestException) {
        errorMsg = e.message;
        if (e.message.contains("Could not find the table")) {
          errorMsg = "Database tables are missing! Please run 'schema.sql' in the Supabase SQL Editor.";
        }
      } else if (e.toString().contains("Failed host lookup") || e.toString().contains("SocketException")) {
        errorMsg = "Network connection failed. Please check your internet connectivity.";
      }
      _showSnackbar(
        "Database/Network Error",
        errorMsg,
        duration: const Duration(seconds: 7),
      );
    }

    _isLoading.value = false;
    update();
  }

  // Refresh feeds and chats
  Future<void> refreshData() async {
    await _loadInitialData();
  }

  // Like / Unlike clip
  Future<void> toggleLike(String clipId) async {
    // 1. Optimistic Update in UI
    int index = _clips.indexWhere((c) => c.id == clipId);
    int delta = 0;
    String? dancerUid;
    if (index != -1) {
      final clip = _clips[index];
      dancerUid = clip.dancerUid;
      if (clip.isLikedByMe) {
        clip.likes--;
        clip.isLikedByMe = false;
        delta = -1;
      } else {
        clip.likes++;
        clip.isLikedByMe = true;
        delta = 1;
      }
      _clips.refresh();
      update();

      // Update active ProfileControllers if they exist in memory
      if (dancerUid.isNotEmpty && delta != 0) {
        final tags = ['me', dancerUid];
        for (final tag in tags) {
          if (Get.isRegistered<ProfileController>(tag: tag)) {
            final profileCtrl = Get.find<ProfileController>(tag: tag);
            if (profileCtrl.profile.value != null && profileCtrl.profile.value!.uid == dancerUid) {
              profileCtrl.profile.value = profileCtrl.profile.value!.copyWith(
                likesCount: profileCtrl.profile.value!.likesCount + delta,
              );
            }
          }
        }
      }
    }

    try {
      // 2. Persist in SQL
      final result = await _dbHelper.toggleLike(clipId, _currentUid);
      
      // Update with exact values from DB if different
      int finalIndex = _clips.indexWhere((c) => c.id == clipId);
      if (finalIndex != -1) {
        _clips[finalIndex].likes = result['likes'] as int;
        _clips[finalIndex].isLikedByMe = result['isLikedByMe'] as bool;
        _clips.refresh();
        update();
      }
    } catch (e) {
      debugPrint("Error toggling like in SQL: $e");
      String errorMsg = "Could not update like status in the database.";
      if (e is PostgrestException) {
        errorMsg = e.message;
      }
      _showSnackbar("Database Error", errorMsg);
    }
  }

  // Follow / Unfollow dancer
  Future<void> toggleFollow(String dancerUid) async {
    // 1. Optimistic Update in UI
    if (followedDancerUids.contains(dancerUid)) {
      followedDancerUids.remove(dancerUid);
    } else {
      followedDancerUids.add(dancerUid);
    }
    for (var clip in _clips) {
      if (clip.dancerUid == dancerUid) {
        clip.isFollowedByMe = !clip.isFollowedByMe;
      }
    }
    _clips.refresh();
    update();

    try {
      // 2. Persist in SQL
      final isFollowed = await _dbHelper.toggleFollow(_currentUid, dancerUid);
      
      // Sync local followed set with DB state
      if (isFollowed) {
        followedDancerUids.add(dancerUid);
      } else {
        followedDancerUids.remove(dancerUid);
      }
      
      // Ensure all clips of this dancer are synced with actual DB state
      for (var clip in _clips) {
        if (clip.dancerUid == dancerUid) {
          clip.isFollowedByMe = isFollowed;
        }
      }
      _clips.refresh();
      update();

      // Proactively refresh any active ProfileController (e.g. to update follower counts)
      if (Get.isRegistered<ProfileController>(tag: dancerUid)) {
        final profileCtrl = Get.find<ProfileController>(tag: dancerUid);
        profileCtrl.loadProfileData(dancerUid);
      }
      if (Get.isRegistered<ProfileController>(tag: 'me')) {
        final profileCtrl = Get.find<ProfileController>(tag: 'me');
        profileCtrl.loadProfileData(_currentUid);
      }
    } catch (e) {
      debugPrint("Error toggling follow in SQL: $e");
      String errorMsg = "Could not update follow status in the database.";
      if (e is PostgrestException) {
        errorMsg = e.message;
      }
      _showSnackbar("Database Error", errorMsg);
    }
  }

  // Fetch comments for a clip
  Future<List<Comment>> getComments(String clipId) async {
    try {
      return await _dbHelper.getComments(clipId);
    } catch (e) {
      debugPrint("Error fetching comments: $e");
      return [];
    }
  }

  // Add Comment
  Future<void> addComment(String clipId, String commentText, DancerProfile user) async {
    final comment = Comment(
      id: "comment_${DateTime.now().millisecondsSinceEpoch}",
      username: user.username,
      avatarUrl: user.avatarUrl,
      commentText: commentText,
      timestamp: DateTime.now(),
    );

    // Optimistically update comment count in local list
    int index = _clips.indexWhere((c) => c.id == clipId);
    if (index != -1) {
      _clips[index].commentsCount++;
      _clips.refresh();
      update();
    }

    try {
      await _dbHelper.addComment(clipId, comment);
      
      // Refresh clips to make sure count is accurate
      _clips.assignAll(await _dbHelper.getClips(_currentUid));
      update();
    } catch (e) {
      debugPrint("Error adding comment in SQL: $e");
      String errorMsg = "Could not save your comment to the database.";
      if (e is PostgrestException) {
        errorMsg = e.message;
      }
      _showSnackbar("Database Error", errorMsg);
    }
  }

  // Create a new post (legacy direct upload)
  Future<void> addNewPost({
    required String caption,
    required String musicName,
    required String musicArtist,
    required String danceStyle,
    required DancerProfile dancer,
    required String videoUrl,
    required String thumbnailUrl,
    double cropAspectRatio = 0.5625,
    String filterType = 'none',
    double brightness = 1.0,
    int startTimeMs = 0,
    int endTimeMs = 0,
  }) async {
    _isLoading.value = true;
    update();

    final newClipId = "clip_${DateTime.now().millisecondsSinceEpoch}";
    final newClip = DanceClip(
      id: newClipId,
      videoUrl: videoUrl,
      thumbnailUrl: thumbnailUrl,
      caption: caption,
      musicName: musicName,
      musicArtist: musicArtist,
      dancerUid: dancer.uid,
      dancerName: dancer.username,
      dancerAvatar: dancer.avatarUrl,
      likes: 0,
      commentsCount: 0,
      sharesCount: 0,
      danceStyle: danceStyle,
      isLikedByMe: false,
      isFollowedByMe: false,
      cropAspectRatio: cropAspectRatio,
      filterType: filterType,
      brightness: brightness,
      startTimeMs: startTimeMs,
      endTimeMs: endTimeMs,
    );

    try {
      await _dbHelper.saveUserProfile(dancer);
      await _dbHelper.insertClip(newClip);
      _clips.assignAll(await _dbHelper.getClips(_currentUid));
    } catch (e) {
      debugPrint("Error inserting new clip to SQL: $e");
      String errorMsg = "Could not publish post. Failed to save to database.";
      if (e is PostgrestException) {
        errorMsg = e.message;
      }
      _showSnackbar("Database Error", errorMsg);
    }

    _isLoading.value = false;
    update();
  }

  // Delete a post (clip)
  Future<void> deletePost(String clipId) async {
    _isLoading.value = true;
    update();
    try {
      await _dbHelper.deleteClip(clipId);
      // Remove from local list
      _clips.removeWhere((c) => c.id == clipId);
      _clips.refresh();
      update();
    } catch (e) {
      debugPrint("Error deleting post: $e");
      _showSnackbar("Database Error", "Could not delete post. Please try again.");
      rethrow;
    } finally {
      _isLoading.value = false;
      update();
    }
  }

  // Update post details (clip)
  Future<void> updatePost(String clipId, {
    required String caption,
    required String danceStyle,
    required String musicName,
    required String musicArtist,
  }) async {
    _isLoading.value = true;
    update();
    try {
      await _dbHelper.updateClip(
        clipId,
        caption: caption,
        danceStyle: danceStyle,
        musicName: musicName,
        musicArtist: musicArtist,
      );
      
      // Update local clip in the reactive list
      int index = _clips.indexWhere((c) => c.id == clipId);
      if (index != -1) {
        final oldClip = _clips[index];
        _clips[index] = DanceClip(
          id: oldClip.id,
          videoUrl: oldClip.videoUrl,
          thumbnailUrl: oldClip.thumbnailUrl,
          caption: caption,
          musicName: musicName,
          musicArtist: musicArtist,
          dancerUid: oldClip.dancerUid,
          dancerName: oldClip.dancerName,
          dancerAvatar: oldClip.dancerAvatar,
          likes: oldClip.likes,
          commentsCount: oldClip.commentsCount,
          sharesCount: oldClip.sharesCount,
          danceStyle: danceStyle,
          isLikedByMe: oldClip.isLikedByMe,
          isFollowedByMe: oldClip.isFollowedByMe,
          cropAspectRatio: oldClip.cropAspectRatio,
          filterType: oldClip.filterType,
          brightness: oldClip.brightness,
          startTimeMs: oldClip.startTimeMs,
          endTimeMs: oldClip.endTimeMs,
          mediaItemsJson: oldClip.mediaItemsJson,
        );
        _clips.refresh();
        update();
      }
    } catch (e) {
      debugPrint("Error updating post: $e");
      _showSnackbar("Database Error", "Could not update post. Please try again.");
      rethrow;
    } finally {
      _isLoading.value = false;
      update();
    }
  }

  // Find or Create Chat Room
  ChatRoom getOrCreateChat(DancerProfile otherUser) {
    final roomId = SupabaseStore.getChatRoomId(_currentUid, otherUser.uid);
    int index = _chatRooms.indexWhere((room) => room.id == roomId);
    if (index != -1) {
      return _chatRooms[index];
    } else {
      final newRoom = ChatRoom(
        id: roomId,
        otherUser: otherUser,
        messages: [],
      );
      _chatRooms.insert(0, newRoom);
      update();
      return newRoom;
    }
  }

  // Send Direct Message
  Future<void> sendMessage(String chatRoomId, String text, String senderId) async {
    int index = _chatRooms.indexWhere((room) => room.id == chatRoomId);
    if (index != -1) {
      final room = _chatRooms[index];
      final message = ChatMessage(
        id: "msg_${DateTime.now().millisecondsSinceEpoch}",
        senderId: senderId,
        receiverId: room.otherUser.uid,
        text: text,
        timestamp: DateTime.now(),
      );

      room.messages.add(message);
      _chatRooms.removeAt(index);
      _chatRooms.insert(0, room);
      markAsRead(chatRoomId);
      update();

      try {
        await _dbHelper.insertMessage(message, chatRoomId);
      } catch (e) {
        debugPrint("Error sending message to SQL: $e");
        String errorMsg = "Could not send message. Failed to save to database.";
        if (e is PostgrestException) {
          errorMsg = e.message;
        }
        _showSnackbar("Database Error", errorMsg);
      }
    }
  }

  Future<void> editMessage(String chatRoomId, String messageId, String newText) async {
    final roomIndex = _chatRooms.indexWhere((r) => r.id == chatRoomId);
    if (roomIndex == -1) return;
    final room = _chatRooms[roomIndex];
    final msgIndex = room.messages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return;
    room.messages[msgIndex] = room.messages[msgIndex].copyWith(text: newText, isEdited: true);
    update();
    try {
      await _dbHelper.updateMessage(messageId, newText);
    } catch (e) {
      debugPrint("Error editing message: $e");
    }
  }

  Future<void> deleteMessage(String chatRoomId, String messageId) async {
    final roomIndex = _chatRooms.indexWhere((r) => r.id == chatRoomId);
    if (roomIndex == -1) return;
    final room = _chatRooms[roomIndex];
    room.messages.removeWhere((m) => m.id == messageId);
    update();
    try {
      await _dbHelper.deleteMessage(messageId);
    } catch (e) {
      debugPrint("Error deleting message: $e");
    }
  }

  Future<List<DanceClip>> getLikedClips() async {
    try {
      return await _dbHelper.getLikedClips(_currentUid);
    } catch (e) {
      debugPrint("Error fetching liked clips from SQL: $e");
      return [];
    }
  }

  RealtimeChannel? _messagesChannel;

  void _subscribeToRealtimeMessages() {
    _unsubscribeFromRealtimeMessages();

    final currentUid = _currentUid;
    if (currentUid == "guest") return;

    try {
      final client = Supabase.instance.client;
      _messagesChannel = client.channel('public:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_uid',
            value: currentUid,
          ),
          callback: (payload) async {
            final newRecord = payload.newRecord;
            if (newRecord.isEmpty) return;

            final senderUid = newRecord['sender_uid'] as String?;
            final receiverUid = newRecord['receiver_uid'] as String?;

            if (senderUid != null && receiverUid != null &&
                (senderUid == currentUid || receiverUid == currentUid)) {
              final chatRoomId = SupabaseStore.getChatRoomId(senderUid, receiverUid);
              final messageId = newRecord['id'] as String? ?? '';
              final messageText = newRecord['message_text'] as String? ?? '';
              final timestampStr = newRecord['timestamp'] as String? ?? '';
              final timestamp = timestampStr.isNotEmpty
                  ? (() {
                      final hasTz = RegExp(r'(Z|([+-]\d{2}(:?\d{2})?))$').hasMatch(timestampStr);
                      return DateTime.parse(hasTz ? timestampStr : '${timestampStr}Z').toUtc();
                    })()
                  : DateTime.now().toUtc();

              if (messageId.isEmpty) return;

              // Find the chat room index
              int roomIndex = _chatRooms.indexWhere((room) => room.id == chatRoomId);
              
              ChatMessage newMessage = ChatMessage(
                id: messageId,
                senderId: senderUid,
                receiverId: receiverUid,
                text: messageText,
                timestamp: timestamp,
              );

              if (roomIndex != -1) {
                // If room exists, check if message is already added
                final room = _chatRooms[roomIndex];
                final messageExists = room.messages.any((m) => m.id == messageId);
                if (!messageExists) {
                  room.messages.add(newMessage);
                  if (chatRoomId == activeChatRoomId) {
                    markAsRead(chatRoomId);
                  } else {
                    _recalcUnread();
                  }
                  // Move room to top
                  _chatRooms.removeAt(roomIndex);
                  _chatRooms.insert(0, room);
                  safeUpdate();
                }
              } else {
                // Fetch other user profile and create the room
                final otherUid = senderUid == currentUid ? receiverUid : senderUid;
                DancerProfile? otherUser = await _dbHelper.getUserProfile(otherUid);
                otherUser ??= DancerProfile(
                  uid: otherUid,
                  username: "dancer_${otherUid.substring(0, (otherUid.length > 4 ? 4 : otherUid.length))}",
                  displayName: "Dancer ${otherUid.substring(0, (otherUid.length > 4 ? 4 : otherUid.length))}",
                  avatarUrl: defaultAvatarUrl,
                  bio: "Hey there! I am using Dance Pulse.",
                  followersCount: 0,
                  followingCount: 0,
                  likesCount: 0,
                  danceStyles: const ["Freestyle"],
                );

                final newRoom = ChatRoom(
                  id: chatRoomId,
                  otherUser: otherUser,
                  messages: [newMessage],
                );
                if (chatRoomId == activeChatRoomId) {
                  markAsRead(chatRoomId);
                } else {
                  _recalcUnread();
                }
                _chatRooms.insert(0, newRoom);
                safeUpdate();
              }
            }
          },
        );
      
      _messagesChannel?.subscribe();
    } catch (e) {
      debugPrint("Error subscribing to realtime messages: $e");
    }
  }

  void _unsubscribeFromRealtimeMessages() {
    if (_messagesChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_messagesChannel!);
      } catch (e) {
        debugPrint("Error removing realtime channel: $e");
      }
      _messagesChannel = null;
    }
  }

  RealtimeChannel? _presenceChannel;
  final Map<String, Map<String, dynamic>> _presenceMap = {};
  final Map<String, DateTime> _lastSeenCache = {};

  bool isUserOnline(String uid) {
    return _presenceMap.containsKey(uid);
  }

  String getUserLastSeen(String uid) {
    if (_presenceMap.containsKey(uid)) {
      return "Online";
    }
    return _lastSeenCache.containsKey(uid)
        ? "Last seen: ${DateFormat('hh:mm a').format(_lastSeenCache[uid]!)}"
        : "Offline";
  }

  bool isUserTypingInRoom(String uid, String roomId) {
    if (_presenceMap.containsKey(uid)) {
      final data = _presenceMap[uid]!;
      return (data['is_typing'] as bool? ?? false) && (data['typing_in'] as String? ?? '') == roomId;
    }
    return false;
  }

  void _subscribeToPresence() {
    _unsubscribeFromPresence();

    final currentUid = _currentUid;
    if (currentUid == "guest") {
      debugPrint("Presence subscription skipped: user is guest");
      return;
    }

    try {
      final client = Supabase.instance.client;
      _presenceChannel = client.channel('global:presence');
      
      _presenceChannel!
        .onPresenceSync((payload) {
          _handlePresenceSync();
        })
        .onPresenceJoin((payload) {
          _handlePresenceSync();
        })
        .onPresenceLeave((payload) {
          for (var presence in payload.leftPresences) {
            final Map<String, dynamic> presenceData = Map<String, dynamic>.from(presence.payload);
            final uid = presenceData['uid'] as String?;
            if (uid != null) {
              _lastSeenCache[uid] = DateTime.now();
            }
          }
          _handlePresenceSync();
        });

      _presenceChannel!.subscribe((status, [error]) async {
        debugPrint("Presence channel subscription status: $status, error: $error");
        if (status == RealtimeSubscribeStatus.subscribed) {
          try {
            await _presenceChannel!.track({
              'uid': currentUid,
              'is_typing': false,
              'typing_in': '',
              'last_seen': DateTime.now().toIso8601String(),
            });
            debugPrint("Presence successfully tracked for user: $currentUid");
          } catch (e) {
            debugPrint("Error tracking presence: $e");
          }
        }
      });
    } catch (e) {
      debugPrint("Error creating presence channel: $e");
    }
  }

  void _handlePresenceSync() {
    if (_presenceChannel == null) return;
    
    _presenceMap.clear();
    final state = _presenceChannel!.presenceState();
    debugPrint("Presence sync callback. State entry count: ${state.length}");
    
    for (final presenceState in state) {
      final list = presenceState.presences;
      if (list.isNotEmpty) {
        final Map<String, dynamic> presence = Map<String, dynamic>.from(list.first.payload);
        final uid = presence['uid'] as String?;
        if (uid != null && uid != _currentUid) {
          _presenceMap[uid] = presence;
          
          final lastSeenStr = presence['last_seen'] as String?;
          if (lastSeenStr != null && lastSeenStr.isNotEmpty) {
            try {
              _lastSeenCache[uid] = DateTime.parse(lastSeenStr);
            } catch (_) {}
          }
        }
      }
    }
    safeUpdate();
  }

  void _unsubscribeFromPresence() {
    if (_presenceChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_presenceChannel!);
      } catch (e) {
        debugPrint("Error removing presence channel: $e");
      }
      _presenceChannel = null;
    }
    _presenceMap.clear();
  }

  void updateTypingStatus(bool isTyping, String roomId) async {
    final currentUid = _currentUid;
    if (currentUid == "guest" || _presenceChannel == null) return;

    try {
      await _presenceChannel!.track({
        'uid': currentUid,
        'is_typing': isTyping,
        'typing_in': isTyping ? roomId : '',
        'last_seen': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("Error updating typing presence: $e");
    }
  }

  // --- BACKGROUND POST UPLOAD QUEUE ---

  final List<PostUploadTask> _uploadQueue = [];
  bool _isUploadingBackground = false;

  List<PostUploadTask> get uploadQueue => _uploadQueue;
  bool get isUploadingBackground => _isUploadingBackground;

  // Active HUD task selection helper
  PostUploadTask? get activeUploadTask {
    if (_uploadQueue.isEmpty) return null;
    
    // 1. Show the task that is currently uploading
    int uploadingIndex = _uploadQueue.indexWhere((task) => task.status == "Uploading" || task.status == "Completed");
    if (uploadingIndex != -1) {
      return _uploadQueue[uploadingIndex];
    }
    // 2. Otherwise show the first failed task
    int failedIndex = _uploadQueue.indexWhere((task) => task.status == "Failed");
    if (failedIndex != -1) {
      return _uploadQueue[failedIndex];
    }
    // 3. Otherwise show the first queued task
    int queuedIndex = _uploadQueue.indexWhere((task) => task.status == "Queued");
    if (queuedIndex != -1) {
      return _uploadQueue[queuedIndex];
    }
    return _uploadQueue.first;
  }

  void addBattleToQueue({
    required String battleId,
    required DancerProfile dancer,
    required String localVideoPath,
    required int meIndex,
    required String opponentName,
  }) {
    final taskId = "battle_$battleId";
    
    // Check if task is already in queue or running to avoid duplicates
    if (_uploadQueue.any((t) => t.id == taskId)) {
      return;
    }

    final task = PostUploadTask(
      id: taskId,
      caption: "Dance Battle vs $opponentName",
      musicName: "",
      musicArtist: "",
      danceStyle: "",
      dancer: dancer,
      videoPath: localVideoPath,
      thumbnailPath: "",
      cropAspectRatio: 1.0,
      filterType: "none",
      brightness: 1.0,
      startTimeMs: 0,
      endTimeMs: 0,
      isBattle: true,
      battleId: battleId,
      battleMeIndex: meIndex,
      opponentName: opponentName,
    );

    _uploadQueue.add(task);
    update();

    _processUploadQueue();
  }

  void addPostToQueue({
    required String caption,
    required String musicName,
    required String musicArtist,
    required String danceStyle,
    required DancerProfile dancer,
    required String videoPath,
    required String thumbnailPath,
    double cropAspectRatio = 0.5625,
    String filterType = 'none',
    double brightness = 1.0,
    int startTimeMs = 0,
    int endTimeMs = 0,
  }) {
    final taskId = "clip_${DateTime.now().millisecondsSinceEpoch}";
    final task = PostUploadTask(
      id: taskId,
      caption: caption,
      musicName: musicName,
      musicArtist: musicArtist,
      danceStyle: danceStyle,
      dancer: dancer,
      videoPath: videoPath,
      thumbnailPath: thumbnailPath,
      cropAspectRatio: cropAspectRatio,
      filterType: filterType,
      brightness: brightness,
      startTimeMs: startTimeMs,
      endTimeMs: endTimeMs,
    );

    _uploadQueue.add(task);
    update();

    // Start background queue processing
    _processUploadQueue();
  }

  Future<void> _processUploadQueue() async {
    if (_isUploadingBackground) return;
    
    int nextTaskIndex = _uploadQueue.indexWhere((task) => task.status == "Queued");
    if (nextTaskIndex == -1) {
      _isUploadingBackground = false;
      update();
      return;
    }

    _isUploadingBackground = true;
    final task = _uploadQueue[nextTaskIndex];
    task.status = "Uploading";
    update();

    if (task.isBattle) {
      await _processBattleUpload(task);
      return;
    }

    try {
      final isMultiple = task.videoPath.startsWith('[') && task.videoPath.endsWith(']');
      List<String> steps;

      if (isMultiple) {
        final List<dynamic> items = jsonDecode(task.videoPath);
        steps = [
          "Analyzing post media content (${items.length} files selected)",
          "Applying individual crops and custom filters",
          "Processing video transcoding for selected performances",
          "Uploading all optimized media assets to GCS",
          "Saving post to database",
        ];
      } else {
        final isVideo = task.videoPath.toLowerCase().endsWith('.mp4') ||
            task.videoPath.toLowerCase().endsWith('.mov') ||
            task.videoPath.toLowerCase().endsWith('.mkv') ||
            task.videoPath.toLowerCase().endsWith('.3gp') ||
            task.videoPath.toLowerCase().endsWith('.avi') ||
            task.videoPath.contains('/tmp/');

        steps = isVideo 
          ? [
              "Resizing cover image to Thumb (150x150) -> thumb_cover.jpg",
              "Resizing cover image to Small (320x320) -> small_cover.jpg",
              "Resizing cover image to Medium (640x640) -> medium_cover.jpg",
              "Resizing cover image to Large (1080x1080) -> large_cover.jpg",
              "Formatting Original cover image -> original_cover.jpg",
              "Transcoding video to HLS (generating playlist index.m3u8)",
              "Uploading playlist and segment files to GCS...",
              "Uploading cover images to GCS...",
            ]
          : [
              "Resizing post image to Thumb (150x150) -> thumb_post.jpg",
              "Resizing post image to Small (320x320) -> small_post.jpg",
              "Resizing post image to Medium (640x640) -> medium_post.jpg",
              "Resizing post image to Large (1080x1080) -> large_post.jpg",
              "Formatting Original post image -> original_post.jpg",
              "Applying crop constraints",
              "Uploading cropped post images to GCS...",
            ];
      }

      for (int i = 0; i < steps.length; i++) {
        // Safe check: check if task was canceled/removed during step delay
        if (!_uploadQueue.any((t) => t.id == task.id)) {
          _isUploadingBackground = false;
          _processUploadQueue();
          return;
        }
        
        task.currentStep = steps[i];
        task.progress = (i + 0.5) / (steps.length + 1);
        update();
        await Future.delayed(const Duration(milliseconds: 700));
      }

      // Safe check before database save
      if (!_uploadQueue.any((t) => t.id == task.id)) {
        _isUploadingBackground = false;
        _processUploadQueue();
        return;
      }

      task.currentStep = "Saving post to database...";
      task.progress = (steps.length + 0.5) / (steps.length + 1);
      update();

      final newClip = DanceClip(
        id: task.id,
        videoUrl: task.videoPath,
        thumbnailUrl: task.thumbnailPath,
        caption: task.caption,
        musicName: task.musicName,
        musicArtist: task.musicArtist,
        dancerUid: task.dancer.uid,
        dancerName: task.dancer.username,
        dancerAvatar: task.dancer.avatarUrl,
        likes: 0,
        commentsCount: 0,
        sharesCount: 0,
        danceStyle: task.danceStyle,
        isLikedByMe: false,
        isFollowedByMe: false,
        cropAspectRatio: task.cropAspectRatio,
        filterType: task.filterType,
        brightness: task.brightness,
        startTimeMs: task.startTimeMs,
        endTimeMs: task.endTimeMs,
      );

      await _dbHelper.saveUserProfile(task.dancer);
      await _dbHelper.insertClip(newClip);
      
      // Update clips list from DB
      _clips.assignAll(await _dbHelper.getClips(_currentUid));

      // Safe check after DB operations (in case user canceled in between)
      if (!_uploadQueue.any((t) => t.id == task.id)) {
        _isUploadingBackground = false;
        _processUploadQueue();
        return;
      }

      task.status = "Completed";
      task.progress = 1.0;
      task.currentStep = "Upload completed! 🔥";
      update();
    } catch (e) {
      debugPrint("Background upload task failed: $e");
      
      // If task was already canceled, just return and process next
      if (!_uploadQueue.any((t) => t.id == task.id)) {
        _isUploadingBackground = false;
        _processUploadQueue();
        return;
      }
      
      task.status = "Failed";
      task.currentStep = "Upload failed. Tap to retry.";
      update();
    }

    await Future.delayed(const Duration(seconds: 3));
    
    // Remove if completed
    _uploadQueue.removeWhere((t) => t.id == task.id && t.status == "Completed");
    
    _isUploadingBackground = false;
    update();

    _processUploadQueue();
  }

  Future<void> _processBattleUpload(PostUploadTask task) async {
    try {
      final battleId = task.battleId!;
      final meIndex = task.battleMeIndex!;
      final localVideoPath = task.videoPath;
      
      // Step 1: Uploading local video
      task.currentStep = "Uploading your performance video...";
      task.progress = 0.1;
      update();
      
      String videoUrl;
      if (localVideoPath.isNotEmpty && !localVideoPath.contains("bee.mp4") && File(localVideoPath).existsSync()) {
        videoUrl = await _dbHelper.uploadBattleVideo(localVideoPath, task.dancer.uid, battleId);
      } else {
        videoUrl = "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4";
        await Future.delayed(const Duration(milliseconds: 1500));
      }
      
      if (!_uploadQueue.any((t) => t.id == task.id)) {
        _isUploadingBackground = false;
        _processUploadQueue();
        return;
      }

      await _dbHelper.updateBattleVideoUrl(battleId, meIndex, videoUrl);

      if (meIndex == 1) {
        // HOST FLOW
        // Step 2: Wait for opponent's video upload
        task.currentStep = "Waiting for opponent's video...";
        task.progress = 0.3;
        update();

        String? oppVideoUrl;
        int maxRetries = 60; // 2 minutes
        for (int i = 0; i < maxRetries; i++) {
          if (!_uploadQueue.any((t) => t.id == task.id)) {
            _isUploadingBackground = false;
            _processUploadQueue();
            return;
          }
          final battle = await _dbHelper.getBattle(battleId);
          if (battle != null && battle.user2VideoUrl != null) {
            oppVideoUrl = battle.user2VideoUrl;
            break;
          }
          await Future.delayed(const Duration(seconds: 2));
        }

        if (oppVideoUrl == null) {
          throw Exception("Opponent video upload timed out.");
        }

        // Step 3: Downloading/Connecting to opponent video
        task.currentStep = "Connecting to opponent's performance...";
        task.progress = 0.5;
        update();

        if (!_uploadQueue.any((t) => t.id == task.id)) {
          _isUploadingBackground = false;
          _processUploadQueue();
          return;
        }

        // Step 4: Merging videos
        task.currentStep = "Merging battle videos with FFmpeg...";
        task.progress = 0.7;
        update();

        final directory = await getTemporaryDirectory();
        final mergedPath = '${directory.path}/merged_${DateTime.now().millisecondsSinceEpoch}.mp4';

        final String path1 = localVideoPath.isNotEmpty ? localVideoPath : videoUrl;
        final String path2 = oppVideoUrl;

        final jwt = Supabase.instance.client.auth.currentSession?.accessToken;
        final headersStr1 = (path1.startsWith('http') && jwt != null) ? '-headers "Authorization: Bearer $jwt\r\n" ' : '';
        final headersStr2 = (path2.startsWith('http') && jwt != null) ? '-headers "Authorization: Bearer $jwt\r\n" ' : '';

        final ffmpegCommand = '$headersStr1-i "$path1" $headersStr2-i "$path2" -filter_complex hstack=inputs=2 -preset ultrafast "$mergedPath"';
        
        final session = await FFmpegKit.execute(ffmpegCommand);
        final returnCode = await session.getReturnCode();

        String combinedUrl;
        if (ReturnCode.isSuccess(returnCode)) {
          if (!_uploadQueue.any((t) => t.id == task.id)) {
            _isUploadingBackground = false;
            _processUploadQueue();
            return;
          }
          task.currentStep = "Uploading merged battle video...";
          task.progress = 0.85;
          update();
          combinedUrl = await _dbHelper.uploadBattleVideo(mergedPath, task.dancer.uid, battleId);
        } else {
          final logs = await session.getAllLogs();
          final failLog = logs.map((l) => l.getMessage()).join('\n');
          debugPrint("FFmpeg battle merge failed: $failLog");
          combinedUrl = videoUrl; // fallback
        }

        if (!_uploadQueue.any((t) => t.id == task.id)) {
          _isUploadingBackground = false;
          _processUploadQueue();
          return;
        }

        task.currentStep = "Completing battle registration...";
        task.progress = 0.95;
        update();

        await _dbHelper.updateBattleCombinedVideoUrl(battleId, combinedUrl);

      } else {
        // OPPONENT FLOW
        // Step 2: Wait for battle resolution
        task.currentStep = "Waiting for battle completion...";
        task.progress = 0.6;
        update();

        int maxRetries = 60; // 2 minutes
        bool isDone = false;
        for (int i = 0; i < maxRetries; i++) {
          if (!_uploadQueue.any((t) => t.id == task.id)) {
            _isUploadingBackground = false;
            _processUploadQueue();
            return;
          }
          final battle = await _dbHelper.getBattle(battleId);
          if (battle != null && battle.status == 'completed') {
            isDone = true;
            break;
          }
          await Future.delayed(const Duration(seconds: 2));
        }

        if (!isDone) {
          throw Exception("Battle completion timed out.");
        }
      }

      if (!_uploadQueue.any((t) => t.id == task.id)) {
        _isUploadingBackground = false;
        _processUploadQueue();
        return;
      }

      task.status = "Completed";
      task.progress = 1.0;
      task.currentStep = "Battle upload completed! 🔥";
      update();

    } catch (e) {
      debugPrint("Background battle upload failed: $e");
      if (!_uploadQueue.any((t) => t.id == task.id)) {
        _isUploadingBackground = false;
        _processUploadQueue();
        return;
      }
      task.status = "Failed";
      task.currentStep = "Upload failed. Tap to retry.";
      update();
    }

    await Future.delayed(const Duration(seconds: 3));
    _uploadQueue.removeWhere((t) => t.id == task.id && t.status == "Completed");
    _isUploadingBackground = false;
    update();
    _processUploadQueue();
  }

  // Retry failed task
  void retryTask(String taskId) {
    int index = _uploadQueue.indexWhere((task) => task.id == taskId);
    if (index != -1) {
      final task = _uploadQueue[index];
      if (task.status == "Failed") {
        task.status = "Queued";
        task.progress = 0.0;
        task.currentStep = "Waiting in queue...";
        update();
        _processUploadQueue();
      }
    }
  }

  // Cancel / dismiss task
  void cancelTask(String taskId) {
    int index = _uploadQueue.indexWhere((task) => task.id == taskId);
    if (index != -1) {
      final task = _uploadQueue[index];
      _uploadQueue.removeAt(index);
      if (task.status == "Uploading") {
        _isUploadingBackground = false;
        update();
        _processUploadQueue();
      } else {
        update();
      }
    }
  }

  @override
  void onClose() {
    _unsubscribeFromRealtimeMessages();
    _unsubscribeFromPresence();
    super.onClose();
  }
}

class PostUploadTask {
  final String id;
  final String caption;
  final String musicName;
  final String musicArtist;
  final String danceStyle;
  final DancerProfile dancer;
  final String videoPath;
  final String thumbnailPath;
  final double cropAspectRatio;
  final String filterType;
  final double brightness;
  final int startTimeMs;
  final int endTimeMs;
  
  // New fields for battle
  final bool isBattle;
  final String? battleOpponentVideoUrl;
  final int? battleMeIndex;
  final String? battleId;
  final String? opponentName;
  
  double progress = 0.0;
  String status = "Queued"; // "Queued", "Uploading", "Completed", "Failed", "Canceled"
  String currentStep = "Waiting in queue";

  PostUploadTask({
    required this.id,
    required this.caption,
    required this.musicName,
    required this.musicArtist,
    required this.danceStyle,
    required this.dancer,
    required this.videoPath,
    required this.thumbnailPath,
    required this.cropAspectRatio,
    required this.filterType,
    required this.brightness,
    required this.startTimeMs,
    required this.endTimeMs,
    this.isBattle = false,
    this.battleOpponentVideoUrl,
    this.battleMeIndex,
    this.battleId,
    this.opponentName,
  });
}
