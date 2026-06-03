const mongoose = require('mongoose');

const playerSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true
  },
  name: {
    type: String,
    required: true
  },
  color: {
    type: String,
    enum: ['red', 'green', 'yellow', 'blue']
  },
  isBot: {
    type: Boolean,
    default: false
  },
  isReady: {
    type: Boolean,
    default: false
  },
  isConnected: {
    type: Boolean,
    default: true
  }
});

const tokenSchema = new mongoose.Schema({
  color: {
    type: String,
    enum: ['red', 'green', 'yellow', 'blue']
  },
  tokenId: {
    type: Number,
    required: true
  },
  // -1: Home base, 0-56: Steps on color-specific track, 99: Goal (reached home)
  position: {
    type: Number,
    default: -1
  }
});

const gameRoomSchema = new mongoose.Schema({
  roomCode: {
    type: String,
    required: true,
    unique: true
  },
  creator: {
    type: String,
    required: true
  },
  status: {
    type: String,
    enum: ['waiting', 'playing', 'finished'],
    default: 'waiting'
  },
  players: [playerSchema],
  tokens: [tokenSchema],
  turn: {
    type: String,
    enum: ['red', 'green', 'yellow', 'blue'],
    default: 'red'
  },
  diceValue: {
    type: Number,
    default: 1
  },
  hasRolled: {
    type: Boolean,
    default: false
  },
  winnerId: {
    type: String,
    default: null
  },
  messages: [{
    id: String,
    senderName: String,
    message: String,
    isEmoji: { type: Boolean, default: false },
    timestamp: { type: Date, default: Date.now },
    status: { type: String, enum: ['sending', 'delivered', 'read'], default: 'delivered' }
  }],
  createdAt: {
    type: Date,
    default: Date.now,
    expires: 86400 // Automatically clean up room entries after 24 hours
  }
});

module.exports = mongoose.model('GameRoom', gameRoomSchema);
