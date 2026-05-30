import 'package:livekit_client/livekit_client.dart';
import 'api_service.dart';

class LiveKitService {
  Room? _room;
  bool isConnected = false;
  bool isMuted = false;

  static const String livekitHost = 'wss://ludo-2ngt1a8e.livekit.cloud';

  Future<bool> joinAudioRoom(String roomCode, String name) async {
    try {
      // 1. Fetch authorized LiveKit JWT token from backend
      final token = await ApiService.fetchLiveKitToken(roomCode, name);
      if (token == null) {
        print('Failed to retrieve voice chat auth token.');
        return false;
      }

      // 2. Connect to the LiveKit server room
      _room = Room();
      await _room!.connect(livekitHost, token);
      
      // 3. Publish local mic audio track
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      
      isConnected = true;
      isMuted = false;
      print('Connected to LiveKit voice room successfully.');
      return true;
    } catch (e) {
      print('LiveKit connection failed: $e. Audio bypass enabled.');
      return false;
    }
  }

  void toggleMute() async {
    if (_room == null || !isConnected) return;
    try {
      isMuted = !isMuted;
      await _room!.localParticipant?.setMicrophoneEnabled(!isMuted);
      print('Microphone set to: ${isMuted ? "MUTED" : "UNMUTED"}');
    } catch (e) {
      print('Mute toggle error: $e');
    }
  }

  void leaveAudioRoom() async {
    if (_room != null) {
      await _room!.disconnect();
      _room = null;
    }
    isConnected = false;
    isMuted = false;
    print('Left voice room.');
  }
}
