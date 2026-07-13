import 'package:audioplayers/audioplayers.dart';
import 'package:get/get.dart';
import 'package:dance_pulse/app/utils/app_logger.dart';

class BattleAudioService extends GetxService {
  static BattleAudioService get to => Get.find();

  late final AudioPlayer _musicPlayer;
  late final AudioPlayer _sfxPlayer;

  // Royalty free public audio URLs
  static const String danceBeatUrl = 'https://samplesongs.netlify.app/Solo.mp3';
  static const String tickSoundUrl = 'https://raw.githubusercontent.com/wesbos/JavaScript30/master/01%20-%20JavaScript%20Drum%20Kit/sounds/tink.wav';
  static const String startSoundUrl = 'https://raw.githubusercontent.com/wesbos/JavaScript30/master/01%20-%20JavaScript%20Drum%20Kit/sounds/boom.wav';

  @override
  void onInit() {
    super.onInit();
    _musicPlayer = AudioPlayer();
    _musicPlayer.setReleaseMode(ReleaseMode.loop); // Loop the background beat
    _sfxPlayer = AudioPlayer();
  }

  @override
  void onClose() {
    _musicPlayer.dispose();
    _sfxPlayer.dispose();
    super.onClose();
  }

  /// Plays loopable background music (dance beat) during active turns
  Future<void> playBackgroundMusic() async {
    try {
      await _musicPlayer.stop();
      await _musicPlayer.play(UrlSource(danceBeatUrl));
      appLog("Battle background music started playing.");
    } catch (e) {
      appLog("Error playing background music: $e");
    }
  }

  /// Stops background music
  Future<void> stopBackgroundMusic() async {
    try {
      await _musicPlayer.stop();
      appLog("Battle background music stopped.");
    } catch (e) {
      appLog("Error stopping background music: $e");
    }
  }

  /// Plays a countdown tick/beep sound
  Future<void> playTickSound() async {
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(UrlSource(tickSoundUrl));
    } catch (e) {
      appLog("Error playing tick sound: $e");
    }
  }

  /// Plays a battle start/whistle sound
  Future<void> playStartSound() async {
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(UrlSource(startSoundUrl));
    } catch (e) {
      appLog("Error playing start sound: $e");
    }
  }

  /// Stop all playing audios
  Future<void> stopAll() async {
    await stopBackgroundMusic();
    try {
      await _sfxPlayer.stop();
    } catch (_) {}
  }
}
