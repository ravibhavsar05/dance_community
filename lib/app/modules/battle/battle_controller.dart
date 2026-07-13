import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dance_pulse/app/utils/app_logger.dart';
import 'package:dance_pulse/app/data/models/dance_models.dart';
import 'package:dance_pulse/app/data/services/supabase_store.dart';
import 'package:dance_pulse/app/utils/app_strings.dart';
import 'package:dance_pulse/app/controllers/auth_controller.dart';
import 'package:dance_pulse/app/modules/home_feed/feed_controller.dart';
import 'package:dance_pulse/app/data/services/battle_audio_service.dart';

class BattleController extends GetxController with GetTickerProviderStateMixin {
  // --- Matchmaking State ---
  Timer? _countdownTimer;
  Timer? _pollingTimer;
  final RxInt secondsLeft = BattleMatchingStrings.searchDurationSeconds.obs;
  final RxBool isMatched = false.obs;
  final RxString statusText = BattleMatchingStrings.searchingForDancers.obs;
  final Rxn<DancerProfile> opponentProfile = Rxn<DancerProfile>();
  final Rxn<DanceBattle> activeBattle = Rxn<DanceBattle>();

  // --- Battle Arena State ---
  final Rxn<DanceBattle> currentBattleState = Rxn<DanceBattle>();
  StreamSubscription? _battleDbSubscription;
  final RxString arenaStage = 'spin'.obs;
  final RxInt arenaSecondsLeft = BattleArenaStrings.spinDurationSeconds.obs;
  final RxBool isSpinning = false.obs;
  final RxnString firstDancerUid = RxnString();
  final RxString arenaStageText = BattleArenaStrings.spinningBottle.obs;
  final Rxn<XFile> myRecordedVideo = Rxn<XFile>();
  final RxnString myVideoUrl = RxnString();
  final RxnString opponentVideoUrl = RxnString();
  final RxBool isWebRTCInitialized = false.obs;

  // --- Tickers and Ticker States ---
  late AnimationController pulseController;
  late AnimationController spinController;
  late Animation<double> spinAnimation;

  // --- WebRTC Fields ---
  final webrtc.RTCVideoRenderer localRenderer = webrtc.RTCVideoRenderer();
  final webrtc.RTCVideoRenderer remoteRenderer = webrtc.RTCVideoRenderer();
  webrtc.RTCPeerConnection? peerConnection;
  webrtc.MediaStream? localStream;
  webrtc.MediaRecorder? mediaRecorder;
  final Set<String> _processedCandidateIds = {};

  // --- Setup Helpers ---
  String? activeBattleId;
  late DancerProfile me;
  late int meIndex;
  late int opponentIndex;
  late DancerProfile opponent;

  // --- Arena Timer ---
  Timer? _stageTimer;

  @override
  void onInit() {
    super.onInit();
    localRenderer.initialize();
    remoteRenderer.initialize();

    pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: BattleArenaStrings.spinDurationSeconds),
    );
    spinAnimation = Tween<double>(begin: 0.0, end: 0.0).animate(spinController);
  }

  @override
  void onClose() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    _battleDbSubscription?.cancel();
    _stageTimer?.cancel();
    
    if (Get.isRegistered<BattleAudioService>()) {
      Get.find<BattleAudioService>().stopAll();
    }
    
    pulseController.dispose();
    spinController.dispose();
    localRenderer.dispose();
    remoteRenderer.dispose();
    _closeWebRTCConnection();
    super.onClose();
  }

  // --- Matchmaking Methods ---
  void startMatchmaking(String currentUid, Function(DanceBattle, DancerProfile) onMatchFound) async {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();

    isMatched.value = false;
    opponentProfile.value = null;
    activeBattle.value = null;
    secondsLeft.value = BattleMatchingStrings.searchDurationSeconds;
    statusText.value = BattleMatchingStrings.searchingForDancers;

    try {
      await SupabaseStore.instance.joinMatchmakingQueue(currentUid);
    } catch (e) {
      Get.snackbar(
        BattleMatchingStrings.matchmakingError,
        "${BattleMatchingStrings.failedToJoinQueue}${e.toString()}",
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
      cancelMatchmaking(currentUid);
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsLeft.value > 0) {
        secondsLeft.value--;
      } else {
        cancelMatchmaking(currentUid, timeout: true);
      }
    });

    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (isMatched.value) return;

      final match = await SupabaseStore.instance.checkForAvailableMatch(currentUid);
      if (match != null) {
        _handleMatchFound(match, currentUid, onMatchFound);
        return;
      }

      final client = Supabase.instance.client;
      final response = await client
          .from('battles')
          .select()
          .or('user1_uid.eq.$currentUid,user2_uid.eq.$currentUid')
          .eq('status', 'matched')
          .maybeSingle();

      if (response != null) {
        final foundBattle = DanceBattle.fromMap(response);
        _handleMatchFound(foundBattle, currentUid, onMatchFound);
      }
    });
  }

  void _handleMatchFound(DanceBattle battle, String currentUid, Function(DanceBattle, DancerProfile) onMatchFound) async {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();

    final opponentUid = battle.user1Uid == currentUid ? battle.user2Uid : battle.user1Uid;
    final profile = await SupabaseStore.instance.getUserProfile(opponentUid);

    isMatched.value = true;
    activeBattle.value = battle;
    opponentProfile.value = profile;
    statusText.value = BattleMatchingStrings.opponentMatched;

    if (profile != null) {
      onMatchFound(battle, profile);
    }
  }

  void cancelMatchmaking(String currentUid, {bool timeout = false}) async {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();

    await SupabaseStore.instance.leaveMatchmakingQueue(currentUid);

    secondsLeft.value = 0;
    statusText.value = timeout ? BattleMatchingStrings.noMatchFound : BattleMatchingStrings.cancelled;
  }

  // --- Battle Arena Setup ---
  void setupArena(DanceBattle battle, DancerProfile opponentProfileData) {
    if (activeBattleId == battle.id) return;
    
    activeBattleId = battle.id;
    currentBattleState.value = battle;
    opponent = opponentProfileData;
    
    me = Get.find<AuthController>().currentUserProfile!;
    meIndex = battle.user1Uid == me.uid ? 1 : 2;
    opponentIndex = 3 - meIndex;

    // Reset arena stages
    arenaStage.value = 'spin';
    arenaSecondsLeft.value = BattleArenaStrings.spinDurationSeconds;
    isSpinning.value = false;
    firstDancerUid.value = null;
    arenaStageText.value = BattleArenaStrings.spinningBottle;
    myRecordedVideo.value = null;
    myVideoUrl.value = null;
    opponentVideoUrl.value = null;
    isWebRTCInitialized.value = false;

    startArenaSubscription(battle.id);

    // Host handles first-turn selection
    if (meIndex == 1) {
      selectFirstDancer(battle.id, battle.user1Uid, battle.user2Uid);
    }
  }

  // --- Battle Arena Methods ---
  void subscribeToBattle(String battleId, Function(DanceBattle) onBattleUpdated) {
    _battleDbSubscription?.cancel();
    
    final client = Supabase.instance.client;
    _battleDbSubscription = client
        .from('battles')
        .stream(primaryKey: ['id'])
        .eq('id', battleId)
        .listen((List<Map<String, dynamic>> data) {
          if (data.isEmpty) return;
          final updatedBattle = DanceBattle.fromMap(data.first);
          currentBattleState.value = updatedBattle;
          onBattleUpdated(updatedBattle);
        });
  }

  void unsubscribeFromBattle() {
    _battleDbSubscription?.cancel();
    _battleDbSubscription = null;
  }

  void startArenaSubscription(String battleId) {
    subscribeToBattle(battleId, (updatedBattle) {
      if (updatedBattle.forfeitWinnerUid != null && arenaStage.value != 'completed') {
        handleForfeit(updatedBattle);
        return;
      }

      currentBattleState.value = updatedBattle;

      // Check if first dancer has been set & spin needs to start
      if (arenaStage.value == 'spin' && !isSpinning.value && updatedBattle.firstDancerUid != null) {
        firstDancerUid.value = updatedBattle.firstDancerUid;
        startSpinAnimation();
      }

      // Handle incoming WebRTC signaling if ongoing
      if (arenaStage.value.startsWith('turn_') && isWebRTCInitialized.value) {
        handleSignalingUpdate(updatedBattle);
      }

      // Handle video URL updates from opponent
      final oppVideo = opponentIndex == 1 ? updatedBattle.user1VideoUrl : updatedBattle.user2VideoUrl;
      if (oppVideo != null && opponentVideoUrl.value == null) {
        setOpponentVideoUrl(oppVideo);
        checkAndMergeVideos();
      }
    });
  }

  Future<void> selectFirstDancer(String battleId, String user1Uid, String user2Uid) async {
    final uids = [user1Uid, user2Uid];
    final selectedUid = uids[math.Random().nextInt(2)];
    await SupabaseStore.instance.updateBattleFirstDancer(battleId, selectedUid);
  }

  Future<void> updateBattleVideoUrl(String battleId, int userIndex, String url) async {
    await SupabaseStore.instance.updateBattleVideoUrl(battleId, userIndex, url);
  }

  Future<void> updateBattleCombinedVideoUrl(String battleId, String url) async {
    await SupabaseStore.instance.updateBattleCombinedVideoUrl(battleId, url);
  }

  Future<void> forfeitBattle(String battleId, String userUid) async {
    await SupabaseStore.instance.forfeitBattle(battleId, userUid);
  }

  Future<void> clearBattleSignaling(String battleId) async {
    await SupabaseStore.instance.clearBattleSignaling(battleId);
  }

  Future<void> addIceCandidate(String battleId, int userIndex, Map<String, dynamic> candidate) async {
    await SupabaseStore.instance.addIceCandidate(battleId, userIndex, candidate);
  }

  Future<void> sendSdpOffer(String battleId, String sdp) async {
    await SupabaseStore.instance.sendSdpOffer(battleId, sdp);
  }

  Future<void> sendSdpAnswer(String battleId, String sdp) async {
    await SupabaseStore.instance.sendSdpAnswer(battleId, sdp);
  }

  void setArenaStage(String stage) {
    arenaStage.value = stage;
  }

  void setArenaSecondsLeft(int seconds) {
    arenaSecondsLeft.value = seconds;
  }

  void setSpinning(bool spinning) {
    isSpinning.value = spinning;
  }

  void setFirstDancerUid(String? uid) {
    firstDancerUid.value = uid;
  }

  void setArenaStageText(String text) {
    arenaStageText.value = text;
  }

  void setMyRecordedVideo(XFile? video) {
    myRecordedVideo.value = video;
  }

  void setMyVideoUrl(String? url) {
    myVideoUrl.value = url;
  }

  void setOpponentVideoUrl(String? url) {
    opponentVideoUrl.value = url;
  }

  void setWebRTCInitialized(bool initialized) {
    isWebRTCInitialized.value = initialized;
  }

  void updateArenaState({
    String? stage,
    int? secondsLeft,
    bool? spinning,
    String? firstDancer,
    String? stageText,
    XFile? recordedVideo,
    String? videoUrl,
    String? oppVideoUrl,
    bool? webRTCInit,
  }) {
    if (stage != null) arenaStage.value = stage;
    if (secondsLeft != null) arenaSecondsLeft.value = secondsLeft;
    if (spinning != null) isSpinning.value = spinning;
    if (firstDancer != null) firstDancerUid.value = firstDancer;
    if (stageText != null) arenaStageText.value = stageText;
    if (recordedVideo != null) myRecordedVideo.value = recordedVideo;
    if (videoUrl != null) myVideoUrl.value = videoUrl;
    if (oppVideoUrl != null) opponentVideoUrl.value = oppVideoUrl;
    if (webRTCInit != null) isWebRTCInitialized.value = webRTCInit;
  }

  // --- Bottle Spin Animation Trigger ---
  void startSpinAnimation() {
    isSpinning.value = true;

    final bool meIsFirst = firstDancerUid.value == me.uid;
    final double targetRotation = meIsFirst 
        ? (2 * math.pi * 5) - (math.pi / 2)
        : (2 * math.pi * 5) + (math.pi / 2);

    spinAnimation = Tween<double>(begin: 0.0, end: targetRotation).animate(
      CurvedAnimation(parent: spinController, curve: Curves.easeOutCubic),
    );

    spinController.reset();
    spinController.forward().then((_) {
      updateArenaState(
        spinning: false,
        stageText: meIsFirst ? BattleArenaStrings.youDanceFirst : BattleArenaStrings.opponentDanceFirst(opponent.displayName),
      );
      
      Future.delayed(const Duration(seconds: 3), () {
        startStageCountdown('countdown_1');
      });
    });
  }

  // --- Arena Stage Countdown Timer ---
  void startStageCountdown(String nextStage) {
    _stageTimer?.cancel();
    updateArenaState(
      stage: nextStage,
      secondsLeft: BattleArenaStrings.prepCountdownSeconds,
    );

    if (Get.isRegistered<BattleAudioService>()) {
      Get.find<BattleAudioService>().playTickSound();
    }

    _stageTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (arenaSecondsLeft.value > 1) {
        setArenaSecondsLeft(arenaSecondsLeft.value - 1);
        if (Get.isRegistered<BattleAudioService>()) {
          Get.find<BattleAudioService>().playTickSound();
        }
      } else {
        _stageTimer?.cancel();
        if (Get.isRegistered<BattleAudioService>()) {
          Get.find<BattleAudioService>().playStartSound();
        }
        if (nextStage == 'countdown_1') {
          startTurn(1);
        } else if (nextStage == 'countdown_2') {
          startTurn(2);
        }
      }
    });
  }

  // --- WebRTC / Turn Handlers ---
  void startTurn(int turnNumber) async {
    _stageTimer?.cancel();
    updateArenaState(
      stage: 'turn_$turnNumber',
      secondsLeft: BattleArenaStrings.danceTurnDurationSeconds,
    );

    if (Get.isRegistered<BattleAudioService>()) {
      Get.find<BattleAudioService>().playBackgroundMusic();
    }

    final bool isMyTurn = (turnNumber == 1 && firstDancerUid.value == me.uid) ||
                         (turnNumber == 2 && firstDancerUid.value != me.uid);

    await setupWebRTCConnection(isMyTurn);

    if (isMyTurn && localStream != null) {
      try {
        final videoTracks = localStream!.getVideoTracks();
        if (videoTracks.isEmpty) {
          appLog("Warning: No video tracks found on local stream. Recording skipped.");
          Get.snackbar(
            "Camera Warning",
            "No video tracks found. Camera recording is not supported on this device/simulator.",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.orangeAccent.withValues(alpha: 0.9),
            colorText: Colors.white,
            duration: const Duration(seconds: 5),
          );
        } else {

        final directory = await getTemporaryDirectory();
        final localVideoPath = '${directory.path}/local_record_${DateTime.now().millisecondsSinceEpoch}.mp4';
        
        mediaRecorder = webrtc.MediaRecorder();
        await mediaRecorder!.start(
          localVideoPath,
          videoTrack: videoTracks.first,
          audioChannel: webrtc.RecorderAudioChannel.INPUT,
        );
        
        setMyRecordedVideo(XFile(localVideoPath));
        }
      } catch (e) {
        appLog("MediaRecorder start failed: $e");
      }
    }

    _stageTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (arenaSecondsLeft.value > 1) {
        setArenaSecondsLeft(arenaSecondsLeft.value - 1);
      } else {
        _stageTimer?.cancel();
        
        if (Get.isRegistered<BattleAudioService>()) {
          Get.find<BattleAudioService>().stopBackgroundMusic();
        }

        if (isMyTurn) {
          if (mediaRecorder != null) {
            try {
              await mediaRecorder!.stop();
              mediaRecorder = null;
            } catch (e) {
              appLog("MediaRecorder stop failed: $e");
            }
          }
        }

        _closeWebRTCConnection();

        if (turnNumber == 1) {
          clearBattleSignaling(currentBattleState.value!.id);
          startStageCountdown('countdown_2');
        } else {
          // Add battle upload to global background queue
          final feedController = Get.find<FeedController>();
          feedController.addBattleToQueue(
            battleId: currentBattleState.value!.id,
            dancer: me,
            localVideoPath: myRecordedVideo.value?.path ?? "",
            meIndex: meIndex,
            opponentName: opponent.displayName,
          );
          setArenaStage('completed');
        }
      }
    });
  }

  // --- WebRTC Helpers ---
  Future<void> setupWebRTCConnection(bool isDancer) async {
    try {
      final config = {
        'iceServers': [
          {'url': 'stun:stun.l.google.com:19302'},
        ]
      };
      
      peerConnection = await webrtc.createPeerConnection(config);
      
      peerConnection!.onIceCandidate = (candidate) {
        addIceCandidate(currentBattleState.value!.id, meIndex, {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        });
      };

      // Always initialize local camera stream for both dancer and observer to support self-view and bidirectional streaming
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
      
      localStream!.getTracks().forEach((track) {
        peerConnection!.addTrack(track, localStream!);
      });

      peerConnection!.onTrack = (event) {
        if (event.track.kind == 'video' && event.streams.isNotEmpty) {
          remoteRenderer.srcObject = event.streams[0];
        }
      };

      if (isDancer) {
        final offer = await peerConnection!.createOffer();
        await peerConnection!.setLocalDescription(offer);
        await sendSdpOffer(currentBattleState.value!.id, offer.sdp!);
      }

      setWebRTCInitialized(true);
      handleSignalingUpdate(currentBattleState.value!);
    } catch (e) {
      appLog("WebRTC connection error: $e");
    }
  }

  void _closeWebRTCConnection() {
    isWebRTCInitialized.value = false;
    localStream?.dispose();
    peerConnection?.close();
    peerConnection = null;
    localRenderer.srcObject = null;
    remoteRenderer.srcObject = null;
    _processedCandidateIds.clear();
  }

  void handleSignalingUpdate(DanceBattle battle) async {
    if (peerConnection == null) return;

    final bool isDancer = (arenaStage.value == 'turn_1' && firstDancerUid.value == me.uid) ||
                         (arenaStage.value == 'turn_2' && firstDancerUid.value != me.uid);

    if (isDancer) {
      if (battle.answerSdp != null && (await peerConnection!.getRemoteDescription()) == null) {
        final answer = webrtc.RTCSessionDescription(battle.answerSdp!, 'answer');
        await peerConnection!.setRemoteDescription(answer);
      }
      
      final oppCandidates = opponentIndex == 1 ? battle.iceCandidatesUser1 : battle.iceCandidatesUser2;
      if (oppCandidates != null && oppCandidates.isNotEmpty && (await peerConnection!.getRemoteDescription()) != null) {
        for (var c in oppCandidates) {
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
    } else {
      if (battle.offerSdp != null && (await peerConnection!.getRemoteDescription()) == null) {
        final offer = webrtc.RTCSessionDescription(battle.offerSdp!, 'offer');
        await peerConnection!.setRemoteDescription(offer);
        
        final answer = await peerConnection!.createAnswer();
        await peerConnection!.setLocalDescription(answer);
        await sendSdpAnswer(battle.id, answer.sdp!);
      }

      final oppCandidates = opponentIndex == 1 ? battle.iceCandidatesUser1 : battle.iceCandidatesUser2;
      if (oppCandidates != null && oppCandidates.isNotEmpty && (await peerConnection!.getRemoteDescription()) != null) {
        for (var c in oppCandidates) {
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
  }

  // --- Forfeit Handler ---
  void handleForfeit(DanceBattle updatedBattle) {
    _stageTimer?.cancel();
    _closeWebRTCConnection();
    
    if (Get.isRegistered<BattleAudioService>()) {
      Get.find<BattleAudioService>().stopAll();
    }

    if (mediaRecorder != null) {
      mediaRecorder!.stop().catchError((e) {
        appLog("Error stopping media recorder on forfeit: $e");
        return null;
      });
      mediaRecorder = null;
    }
    currentBattleState.value = updatedBattle;
    setArenaStage('completed');
  }

  // --- Video Merging Methods ---
  void uploadAndRegisterMyVideo() async {
    try {
      String videoUrl;
      if (myRecordedVideo.value != null) {
        videoUrl = await SupabaseStore.instance.uploadBattleVideo(
          myRecordedVideo.value!.path, 
          me.uid, 
          currentBattleState.value!.id
        );
      } else {
        videoUrl = "https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4";
        appLog("Using placeholder video URL for simulator: $videoUrl");
      }

      setMyVideoUrl(videoUrl);
      await updateBattleVideoUrl(currentBattleState.value!.id, meIndex, videoUrl);
      checkAndMergeVideos();
    } catch (e) {
      appLog("Error uploading/registering video: $e");
    }
  }

  void checkAndMergeVideos() async {
    if (myVideoUrl.value == null || opponentVideoUrl.value == null) {
      return;
    }

    if (arenaStage.value == 'completed') return;

    if (meIndex == 1) {
      try {
        final directory = await getTemporaryDirectory();
        
        final String path1 = myRecordedVideo.value?.path ?? myVideoUrl.value!;
        final String path2 = opponentVideoUrl.value!;
        final String mergedPath = '${directory.path}/merged_${DateTime.now().millisecondsSinceEpoch}.mp4';

        final jwt = Supabase.instance.client.auth.currentSession?.accessToken;
        final headersStr1 = (path1.startsWith('http') && jwt != null) ? '-headers "Authorization: Bearer $jwt\r\n" ' : '';
        final headersStr2 = (path2.startsWith('http') && jwt != null) ? '-headers "Authorization: Bearer $jwt\r\n" ' : '';

        final ffmpegCommand = '$headersStr1-i "$path1" $headersStr2-i "$path2" -filter_complex hstack=inputs=2 -preset ultrafast "$mergedPath"';

        appLog("FFmpeg merging command: $ffmpegCommand");
        final session = await FFmpegKit.execute(ffmpegCommand);
        final returnCode = await session.getReturnCode();

        if (ReturnCode.isSuccess(returnCode)) {
          appLog("FFmpeg merge succeeded! File created at: $mergedPath");
          final combinedUrl = await SupabaseStore.instance.uploadBattleVideo(mergedPath, me.uid, currentBattleState.value!.id);
          await updateBattleCombinedVideoUrl(currentBattleState.value!.id, combinedUrl);
          setArenaStage('completed');
        } else {
          final logs = await session.getAllLogs();
          final failLog = logs.map((l) => l.getMessage()).join('\n');
          appLog("FFmpeg video merge failed: $failLog");
          await updateBattleCombinedVideoUrl(currentBattleState.value!.id, myVideoUrl.value!);
          setArenaStage('completed');
        }
      } catch (e) {
        appLog("Error during video merging: $e");
        await updateBattleCombinedVideoUrl(currentBattleState.value!.id, myVideoUrl.value!);
        setArenaStage('completed');
      }
    } else {
      Timer.periodic(const Duration(seconds: 2), (timer) {
        if (currentBattleState.value?.status == 'completed' || arenaStage.value == 'completed') {
          timer.cancel();
          setArenaStage('completed');
        }
      });
    }
  }
}
