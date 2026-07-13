import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/controllers/auth_controller.dart';
import '../../../app/controllers/battle_controller.dart';
import '../../../app/data/models/dance_models.dart';
import '../../data/services/supabase_store.dart';
import '../theme/app_theme.dart';
import 'battle_arena_screen.dart';
import 'app_strings.dart';

class BattleMatchingScreen extends StatelessWidget {
  const BattleMatchingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final battleController = Get.put(BattleController());
    final authController = Get.find<AuthController>();
    final me = authController.currentUserProfile;

    // Start matchmaking once if not already matched
    if (me != null &&
        !battleController.isMatched.value &&
        battleController.secondsLeft.value == BattleMatchingStrings.searchDurationSeconds) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        battleController.startMatchmaking(me.uid, (battle, opponent) {
          Future.delayed(const Duration(seconds: 3), () {
            Get.off(() => BattleArenaScreen(battle: battle, opponent: opponent));
          });
        });
      });
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          if (me != null) {
            battleController.cancelMatchmaking(me.uid);
          }
          Get.delete<BattleController>();
        }
      },
      child: Obx(() {
        return Scaffold(
          backgroundColor: AppTheme.darkBackground,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              onPressed: () {
                if (me != null) {
                  battleController.cancelMatchmaking(me.uid);
                }
                Navigator.of(context).pop();
              },
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Header
                  Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                        child: const Text(
                          BattleMatchingStrings.battleArena,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        BattleMatchingStrings.matchmakingSubtitle,
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),

                  // Matchmaking Visualizer
                  Expanded(
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Radial Glowing Orbs
                          AnimatedBuilder(
                            animation: battleController.pulseController,
                            builder: (context, child) {
                              return Container(
                                height: 220 + (battleController.pulseController.value * 40),
                                width: 220 + (battleController.pulseController.value * 40),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      (battleController.isMatched.value ? AppTheme.accent : AppTheme.primary)
                                          .withValues(alpha: 0.15),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          // Outer spinning ring
                          RotationTransition(
                            turns: battleController.pulseController,
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: battleController.isMatched.value ? AppTheme.accent : AppTheme.primary,
                                  width: 3,
                                  style: BorderStyle.solid,
                                ),
                              ),
                            ),
                          ),

                          // Countdown / Opponent Display
                          if (!battleController.isMatched.value)
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "${battleController.secondsLeft.value}",
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  BattleMatchingStrings.secondsLeft,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          else
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.flash_on_rounded, color: AppTheme.accent, size: 48),
                                const SizedBox(height: 8),
                                const Text(
                                  BattleMatchingStrings.ready,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Match status, Profiles Display
                  Column(
                    children: [
                      // Pulse Status Text
                      AnimatedBuilder(
                        animation: battleController.pulseController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: battleController.isMatched.value
                                ? 1.0
                                : (0.4 + (battleController.pulseController.value * 0.6)),
                            child: Text(
                              battleController.statusText.value,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: battleController.isMatched.value ? AppTheme.accent : AppTheme.primary,
                                letterSpacing: 1.0,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),

                      // Profiles Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Current User Profile card
                          Column(
                            children: [
                              CircleAvatar(
                                radius: 36,
                                backgroundImage: NetworkImage(
                                  me?.avatarUrl ?? defaultAvatarUrl,
                                  headers: me?.avatarUrl != null ? SupabaseStore.getHeadersForUrl(me!.avatarUrl) : null,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "@${me?.username ?? BattleMatchingStrings.dancer}",
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ],
                          ),

                          // VS Indicator
                          const Text(
                            BattleMatchingStrings.vs,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),

                          // Opponent User Profile card
                          Column(
                            children: [
                              battleController.isMatched.value && battleController.opponentProfile.value != null
                                  ? CircleAvatar(
                                      radius: 46,
                                      backgroundImage: NetworkImage(
                                        battleController.opponentProfile.value!.avatarUrl,
                                        headers: SupabaseStore.getHeadersForUrl(
                                          battleController.opponentProfile.value!.avatarUrl,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 72,
                                      height: 72,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppTheme.cardBg,
                                        border: Border.all(color: AppTheme.border, width: 1.5),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.question_mark_rounded,
                                          color: AppTheme.textSecondary,
                                          size: 28,
                                        ),
                                      ),
                                    ),
                              const SizedBox(height: 8),
                              Text(
                                battleController.isMatched.value && battleController.opponentProfile.value != null
                                    ? "@${battleController.opponentProfile.value!.username}"
                                    : BattleMatchingStrings.matching,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),

                      // Action Button
                      if (!battleController.isMatched.value && battleController.secondsLeft.value == 0)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              if (me != null) {
                                battleController.startMatchmaking(me.uid, (battle, opponent) {
                                  Future.delayed(const Duration(seconds: 3), () {
                                    Get.off(() => BattleArenaScreen(battle: battle, opponent: opponent));
                                  });
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              BattleMatchingStrings.retryMatchmaking,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        )
                      else if (!battleController.isMatched.value)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            onPressed: () {
                              if (me != null) {
                                battleController.cancelMatchmaking(me.uid);
                              }
                              Navigator.of(context).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.border, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text(
                              BattleMatchingStrings.cancelSearch,
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        )
                      else
                        const SizedBox(height: 50),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}
