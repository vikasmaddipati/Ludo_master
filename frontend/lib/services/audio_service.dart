import 'package:audioplayers/audioplayers.dart';

class AudioService {
  static final AudioService instance = AudioService._internal();
  AudioService._internal();

  final AudioPlayer _bgPlayer = AudioPlayer();
  bool _isMusicPlaying = false;

  Future<void> initializeBackgroundMusic() async {
    if (_isMusicPlaying) return;
    try {
      await _bgPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgPlayer.setVolume(0.20); // 20% soft volume for premium ambient background score
      await _bgPlayer.play(AssetSource('sounds/background_score.mp3'));
      _isMusicPlaying = true;
      print('Background score initialized and playing in loop.');
    } catch (e) {
      print('Error starting background music: $e');
    }
  }

  Future<void> stopBackgroundMusic() async {
    try {
      await _bgPlayer.stop();
      _isMusicPlaying = false;
      print('Background score stopped.');
    } catch (e) {
      print('Error stopping background music: $e');
    }
  }

  Future<void> setMusicVolume(double volume) async {
    try {
      await _bgPlayer.setVolume(volume);
    } catch (e) {
      print('Error updating volume: $e');
    }
  }
}
