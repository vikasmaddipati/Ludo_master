const mongoose = require('mongoose');

const rewardHistorySchema = new mongoose.Schema({
  userId: {
    type: String,
    required: true,
    ref: 'User'
  },
  rewardType: {
    type: String,
    enum: ['daily', 'match_win', 'registration'],
    required: true
  },
  amount: {
    type: Number,
    required: true
  },
  date: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('RewardHistory', rewardHistorySchema);
