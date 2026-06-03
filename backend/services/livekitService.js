const { AccessToken } = require('livekit-server-sdk');

/**
 * Generate a JWT token to authorize a player to join a LiveKit audio room
 * @param {string} roomName - The game room code
 * @param {string} participantName - The user's display name or ID
 * @returns {string} The serialized JWT token
 */
const generateLiveKitToken = async (roomName, participantId, participantName) => {
  try {
    const apiKey = process.env.LIVEKIT_API_KEY || 'devkey';
    const apiSecret = process.env.LIVEKIT_API_SECRET || 'secret';

    const livekitRoomName = roomName.startsWith('voice_') ? roomName : `voice_${roomName}`;

    const at = new AccessToken(apiKey, apiSecret, {
      identity: participantId,
      name: participantName,
      ttl: '2h' // Token expires after 2 hours
    });

    at.addGrant({
      roomJoin: true,
      room: livekitRoomName,
      canPublish: true,
      canPublishData: true,
      canSubscribe: true
    });

    return await at.toJwt();
  } catch (error) {
    console.error('Error generating LiveKit token:', error);
    throw error;
  }
};

module.exports = {
  generateLiveKitToken
};
