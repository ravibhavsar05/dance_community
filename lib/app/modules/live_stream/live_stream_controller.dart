import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:dance_pulse/app/utils/app_logger.dart';
import 'package:dance_pulse/app/data/models/dance_models.dart';
import 'package:dance_pulse/app/data/services/supabase_store.dart';
import 'package:dance_pulse/app/controllers/auth_controller.dart';
import 'package:dance_pulse/app/ui/theme/app_theme.dart';

class LiveStreamController extends GetxController {
  // --- Active Streams List ---
  final RxList<LiveStreamSession> activeLiveStreams = <LiveStreamSession>[].obs;
  StreamSubscription? _streamsSubscription;

  // --- Active Stream details ---
  final Rxn<LiveStreamSession> currentSession = Rxn<LiveStreamSession>();
  final RxList<LiveStreamMessage> currentChatMessages = <LiveStreamMessage>[].obs;
  StreamSubscription? _chatSubscription;
  StreamSubscription? _statusSubscription;

  // --- WebRTC / Camera Renderer ---
  final webrtc.RTCVideoRenderer localRenderer = webrtc.RTCVideoRenderer();
  final webrtc.RTCVideoRenderer remoteRenderer = webrtc.RTCVideoRenderer();
  webrtc.MediaStream? localStream;
  final RxBool isCameraInitialized = false.obs;
  final RxBool isMuted = false.obs;
  final RxBool isFrontCamera = true.obs;

  // --- WebRTC live stream variables ---
  webrtc.RTCPeerConnection? peerConnection;
  final RxBool isWebRTCInitialized = false.obs;
  final Set<String> _processedCandidateIds = {};

  // --- Live Viewer Count ---
  final RxInt viewerCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    localRenderer.initialize();
    remoteRenderer.initialize();
    listenToActiveStreams();
  }

  @override
  void onClose() {
    _streamsSubscription?.cancel();
    _chatSubscription?.cancel();
    _statusSubscription?.cancel();
    localRenderer.dispose();
    remoteRenderer.dispose();
    _releaseCamera();
    _closeWebRTCConnection();
    super.onClose();
  }

  // --- Realtime active streams listener ---
  void listenToActiveStreams() {
    _streamsSubscription?.cancel();
    _streamsSubscription = SupabaseStore.instance.getActiveStreamsStream().listen((data) async {
      try {
        final List<LiveStreamSession> sessions = [];
        for (var row in data) {
          final status = row['status'] as String? ?? 'live';
          if (status != 'live') {
            continue;
          }

          final hostUid = row['host_uid'] as String;
          // Retrieve user profile details from the cache or DB
          final profileMap = await Supabase.instance.client.from('users').select().eq('uid', hostUid).maybeSingle();
          final hostName = profileMap != null ? profileMap['display_name'] as String? ?? 'Dancer' : 'Dancer';
          final hostAvatar = profileMap != null ? profileMap['avatar_url'] as String? ?? defaultAvatarUrl : defaultAvatarUrl;

          sessions.add(LiveStreamSession.fromMap(row, hostName: hostName, hostAvatar: hostAvatar));
        }
        activeLiveStreams.value = sessions;
      } catch (e) {
        appLog("Error in active streams listener: $e");
      }
    });
  }

  // --- Camera Streaming logic (Host) ---
  Future<void> initializeHostCamera() async {
    try {
      _releaseCamera();

      final mediaConstraints = {
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': 1280,
          'height': 720,
          'frameRate': 30,
        }
      };

      localStream = await webrtc.navigator.mediaDevices.getUserMedia(mediaConstraints);
      localRenderer.srcObject = localStream;
      isCameraInitialized.value = true;
      isMuted.value = false;
      isFrontCamera.value = true;
    } catch (e) {
      appLog("Error initializing host camera: $e");
      Get.snackbar(
        "Camera Error",
        "Unable to access camera: $e",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }

  void _releaseCamera() {
    isCameraInitialized.value = false;
    localStream?.dispose();
    localStream = null;
    localRenderer.srcObject = null;
  }

  // --- Host Actions: Start / Stop Stream ---
  Future<void> startStream(String title) async {
    final authController = Get.find<AuthController>();
    final currentUser = authController.currentUserProfile;
    if (currentUser == null) return;

    final streamId = 'stream_${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}';
    final newSession = LiveStreamSession(
      id: streamId,
      hostUid: currentUser.uid,
      hostName: currentUser.displayName,
      hostAvatar: currentUser.avatarUrl,
      title: title,
      createdAt: DateTime.now(),
    );

    try {
      await SupabaseStore.instance.startLiveStream(newSession);
      currentSession.value = newSession;
      joinChatRoom(streamId);
      
      // Initialize Host WebRTC Connection
      await setupWebRTCConnection(true, streamId);
      
      // Host listens to status to get realtime viewer count updates and WebRTC answer
      _statusSubscription?.cancel();
      _statusSubscription = SupabaseStore.instance.getLiveStreamStatusStream(streamId).listen((data) async {
        if (data.isNotEmpty) {
          final count = data.first['viewer_count'] as int? ?? 0;
          viewerCount.value = count;

          final updatedSession = await SupabaseStore.instance.getLiveStreamSession(streamId);
          if (updatedSession != null) {
            handleHostSignalingUpdate(updatedSession);
          }
        }
      });
    } catch (e) {
      appLog("Failed to start live stream: $e");
      Get.snackbar(
        "Stream Error",
        "Could not go live: $e",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
      rethrow;
    }
  }

  Future<void> stopStream() async {
    if (currentSession.value == null) return;

    try {
      await SupabaseStore.instance.endLiveStream(currentSession.value!.id);
      _chatSubscription?.cancel();
      _statusSubscription?.cancel();
      currentChatMessages.clear();
      currentSession.value = null;
      _releaseCamera();
      _closeWebRTCConnection();
    } catch (e) {
      appLog("Failed to stop live stream: $e");
    }
  }

  // --- Viewer Actions: Join / Leave Stream ---
  void joinStream(LiveStreamSession session) async {
    currentSession.value = session;
    joinChatRoom(session.id);

    // Increment viewer count in database
    SupabaseStore.instance.incrementViewerCount(session.id);

    // Initialize Viewer WebRTC Connection
    await setupWebRTCConnection(false, session.id);

    // Listen to status changes of this live stream and WebRTC offer
    _statusSubscription?.cancel();
    _statusSubscription = SupabaseStore.instance.getLiveStreamStatusStream(session.id).listen((data) async {
      if (data.isNotEmpty) {
        final status = data.first['status'] as String?;
        if (status == 'ended') {
          handleStreamEnded();
        } else {
          // Update viewer count from database
          final count = data.first['viewer_count'] as int? ?? 0;
          viewerCount.value = count;

          final updatedSession = await SupabaseStore.instance.getLiveStreamSession(session.id);
          if (updatedSession != null) {
            handleViewerSignalingUpdate(updatedSession);
          }
        }
      }
    });
  }

  void leaveStream() {
    if (currentSession.value != null) {
      SupabaseStore.instance.decrementViewerCount(currentSession.value!.id);
    }
    _statusSubscription?.cancel();
    _chatSubscription?.cancel();
    currentChatMessages.clear();
    currentSession.value = null;
    _closeWebRTCConnection();
  }

  void handleStreamEnded() {
    if (currentSession.value != null) {
      _statusSubscription?.cancel();
      _chatSubscription?.cancel();
      currentChatMessages.clear();
      currentSession.value = null;
      _closeWebRTCConnection();

      // Pop the screen back to feed
      Get.back();

      Get.snackbar(
        "Stream Ended",
        "The host has ended the live stream.",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    }
  }

  // --- WebRTC signaling methods for live streams ---
  Future<void> setupWebRTCConnection(bool isHost, String streamId) async {
    try {
      final config = {
        'iceServers': [
          {'url': 'stun:stun.l.google.com:19302'},
        ]
      };
      
      peerConnection = await webrtc.createPeerConnection(config);
      
      peerConnection!.onIceCandidate = (candidate) {
        SupabaseStore.instance.addLiveStreamIceCandidate(streamId, isHost, {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      };

      if (isHost) {
        // Host adds local camera stream tracks
        if (localStream != null) {
          localStream!.getTracks().forEach((track) {
            peerConnection!.addTrack(track, localStream!);
          });
        }

        final offer = await peerConnection!.createOffer();
        await peerConnection!.setLocalDescription(offer);
        await SupabaseStore.instance.sendLiveStreamSdpOffer(streamId, offer.sdp!);
      } else {
        // Viewer gets remote tracks
        peerConnection!.onTrack = (event) {
          if (event.track.kind == 'video' && event.streams.isNotEmpty) {
            remoteRenderer.srcObject = event.streams[0];
          }
        };
      }

      isWebRTCInitialized.value = true;
    } catch (e) {
      appLog("Live stream WebRTC setup error: $e");
    }
  }

  void handleHostSignalingUpdate(LiveStreamSession session) async {
    if (peerConnection == null) return;

    if (session.answerSdp != null && (await peerConnection!.getRemoteDescription()) == null) {
      final answer = webrtc.RTCSessionDescription(session.answerSdp!, 'answer');
      await peerConnection!.setRemoteDescription(answer);
    }
    
    final viewerCandidates = session.iceCandidatesViewer;
    if (viewerCandidates != null && viewerCandidates.isNotEmpty && (await peerConnection!.getRemoteDescription()) != null) {
      for (var c in viewerCandidates) {
        final candidateStr = c['candidate']?.toString() ?? '';
        if (candidateStr.isNotEmpty && !_processedCandidateIds.contains(candidateStr)) {
          _processedCandidateIds.add(candidateStr);
          try {
            final candidate = webrtc.RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']);
            await peerConnection!.addCandidate(candidate);
          } catch (e) {
            appLog("Error adding ICE candidate: $e");
            _processedCandidateIds.remove(candidateStr);
          }
        }
      }
    }
  }

  void handleViewerSignalingUpdate(LiveStreamSession session) async {
    if (peerConnection == null) return;

    if (session.offerSdp != null && (await peerConnection!.getRemoteDescription()) == null) {
      final offer = webrtc.RTCSessionDescription(session.offerSdp!, 'offer');
      await peerConnection!.setRemoteDescription(offer);
      
      final answer = await peerConnection!.createAnswer();
      await peerConnection!.setLocalDescription(answer);
      await SupabaseStore.instance.sendLiveStreamSdpAnswer(session.id, answer.sdp!);
    }

    final hostCandidates = session.iceCandidatesHost;
    if (hostCandidates != null && hostCandidates.isNotEmpty && (await peerConnection!.getRemoteDescription()) != null) {
      for (var c in hostCandidates) {
        final candidateStr = c['candidate']?.toString() ?? '';
        if (candidateStr.isNotEmpty && !_processedCandidateIds.contains(candidateStr)) {
          _processedCandidateIds.add(candidateStr);
          try {
            final candidate = webrtc.RTCIceCandidate(c['candidate'], c['sdpMid'], c['sdpMLineIndex']);
            await peerConnection!.addCandidate(candidate);
          } catch (e) {
            appLog("Error adding ICE candidate: $e");
            _processedCandidateIds.remove(candidateStr);
          }
        }
      }
    }
  }

  void _closeWebRTCConnection() {
    isWebRTCInitialized.value = false;
    peerConnection?.close();
    peerConnection = null;
    remoteRenderer.srcObject = null;
    _processedCandidateIds.clear();
  }

  // --- Realtime Chat Room Logic ---
  void joinChatRoom(String streamId) {
    _chatSubscription?.cancel();
    currentChatMessages.clear();

    _chatSubscription = SupabaseStore.instance.getLiveStreamMessagesStream(streamId).listen((data) {
      try {
        final List<LiveStreamMessage> messages = data.map((row) => LiveStreamMessage.fromMap(row)).toList();
        currentChatMessages.value = messages;
      } catch (e) {
        appLog("Error parsing chat messages: $e");
      }
    });
  }

  Future<void> sendChatMessage(String text) async {
    if (currentSession.value == null || text.trim().isEmpty) return;

    final authController = Get.find<AuthController>();
    final currentUser = authController.currentUserProfile;
    if (currentUser == null) return;

    final newMessage = LiveStreamMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(1000)}',
      streamId: currentSession.value!.id,
      senderUid: currentUser.uid,
      senderName: currentUser.displayName,
      senderAvatar: currentUser.avatarUrl,
      messageText: text.trim(),
      timestamp: DateTime.now(),
    );

    try {
      await SupabaseStore.instance.sendLiveChatMessage(newMessage);
    } catch (e) {
      appLog("Error sending chat message: $e");
    }
  }

  void toggleMute() {
    if (localStream != null) {
      final audioTracks = localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        final currentMute = isMuted.value;
        for (var track in audioTracks) {
          track.enabled = currentMute;
        }
        isMuted.value = !currentMute;
      }
    }
  }

  Future<void> switchCamera() async {
    if (localStream != null) {
      final videoTracks = localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        final videoTrack = videoTracks.first;
        await webrtc.Helper.switchCamera(videoTrack);
        isFrontCamera.value = !isFrontCamera.value;
      }
    }
  }

  void showViewerList() async {
    List<DancerProfile> viewers = [];
    try {
      viewers = await SupabaseStore.instance.getAllUsers();
    } catch (e) {
      appLog("Error fetching viewers: $e");
    }

    final currentCount = viewerCount.value;
    if (viewers.isNotEmpty && currentCount < viewers.length) {
      viewers.shuffle();
      viewers = viewers.take(math.max(1, currentCount)).toList();
    }

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.only(top: 12, left: 16, right: 16, bottom: 24),
        decoration: BoxDecoration(
          color: Get.theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: Colors.white12, width: 0.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Live Viewers (${viewerCount.value})",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  currentSession.value != null ? "Room: ${currentSession.value!.title}" : "",
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (viewers.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    "No viewers yet",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: viewers.length,
                  itemBuilder: (context, index) {
                    final viewer = viewers[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: NetworkImage(
                              viewer.avatarUrl,
                              headers: SupabaseStore.getHeadersForUrl(viewer.avatarUrl),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  viewer.displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  "@${viewer.username}",
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5), width: 0.5),
                            ),
                            child: const Text(
                              "Watching",
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
    );
  }
}
