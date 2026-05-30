const User = require('../models/User');
const RewardHistory = require('../models/RewardHistory');

const claimDailyReward = async (req, res) => {
  try {
    const { userId } = req.body;

    if (!userId) {
      return res.status(400).json({ success: false, message: 'User ID is required.' });
    }

    const mongoose = require('mongoose');
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      // Elegant simulated Sandbox Guest Daily Claim Response
      const currentCoins = req.body.currentCoins ? parseInt(req.body.currentCoins) : 1000;
      const rewardAmount = 150;
      const newCoins = currentCoins + rewardAmount;
      return res.status(200).json({
        success: true,
        message: `Daily reward of ${rewardAmount} coins claimed successfully (Sandbox Session)!`,
        coins: newCoins,
        reward: {
          userId,
          rewardType: 'daily',
          amount: rewardAmount,
          date: new Date()
        }
      });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    // Check last daily reward claim
    const lastClaim = await RewardHistory.findOne({
      userId,
      rewardType: 'daily'
    }).sort({ date: -1 });

    const now = new Date();
    if (lastClaim) {
      const timeDiff = now.getTime() - lastClaim.date.getTime();
      const hoursDiff = timeDiff / (1000 * 3600);

      if (hoursDiff < 24) {
        const remainingHours = Math.ceil(24 - hoursDiff);
        return res.status(400).json({
          success: false,
          message: `Daily reward already claimed. Please try again in ${remainingHours} hours.`
        });
      }
    }

    const rewardAmount = 150; // default daily coin bonus

    // Add coins to user and save reward history
    user.coins += rewardAmount;
    await user.save();

    const history = new RewardHistory({
      userId,
      rewardType: 'daily',
      amount: rewardAmount
    });
    await history.save();

    res.status(200).json({
      success: true,
      message: `Daily reward of ${rewardAmount} coins claimed successfully!`,
      coins: user.coins,
      reward: history
    });
  } catch (error) {
    console.error('Error claiming daily reward:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

const getRewardHistory = async (req, res) => {
  try {
    const { userId } = req.params;
    const mongoose = require('mongoose');
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(200).json({ success: true, history: [] });
    }
    const history = await RewardHistory.find({ userId }).sort({ date: -1 });
    res.status(200).json({ success: true, history });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

module.exports = {
  claimDailyReward,
  getRewardHistory
};
