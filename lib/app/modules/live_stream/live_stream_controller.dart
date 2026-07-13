import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:firebasecrashreport/app/utils/app_logger.dart';
import 'package:firebasecrashreport/app/data/models/dance_models.dart';
import 'package:firebasecrashreport/app/data/services/supabase_store.dart';
import 'package:firebasecrashreport/app/controllers/auth_controller.dart';

class LiveStreamController extends GetxController {
  // --- Active Streams List ---
  final RxList<LiveStreamSession> activeLiveStreams = <LiveStreamSession>[].obs;
  StreamSubscription? _streamsSubscription;

  // --- Active Stream details ---
  final Rxn<LiveStreamSession> currentSession = Rxn<LiveStreamSession>();
  final RxList<LiveStreamMessage> currentChatMessages = <LiveStreamMessage>[].obs;
  StreamSubscription? _chatSubscription;

  // --- WebRTC / Camera Renderer ---
  final webrtc.RTCVideoRenderer localRenderer = webrtc.RTCVideoRenderer();
  webrtc.MediaStream? localStream;
  final RxBool isCameraInitialized = false.obs;

  // --- Simulated Viewer Count ---
  final RxInt viewerCount = 0.obs;
  Timer? _viewerCountTimer;

  @override
  void onInit() {
    super.onInit();
    localRenderer.initialize();
    listenToActiveStreams();
  }

  @override
  void onClose() {
    _streamsSubscription?.cancel();
    _chatSubscription?.cancel();
    _viewerCountTimer?.cancel();
    localRenderer.dispose();
    _releaseCamera();
    super.onClose();
  }

  // --- Realtime active streams listener ---
  void listenToActiveStreams() {
    _streamsSubscription?.cancel();
    _streamsSubscription = SupabaseStore.instance.getActiveStreamsStream().listen((data) async {
      try {
        final List<LiveStreamSession> sessions = [];
        for (var row in data) {
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
      startViewerCountSimulation();
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
      _viewerCountTimer?.cancel();
      _chatSubscription?.cancel();
      currentChatMessages.clear();
      currentSession.value = null;
      _releaseCamera();
    } catch (e) {
      appLog("Failed to stop live stream: $e");
    }
  }

  // --- Viewer Actions: Join / Leave Stream ---
  void joinStream(LiveStreamSession session) {
    currentSession.value = session;
    joinChatRoom(session.id);
    startViewerCountSimulation();
  }

  void leaveStream() {
    _viewerCountTimer?.cancel();
    _chatSubscription?.cancel();
    currentChatMessages.clear();
    currentSession.value = null;
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

  // --- Viewer Simulation ---
  void startViewerCountSimulation() {
    _viewerCountTimer?.cancel();
    // Start with a dynamic count
    viewerCount.value = 5 + math.Random().nextInt(11); // 5 to 15 viewers

    _viewerCountTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      final change = math.Random().nextInt(3) - 1; // -1, 0, or +1
      final newCount = viewerCount.value + change;
      viewerCount.value = newCount.clamp(1, 100);
    });
  }
}
