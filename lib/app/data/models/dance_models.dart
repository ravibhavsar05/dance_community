import 'dart:convert';

const String defaultAvatarUrl =
    "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&auto=format&fit=crop&q=80";

class DancerProfile {
  final String uid;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String bio;
  final int followersCount;
  final int followingCount;
  final int likesCount;
  final bool isVerified;
  final List<String> danceStyles;
  final String? gender;
  final DateTime? dateOfBirth;

  DancerProfile({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
    required this.followersCount,
    required this.followingCount,
    required this.likesCount,
    this.isVerified = false,
    required this.danceStyles,
    this.gender,
    this.dateOfBirth,
  });

  DancerProfile copyWith({
    String? displayName,
    String? bio,
    int? followersCount,
    int? followingCount,
    int? likesCount,
    String? gender,
    DateTime? dateOfBirth,
  }) {
    return DancerProfile(
      uid: uid,
      username: username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl,
      bio: bio ?? this.bio,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      likesCount: likesCount ?? this.likesCount,
      isVerified: isVerified,
      danceStyles: danceStyles,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
    );
  }
}

class DanceClip {
  final String id;
  final String videoUrl;
  final String thumbnailUrl;
  final String caption;
  final String musicName;
  final String musicArtist;
  final String dancerUid;
  final String dancerName;
  final String dancerAvatar;
  int likes;
  int commentsCount;
  int sharesCount;
  final String danceStyle;
  bool isLikedByMe;
  bool isFollowedByMe;

  // Custom edit parameters
  final double cropAspectRatio;
  final String filterType;
  final double brightness;
  final int startTimeMs;
  final int endTimeMs;

  /// Raw JSON string for multi-media posts stored in the `media_items` DB column.
  /// When non-null, `mediaItems` uses this instead of parsing `videoUrl`.
  final String? mediaItemsJson;

  DanceClip({
    required this.id,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.caption,
    required this.musicName,
    required this.musicArtist,
    required this.dancerUid,
    required this.dancerName,
    required this.dancerAvatar,
    required this.likes,
    required this.commentsCount,
    required this.sharesCount,
    required this.danceStyle,
    this.isLikedByMe = false,
    this.isFollowedByMe = false,
    this.cropAspectRatio = 0.5625, // default 9:16
    this.filterType = 'none',
    this.brightness = 1.0,
    this.startTimeMs = 0,
    this.endTimeMs = 0,
    this.mediaItemsJson,
  });

  List<Map<String, dynamic>> get mediaItems {
    // Prefer dedicated media_items column (avoids VARCHAR(512) limit on video_url)
    final jsonSource = (mediaItemsJson != null && mediaItemsJson!.isNotEmpty)
        ? mediaItemsJson!
        : (videoUrl.startsWith('[') && videoUrl.endsWith(']') ? videoUrl : null);

    if (jsonSource != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonSource);
        return decoded.map((item) {
          final map = Map<String, dynamic>.from(item);
          map['scale'] ??= 1.0;
          map['panX'] ??= 0.0;
          map['panY'] ??= 0.0;
          return map;
        }).toList();
      } catch (e) {
        // Fallback below
      }
    }
    return [
      {
        'url': videoUrl,
        'type': videoUrl.contains('.mp4') || videoUrl.contains('.mov') || videoUrl.contains('playlist.m3u8')
            ? 'video'
            : 'image',
        'cropAspectRatio': cropAspectRatio,
        'filterType': filterType,
        'brightness': brightness,
        'startTimeMs': startTimeMs,
        'endTimeMs': endTimeMs,
        'scale': 1.0,
        'panX': 0.0,
        'panY': 0.0,
      },
    ];
  }
}

class Comment {
  final String id;
  final String username;
  final String avatarUrl;
  final String commentText;
  final DateTime timestamp;

  Comment({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.commentText,
    required this.timestamp,
  });
}

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String text;
  final DateTime timestamp;
  final bool isEdited;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.text,
    required this.timestamp,
    this.isEdited = false,
  });

  ChatMessage copyWith({String? text, bool? isEdited}) {
    return ChatMessage(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      text: text ?? this.text,
      timestamp: timestamp,
      isEdited: isEdited ?? this.isEdited,
    );
  }
}

class ChatRoom {
  final String id;
  final DancerProfile otherUser;
  final List<ChatMessage> messages;

  ChatRoom({required this.id, required this.otherUser, required this.messages});

  ChatMessage? get lastMessage => messages.isNotEmpty ? messages.last : null;
}

class DanceBattle {
  final String id;
  final String user1Uid;
  final String user2Uid;
  final String? user1VideoUrl;
  final String? user2VideoUrl;
  final String? combinedVideoUrl;
  final String status; // 'matched', 'ongoing', 'completed'
  final String? firstDancerUid;
  final int user1Votes;
  final int user2Votes;
  final DateTime createdAt;
  final DateTime votingEndsAt;
  final String? winnerUid;
  final String? forfeitWinnerUid;
  final int likes;
  final int commentsCount;

  // WebRTC signaling fields
  final String? offerSdp;
  final String? answerSdp;
  final List<dynamic>? iceCandidatesUser1;
  final List<dynamic>? iceCandidatesUser2;

  DanceBattle({
    required this.id,
    required this.user1Uid,
    required this.user2Uid,
    this.user1VideoUrl,
    this.user2VideoUrl,
    this.combinedVideoUrl,
    required this.status,
    this.firstDancerUid,
    required this.user1Votes,
    required this.user2Votes,
    required this.createdAt,
    required this.votingEndsAt,
    this.winnerUid,
    this.forfeitWinnerUid,
    this.offerSdp,
    this.answerSdp,
    this.iceCandidatesUser1,
    this.iceCandidatesUser2,
    this.likes = 0,
    this.commentsCount = 0,
  });

  factory DanceBattle.fromMap(Map<String, dynamic> map) {
    return DanceBattle(
      id: map['id'] as String,
      user1Uid: map['user1_uid'] as String,
      user2Uid: map['user2_uid'] as String,
      user1VideoUrl: map['user1_video_url'] as String?,
      user2VideoUrl: map['user2_video_url'] as String?,
      combinedVideoUrl: map['combined_video_url'] as String?,
      status: map['status'] as String? ?? 'matched',
      firstDancerUid: map['first_dancer_uid'] as String?,
      user1Votes: map['user1_votes'] as int? ?? 0,
      user2Votes: map['user2_votes'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      votingEndsAt: DateTime.parse(map['voting_ends_at'] as String),
      winnerUid: map['winner_uid'] as String?,
      forfeitWinnerUid: map['forfeit_winner_uid'] as String?,
      offerSdp: map['offer_sdp'] as String?,
      answerSdp: map['answer_sdp'] as String?,
      iceCandidatesUser1: map['ice_candidates_user1'] as List<dynamic>?,
      iceCandidatesUser2: map['ice_candidates_user2'] as List<dynamic>?,
      likes: map['likes'] as int? ?? 0,
      commentsCount: map['comments_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user1_uid': user1Uid,
      'user2_uid': user2Uid,
      'user1_video_url': user1VideoUrl,
      'user2_video_url': user2VideoUrl,
      'combined_video_url': combinedVideoUrl,
      'status': status,
      'first_dancer_uid': firstDancerUid,
      'user1_votes': user1Votes,
      'user2_votes': user2Votes,
      'created_at': createdAt.toIso8601String(),
      'voting_ends_at': votingEndsAt.toIso8601String(),
      'winner_uid': winnerUid,
      'forfeit_winner_uid': forfeitWinnerUid,
      'offer_sdp': offerSdp,
      'answer_sdp': answerSdp,
      'ice_candidates_user1': iceCandidatesUser1,
      'ice_candidates_user2': iceCandidatesUser2,
      'likes': likes,
      'comments_count': commentsCount,
    };
  }
}

class BattleVote {
  final String id;
  final String battleId;
  final String voterUid;
  final String votedForUid;
  final DateTime createdAt;

  BattleVote({
    required this.id,
    required this.battleId,
    required this.voterUid,
    required this.votedForUid,
    required this.createdAt,
  });

  factory BattleVote.fromMap(Map<String, dynamic> map) {
    return BattleVote(
      id: map['id'] as String,
      battleId: map['battle_id'] as String,
      voterUid: map['voter_uid'] as String,
      votedForUid: map['voted_for_uid'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'battle_id': battleId,
      'voter_uid': voterUid,
      'voted_for_uid': votedForUid,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class LiveStreamSession {
  final String id;
  final String hostUid;
  final String hostName;
  final String hostAvatar;
  final String title;
  final String status; // 'live', 'ended'
  final DateTime createdAt;
  final int viewerCount;
  final String? offerSdp;
  final String? answerSdp;
  final List<dynamic>? iceCandidatesHost;
  final List<dynamic>? iceCandidatesViewer;

  LiveStreamSession({
    required this.id,
    required this.hostUid,
    required this.hostName,
    required this.hostAvatar,
    required this.title,
    this.status = 'live',
    required this.createdAt,
    this.viewerCount = 0,
    this.offerSdp,
    this.answerSdp,
    this.iceCandidatesHost,
    this.iceCandidatesViewer,
  });

  factory LiveStreamSession.fromMap(Map<String, dynamic> map, {required String hostName, required String hostAvatar}) {
    return LiveStreamSession(
      id: map['id'] as String,
      hostUid: map['host_uid'] as String,
      hostName: hostName,
      hostAvatar: hostAvatar,
      title: map['title'] as String,
      status: map['status'] as String? ?? 'live',
      createdAt: DateTime.parse(map['created_at'] as String),
      viewerCount: map['viewer_count'] as int? ?? 0,
      offerSdp: map['offer_sdp'] as String?,
      answerSdp: map['answer_sdp'] as String?,
      iceCandidatesHost: map['ice_candidates_host'] as List<dynamic>?,
      iceCandidatesViewer: map['ice_candidates_viewer'] as List<dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'host_uid': hostUid,
      'title': title,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'viewer_count': viewerCount,
    };
    // Only include WebRTC signalling fields when they have a value.
    // Sending null for a column that doesn't exist yet causes PGRST204.
    if (offerSdp != null) map['offer_sdp'] = offerSdp;
    if (answerSdp != null) map['answer_sdp'] = answerSdp;
    if (iceCandidatesHost != null) map['ice_candidates_host'] = iceCandidatesHost;
    if (iceCandidatesViewer != null) map['ice_candidates_viewer'] = iceCandidatesViewer;
    return map;
  }
}

class LiveStreamMessage {
  final String id;
  final String streamId;
  final String senderUid;
  final String senderName;
  final String senderAvatar;
  final String messageText;
  final DateTime timestamp;

  LiveStreamMessage({
    required this.id,
    required this.streamId,
    required this.senderUid,
    required this.senderName,
    required this.senderAvatar,
    required this.messageText,
    required this.timestamp,
  });

  factory LiveStreamMessage.fromMap(Map<String, dynamic> map) {
    return LiveStreamMessage(
      id: map['id'] as String,
      streamId: map['stream_id'] as String,
      senderUid: map['sender_uid'] as String,
      senderName: map['sender_name'] as String,
      senderAvatar: map['sender_avatar'] as String? ?? defaultAvatarUrl,
      messageText: map['message_text'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'stream_id': streamId,
      'sender_uid': senderUid,
      'sender_name': senderName,
      'sender_avatar': senderAvatar,
      'message_text': messageText,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
