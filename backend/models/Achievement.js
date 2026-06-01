const mongoose = require('mongoose');

const achievementSchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    ref: 'User'
  },
  key: {
    type: String,
    required: true
  },
  title: {
    type: String,
    required: true
  },
  description: {
    type: String,
    required: true
  },
  currentValue: {
    type: Number,
    default: 0
  },
  targetValue: {
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
  isUnlocked: {
    type: Boolean,
    default: false
  },
  isClaimed: {
    type: Boolean,
    default: false
  },
  unlockedAt: {
    type: Date
  }
});

module.exports = mongoose.model('Achievement', achievementSchema);
