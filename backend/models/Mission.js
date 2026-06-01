const mongoose = require('mongoose');

const missionSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    ref: 'User'
  },
  missionType: {
    type: String,
    enum: ['play_matches', 'win_matches', 'invite_friend', 'send_messages', 'roll_dice'],
    required: true
  },
  title: {
    type: String,
    required: true
  },
  currentCount: {
    type: Number,
    default: 0
  },
  targetCount: {
    type: Number,
    required: true
  },
  rewardCoins: {
    type: Number,
    required: true
  },
  rewardXp: {
    type: Number,
    required: true
  },
  isWeekly: {
    type: Boolean,
    default: false
  },
  isClaimed: {
    type: Boolean,
    default: false
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('Mission', missionSchema);
