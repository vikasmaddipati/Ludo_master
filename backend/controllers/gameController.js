const GameRoom = require('../models/GameRoom');
const { generateLiveKitToken } = require('../services/livekitService');

// Helper to generate unique 6-digit room code
const generateRoomCode = () => {
  return Math.floor(100000 + Math.random() * 900000).toString();
};

const createRoom = async (req, res) => {
  try {
    const { userId, name } = req.body;

    if (!userId || !name) {
      return res.status(400).json({ success: false, message: 'User ID and name are required.' });
    }

    const roomCode = generateRoomCode();
    console.log(`[ROOM] Room Code Generated: ${roomCode}`);

    const room = new GameRoom({
      roomCode,
      creator: userId,
      status: 'waiting',
      players: [
        {
          userId,
          name,
          color: 'red', // Host is Red
          isReady: true,
          isConnected: true
        }
      ],
      tokens: [] // Will initialize when game starts
    });

    await room.save();
    console.log(`[ROOM] Room Created: ${roomCode}`);

    res.status(201).json({
      success: true,
      message: 'Room created successfully.',
      roomCode,
      room
    });
  } catch (error) {
    console.error('Error creating game room:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

const getRoomDetails = async (req, res) => {
  try {
    const { code } = req.params;
    const room = await GameRoom.findOne({ roomCode: code });

    if (!room) {
      return res.status(404).json({ success: false, message: 'Game room not found.' });
    }

    res.status(200).json({ success: true, room });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

const getLiveKitToken = async (req, res) => {
  try {
    const { roomCode, userId, name } = req.query;

    if (!roomCode || !userId || !name) {
      return res.status(400).json({ success: false, message: 'Room code, userId and user name are required.' });
    }

    const token = await generateLiveKitToken(roomCode, userId, name);

    res.status(200).json({
      success: true,
      token
    });
  } catch (error) {
    console.error('Error in livekit token route:', error);
    res.status(500).json({ success: false, message: 'Failed to generate token.' });
  }
};

module.exports = {
  createRoom,
  getRoomDetails,
  getLiveKitToken
};
