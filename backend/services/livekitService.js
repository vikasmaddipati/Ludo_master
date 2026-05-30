const { AccessToken } = require('livekit-server-sdk');

/**
 * Generate a JWT token to authorize a player to join a LiveKit audio room
 * @param {string} roomName - The game room code
 * @param {string} participantName - The user's display name or ID
 * @returns {string} The serialized JWT token
 */
const generateLiveKitToken = (roomName, participantName) => {
  try {
    const apiKey = process.env.LIVEKIT_API_KEY || 'devkey';
    const apiSecret = process.env.LIVEKIT_API_SECRET || 'secret';

    const at = new AccessToken(apiKey, apiSecret, {
      identity: participantName,
      ttl: '2h' // Token expires after 2 hours
    });

    at.addGrant({
      roomJoin: true,
      room: roomName,
      canPublish: true,
      canPublishData: true,
      canSubscribe: true
    });

    return at.toJwt();
  } catch (error) {
    console.error('Error generating LiveKit token:', error);
    throw error;
  }
};

module.exports = {
  generateLiveKitToken
};
