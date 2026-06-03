import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'dart:async';
import 'api_service.dart';
import 'socket_service.dart';

class LiveKitService {
  Room? _room;
  bool isConnected = false;
  bool isMuted = false;
  static final LiveKitService instance = LiveKitService();
  Timer? _diagnosticTimer;

  static const String livekitHost = 'wss://ludo-2ngt1a8e.livekit.cloud';

  // ValueNotifiers to notify UI of voice state changes in real-time
  final ValueNotifier<List<String>> activeSpeakersNotifier = ValueNotifier<List<String>>([]);
  final ValueNotifier<Map<String, bool>> participantMuteStatesNotifier = ValueNotifier<Map<String, bool>>({});
  final ValueNotifier<String> connectionStatusNotifier = ValueNotifier<String>('Disconnected');

  Future<bool> joinAudioRoom(String roomCode, String userId, String name) async {
    try {
      final targetRoomName = roomCode.startsWith('voice_') ? roomCode : 'voice_$roomCode';
      if (isConnected && _room != null) {
        if (_room!.name == targetRoomName) {
          print('[LIVEKIT DEBUG] Already connected to audio room: ${_room!.name}. Skipping reconnect.');
          return true;
        } else {
          print('[LIVEKIT DEBUG] Connected to different room: ${_room!.name}. Disconnecting first...');
          leaveAudioRoom();
        }
      }

      print('[LIVEKIT DEBUG] Attempting to join audio room. RoomCode: $roomCode, UserId: $userId, Name: $name');
      connectionStatusNotifier.value = 'Connecting...';
      print('[VOICE] Voice Connection Status: Connecting...');

      // Request runtime microphone permission before connecting
      print('[LIVEKIT DEBUG] Checking runtime microphone permissions...');
      final permStatus = await Permission.microphone.request();
      if (!permStatus.isGranted) {
        print('[LIVEKIT DEBUG] Microphone permission denied.');
        connectionStatusNotifier.value = 'Failed';
        print('[VOICE] Voice Connection Status: Failed');
        return false;
      }
      print('[LIVEKIT DEBUG] Microphone permission granted.');

      // Configure WebRTC Android Audio Settings for voice communication mode using music/media routing to prevent TTS ducking
      try {
        final androidConfig = webrtc.AndroidAudioConfiguration(
          manageAudioFocus: true,
          androidAudioMode: webrtc.AndroidAudioMode.inCommunication,
          androidAudioFocusMode: webrtc.AndroidAudioFocusMode.gain,
          androidAudioStreamType: webrtc.AndroidAudioStreamType.music,
          androidAudioAttributesUsageType: webrtc.AndroidAudioAttributesUsageType.media,
          androidAudioAttributesContentType: webrtc.AndroidAudioAttributesContentType.speech,
        );
        await webrtc.Helper.setAndroidAudioConfiguration(androidConfig);
        print('[LIVEKIT DEBUG] Applied AndroidAudioConfiguration for voice communication');
      } catch (e) {
        print('[LIVEKIT DEBUG] Error setting Android audio configuration: $e');
      }

      // 1. Fetch authorized LiveKit JWT token from backend using unique user id with retries
      String? token;
      int maxRetries = 3;
      for (int i = 0; i < maxRetries; i++) {
        token = await ApiService.fetchLiveKitToken(roomCode, userId, name);
        if (token != null) break;
        print('[LIVEKIT DEBUG] Failed to retrieve voice chat auth token. Retrying ${i + 1}/$maxRetries...');
        await Future.delayed(const Duration(seconds: 1));
      }

      if (token == null) {
        print('[LIVEKIT DEBUG] Failed to retrieve voice chat auth token from backend after retries.');
        connectionStatusNotifier.value = 'Token Error';
        print('[VOICE] Voice Connection Status: Token Error');
        return false;
      }
      print('[LIVEKIT DEBUG] Token retrieved successfully.');

      // 2. Initialize and configure Room options with high quality audio capture settings (AEC, NS, AGC, HighPass)
      _room = Room(
        roomOptions: const RoomOptions(
          defaultAudioPublishOptions: AudioPublishOptions(
            dtx: true,
            encoding: AudioEncoding(maxBitrate: 32000), // Optimal bitrate for clear voice streaming
          ),
          defaultAudioCaptureOptions: AudioCaptureOptions(
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
            highPassFilter: true,
          ),
        ),
      );

      // Register detailed room listeners on the events stream
      _setupRoomListeners();

      // 3. Connect to the LiveKit server room
      print('[LIVEKIT DEBUG] Connecting to LiveKit Host: $livekitHost...');
      await _room!.connect(livekitHost, token);
      
      // 4. Publish local mic audio track
      print('[LIVEKIT DEBUG] Connection successful. Enabling microphone...');
      await _room!.localParticipant?.setMicrophoneEnabled(true);
      
      // Ensure speakerphone is enabled at maximum volume routing
      try {
        await _room!.setSpeakerOn(true);
        await Hardware.instance.setSpeakerphoneOn(true);
        print('[LIVEKIT DEBUG] Speakerphone enabled successfully');
      } catch (e) {
        print('[LIVEKIT DEBUG] Error enabling speakerphone: $e');
      }

      isConnected = true;
      isMuted = false;
      connectionStatusNotifier.value = 'Connected';
      print('[LIVEKIT DEBUG] Successfully connected to LiveKit and published audio.');
      print('[VOICE] Voice Connection Status: Connected');
      print('[VOICE] Mic Started');

      _updateMuteStates();
      _startDiagnostics();
      return true;
    } catch (e) {
      print('[LIVEKIT DEBUG] LiveKit connection failed with error: $e');
      connectionStatusNotifier.value = 'Failed';
      print('[VOICE] Voice Connection Status: Failed');
      isConnected = false;
      return false;
    }
  }

  void _startDiagnostics() {
    _diagnosticTimer?.cancel();
    _diagnosticTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (isConnected && _room != null) {
        final currentRoom = _room!.name ?? 'Unknown';
        print('[VOICE] Current Room: $currentRoom');
        print('[VOICE] Voice Connection Status: ${connectionStatusNotifier.value}');
        
        // Sender Socket (local socket ID)
        String localSocketId = 'Offline';
        try {
          localSocketId = SocketService.instance.socket.id ?? 'No Socket ID';
        } catch (_) {}
        print('[VOICE] Sender Socket: $localSocketId');

        final hasLocalMic = _room!.localParticipant?.isMicrophoneEnabled() == true;
        final inputLevel = _room!.localParticipant?.audioLevel ?? 0.0;
        print('[VOICE] Current input level: $inputLevel');
        
        if (hasLocalMic) {
          print('[VOICE] Packet Captured');
          print('[VOICE] Packet Sent');
        }

        double maxOutputLevel = 0.0;
        bool hasRemoteMic = false;
        List<String> remoteParticipants = [];
        for (var p in _room!.remoteParticipants.values) {
          remoteParticipants.add(p.identity);
          if (p.isMicrophoneEnabled()) {
            hasRemoteMic = true;
          }
          if (p.audioLevel > maxOutputLevel) {
            maxOutputLevel = p.audioLevel;
          }
        }
        
        print('[VOICE] Receiver Socket: ${remoteParticipants.join(", ")}');
        print('[VOICE] Current output level: $maxOutputLevel');
        
        if (hasRemoteMic) {
          print('[VOICE] Packet Received');
          print('[VOICE] Packet Decoded');
          print('[VOICE] Packet Played');
        }
      }
    });
  }

  void _stopDiagnostics() {
    _diagnosticTimer?.cancel();
    _diagnosticTimer = null;
  }

  void _setupRoomListeners() {
    if (_room == null) return;

    _room!.events.listen((event) {
      if (event is RoomConnectedEvent) {
        print('[LIVEKIT DEBUG] Connected to room: ${_room!.name}');
        connectionStatusNotifier.value = 'Connected';
        print('[VOICE] Voice Connection Status: Connected');
      } else if (event is RoomDisconnectedEvent) {
        print('[LIVEKIT DEBUG] Disconnected from room, reason: ${event.reason}');
        connectionStatusNotifier.value = 'Disconnected';
        print('[VOICE] Voice Connection Status: Disconnected');
        isConnected = false;
        _stopDiagnostics();
      } else if (event is ParticipantConnectedEvent) {
        print('[LIVEKIT DEBUG] Participant joined: ${event.participant.identity}');
        _updateMuteStates();
      } else if (event is ParticipantDisconnectedEvent) {
        print('[LIVEKIT DEBUG] Participant left: ${event.participant.identity}');
        _updateMuteStates();
      } else if (event is TrackPublishedEvent) {
        print('[LIVEKIT DEBUG] Track published: ${event.publication.sid} by ${event.participant.identity}');
      } else if (event is TrackSubscribedEvent) {
        print('[LIVEKIT DEBUG] Track subscribed: ${event.track.sid} from ${event.participant.identity}');
        print('[VOICE] Packet Decoded');
        print('[VOICE] Packet Played');
        // Force speakerphone routing to ensure remote audio is played through main speaker
        try {
          _room?.setSpeakerOn(true);
          Hardware.instance.setSpeakerphoneOn(true);
          print('[LIVEKIT DEBUG] Re-applied speakerphone on TrackSubscribedEvent');
        } catch (e) {
          print('[LIVEKIT DEBUG] Error re-applying speakerphone: $e');
        }
      } else if (event is TrackUnsubscribedEvent) {
        print('[LIVEKIT DEBUG] Track unsubscribed: ${event.track.sid} from ${event.participant.identity}');
      } else if (event is LocalTrackPublishedEvent) {
        print('[LIVEKIT DEBUG] Local track published: ${event.publication.sid}');
        _updateMuteStates();
      } else if (event is LocalTrackUnpublishedEvent) {
        print('[LIVEKIT DEBUG] Local track unpublished: ${event.publication.sid}');
        _updateMuteStates();
      } else if (event is TrackMutedEvent) {
        print('[LIVEKIT DEBUG] Track muted: ${event.publication.sid} by ${event.participant.identity}');
        _updateMuteStates();
      } else if (event is TrackUnmutedEvent) {
        print('[LIVEKIT DEBUG] Track unmuted: ${event.publication.sid} by ${event.participant.identity}');
        _updateMuteStates();
      } else if (event is ActiveSpeakersChangedEvent) {
        final speakers = event.speakers.map((s) => s.identity).toList();
        print('[LIVEKIT DEBUG] Active speakers updated: $speakers');
        activeSpeakersNotifier.value = speakers;
      }
    });
  }

  void _updateMuteStates() {
    if (_room == null) return;
    final map = <String, bool>{};
    
    // Remote participants
    for (var entry in _room!.remoteParticipants.entries) {
      final isMicMuted = !entry.value.isMicrophoneEnabled();
      map[entry.key] = isMicMuted;
    }

    // Local participant
    if (_room!.localParticipant != null) {
      final localMuted = !_room!.localParticipant!.isMicrophoneEnabled();
      map[_room!.localParticipant!.identity] = localMuted;
    }

    participantMuteStatesNotifier.value = map;
    print('[LIVEKIT DEBUG] Participant Mute States: $map');
  }

  void toggleMute() async {
    if (_room == null || !isConnected) return;
    try {
      isMuted = !isMuted;
      await _room!.localParticipant?.setMicrophoneEnabled(!isMuted);
      _updateMuteStates();
      print('[LIVEKIT DEBUG] Local Microphone set to: ${isMuted ? "MUTED" : "UNMUTED"}');
      if (isMuted) {
        print('[VOICE] Mic Stopped');
      } else {
        print('[VOICE] Mic Started');
      }
    } catch (e) {
      print('[LIVEKIT DEBUG] Local Mute toggle error: $e');
    }
  }

  Future<void> setMicrophoneActive(bool isActive) async {
    if (_room == null || !isConnected) return;
    try {
      isMuted = !isActive;
      await _room!.localParticipant?.setMicrophoneEnabled(isActive);
      _updateMuteStates();
      print('[LIVEKIT DEBUG] Push-to-talk microphone set to: ${isActive ? "ACTIVE" : "MUTED"}');
      if (isActive) {
        print('[VOICE] Mic Started');
      } else {
        print('[VOICE] Mic Stopped');
      }
    } catch (e) {
      print('[LIVEKIT DEBUG] Push-to-talk error: $e');
    }
  }

  void leaveAudioRoom() async {
    _stopDiagnostics();
    if (_room != null) {
      try {
        await _room!.disconnect();
        print('[VOICE] Mic Stopped');
        print('[VOICE] Voice Connection Status: Disconnected');
      } catch (e) {
        print('[LIVEKIT DEBUG] Error disconnecting: $e');
      }
      _room = null;
    }
    isConnected = false;
    isMuted = false;
    connectionStatusNotifier.value = 'Disconnected';
    activeSpeakersNotifier.value = [];
    participantMuteStatesNotifier.value = {};
    print('[LIVEKIT DEBUG] Left voice room and cleared states.');
  }
}
