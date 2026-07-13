import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import '../../../app/controllers/auth_controller.dart';
import '../../../app/controllers/battle_controller.dart';
import '../../../app/data/models/dance_models.dart';
import '../../../app/data/services/supabase_store.dart';
import '../theme/app_theme.dart';
import 'app_strings.dart';

class BattleArenaScreen extends StatelessWidget {
  final DanceBattle battle;
  final DancerProfile opponent;

  const BattleArenaScreen({super.key, required this.battle, required this.opponent});

  @override
  Widget build(BuildContext context) {
    final battleController = Get.put(BattleController());
    final authController = Get.find<AuthController>();
    final me = authController.currentUserProfile!;

    // Call setupArena once if not already initialized
    if (battleController.activeBattleId != battle.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        battleController.setupArena(battle, opponent);
      });
    }

    return PopScope(
      canPop: false, // Pop is handled manually via the confirmation dialog
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        // If the battle is completed, we can pop without confirming
        if (battleController.arenaStage.value == 'completed') {
          Get.delete<BattleController>();
          Navigator.of(context).pop();
          return;
        }

        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.cardBg,
            title: const Text(
              BattleArenaStrings.exitArenaTitle,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: const Text(BattleArenaStrings.exitArenaContent, style: TextStyle(color: AppTheme.textSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(BattleArenaStrings.cancel, style: TextStyle(color: Colors.white54)),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  BattleArenaStrings.forfeitAndExit,
                  style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await battleController.forfeitBattle(battle.id, me.uid);
          Get.delete<BattleController>();
          if (context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Obx(() {
        final bool isMyTurn =
            (battleController.arenaStage.value == 'turn_1' && battleController.firstDancerUid.value == me.uid) ||
            (battleController.arenaStage.value == 'turn_2' && battleController.firstDancerUid.value != me.uid);

        return Scaffold(
          backgroundColor: AppTheme.darkBackground,
          body: SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            BattleArenaStrings.battleStage,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.0,
                              shadows: [Shadow(color: AppTheme.primary.withValues(alpha: 0.5), blurRadius: 8)],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            battleController.arenaStage.value.startsWith('turn_')
                                ? BattleArenaStrings.liveDanceOff
                                : BattleArenaStrings.prepMode,
                            style: const TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.timer_outlined, color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              "${battleController.arenaSecondsLeft.value} s",
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Arena Panel
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        color: Colors.black,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // --- STAGE: BOTTLE SPIN ---
                            if (battleController.arenaStage.value == 'spin') ...[
                              Positioned(
                                top: 40,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Text(
                                    battleController.arenaStageText.value,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ),

                              // Bottle Wheel Grid
                              Positioned.fill(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        // Me Avatar
                                        Column(
                                          children: [
                                            Stack(
                                              clipBehavior: Clip.none,
                                              alignment: Alignment.center,
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      if (!battleController.isSpinning.value &&
                                                          battleController.firstDancerUid.value == me.uid)
                                                        BoxShadow(
                                                          color: AppTheme.primary.withValues(alpha: 0.6),
                                                          blurRadius: 16,
                                                          spreadRadius: 4,
                                                        ),
                                                    ],
                                                  ),
                                                  child: CircleAvatar(
                                                    radius: 36,
                                                    backgroundImage: NetworkImage(
                                                      me.avatarUrl,
                                                      headers: SupabaseStore.getHeadersForUrl(me.avatarUrl),
                                                    ),
                                                  ),
                                                ),
                                                if (!battleController.isSpinning.value &&
                                                    battleController.firstDancerUid.value == me.uid)
                                                  const Positioned(
                                                    top: -28,
                                                    child: Icon(
                                                      Icons.arrow_drop_down_circle,
                                                      color: AppTheme.primary,
                                                      size: 28,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              BattleArenaStrings.you,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),

                                        // Spinner Core
                                        Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            Container(
                                              width: 130,
                                              height: 130,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(color: AppTheme.border, width: 2),
                                                gradient: RadialGradient(colors: [Colors.grey[900]!, Colors.black]),
                                              ),
                                            ),
                                            // Rotating Bottle Arrow
                                            AnimatedBuilder(
                                              animation: battleController.spinController,
                                              builder: (context, child) {
                                                return Transform.rotate(
                                                  angle: battleController.spinAnimation.value,
                                                  child: child,
                                                );
                                              },
                                              child: Container(
                                                width: 14,
                                                height: 100,
                                                alignment: Alignment.topCenter,
                                                child: Container(
                                                  width: 14,
                                                  height: 50,
                                                  decoration: BoxDecoration(
                                                    gradient: AppTheme.primaryGradient,
                                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: AppTheme.primary.withValues(alpha: 0.8),
                                                        blurRadius: 10,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        // Opponent Avatar
                                        Column(
                                          children: [
                                            Stack(
                                              clipBehavior: Clip.none,
                                              alignment: Alignment.center,
                                              children: [
                                                Container(
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    boxShadow: [
                                                      if (!battleController.isSpinning.value &&
                                                          battleController.firstDancerUid.value == opponent.uid)
                                                        BoxShadow(
                                                          color: AppTheme.accent.withValues(alpha: 0.6),
                                                          blurRadius: 16,
                                                          spreadRadius: 4,
                                                        ),
                                                    ],
                                                  ),
                                                  child: CircleAvatar(
                                                    radius: 36,
                                                    backgroundImage: NetworkImage(
                                                      opponent.avatarUrl,
                                                      headers: SupabaseStore.getHeadersForUrl(opponent.avatarUrl),
                                                    ),
                                                  ),
                                                ),
                                                if (!battleController.isSpinning.value &&
                                                    battleController.firstDancerUid.value == opponent.uid)
                                                  const Positioned(
                                                    top: -28,
                                                    child: Icon(
                                                      Icons.arrow_drop_down_circle,
                                                      color: AppTheme.accent,
                                                      size: 28,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              opponent.displayName.toUpperCase(),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // --- STAGES: COUNTDOWNS ---
                            if (battleController.arenaStage.value.startsWith('countdown_')) ...[
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    battleController.arenaStage.value == 'countdown_1'
                                        ? BattleArenaStrings.getReadyTurn1
                                        : BattleArenaStrings.getReadyTurn2,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppTheme.accent,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    "${battleController.arenaSecondsLeft.value}",
                                    style: const TextStyle(
                                      fontSize: 72,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            // --- STAGES: DANCE TURNS ---
                            if (battleController.arenaStage.value.startsWith('turn_')) ...[
                              // Render Video stream
                              Positioned.fill(
                                child: isMyTurn
                                    ? (battleController.isWebRTCInitialized.value
                                          ? webrtc.RTCVideoView(
                                              battleController.localRenderer,
                                              objectFit: webrtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                                              mirror: true,
                                            )
                                          : const Center(child: CircularProgressIndicator(color: AppTheme.primary)))
                                    : (battleController.isWebRTCInitialized.value
                                          ? webrtc.RTCVideoView(
                                              battleController.remoteRenderer,
                                              objectFit: webrtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                                            )
                                          : const Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.video_camera_front_rounded,
                                                    size: 48,
                                                    color: Colors.white24,
                                                  ),
                                                  SizedBox(height: 12),
                                                  Text(
                                                    BattleArenaStrings.connectingToOpponentCamera,
                                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                            )),
                              ),

                              // Floating Preview Overlay (top side / top-right corner)
                              Positioned(
                                top: 80,
                                right: 16,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    width: 100,
                                    height: 150,
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      border: Border.all(
                                        color: isMyTurn
                                            ? AppTheme.accent.withValues(alpha: 0.4)
                                            : AppTheme.primary.withValues(alpha: 0.4),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: isMyTurn
                                              ? (battleController.isWebRTCInitialized.value
                                                    ? webrtc.RTCVideoView(
                                                        battleController.remoteRenderer,
                                                        objectFit:
                                                            webrtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                                                      )
                                                    : const Center(
                                                        child: Icon(
                                                          Icons.video_camera_front_rounded,
                                                          color: Colors.white24,
                                                        ),
                                                      ))
                                              : (battleController.isWebRTCInitialized.value
                                                    ? webrtc.RTCVideoView(
                                                        battleController.localRenderer,
                                                        objectFit:
                                                            webrtc.RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                                                        mirror: true,
                                                      )
                                                    : const Center(
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: AppTheme.primary,
                                                        ),
                                                      )),
                                        ),
                                        Positioned(
                                          bottom: 4,
                                          left: 4,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.6),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isMyTurn ? opponent.displayName : BattleArenaStrings.you,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Turn Info Badge Overlay
                              Positioned(
                                top: 20,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: isMyTurn ? AppTheme.primary : AppTheme.accent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isMyTurn ? AppTheme.primary : AppTheme.accent,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isMyTurn
                                            ? BattleArenaStrings.yourTurn
                                            : BattleArenaStrings.opponentTurn(opponent.displayName),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            // --- STAGES: MERGING PIPELINE ---
                            if (battleController.arenaStage.value == 'merging') ...[
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const CircularProgressIndicator(color: AppTheme.accent),
                                    const SizedBox(height: 24),
                                    const Text(
                                      BattleArenaStrings.recordingComplete,
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      battleController.meIndex == 1
                                          ? BattleArenaStrings.ffmpegProcessing
                                          : BattleArenaStrings.waitingForHostTranscode,
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // --- STAGES: COMPLETED ---
                            if (battleController.arenaStage.value == 'completed') ...[
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      BattleArenaStrings.battleComplete,
                                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      BattleArenaStrings.battleCompleteDescription,
                                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 36),
                                    SizedBox(
                                      width: 200,
                                      height: 46,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          Get.delete<BattleController>();
                                          Navigator.of(context).pop();
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.primary,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: const Text(
                                          BattleArenaStrings.exitArena,
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      }),
    );
  }
}
