const User = require('../models/User');
const RewardHistory = require('../models/RewardHistory');
const Mission = require('../models/Mission');
const Achievement = require('../models/Achievement');
const mongoose = require('mongoose');

// Seed/Initialize user missions if not present
const initializeUserMissions = async (userId) => {
  const count = await Mission.countDocuments({ userId });
  if (count > 0) return;

  const defaultMissions = [
    // Daily Missions
    { missionType: 'roll_dice', title: 'Roll Dice 20 Times', targetCount: 20, rewardCoins: 100, rewardXp: 20, isWeekly: false },
    { missionType: 'send_messages', title: 'Send 5 Chat Messages', targetCount: 5, rewardCoins: 50, rewardXp: 10, isWeekly: false },
    { missionType: 'play_matches', title: 'Play 3 Matches', targetCount: 3, rewardCoins: 150, rewardXp: 30, isWeekly: false },
    { missionType: 'win_matches', title: 'Win 1 Match', targetCount: 1, rewardCoins: 200, rewardXp: 50, isWeekly: false },
    { missionType: 'invite_friend', title: 'Invite 1 Friend', targetCount: 1, rewardCoins: 100, rewardXp: 25, isWeekly: false },
    // Weekly Missions
    { missionType: 'play_matches', title: 'Play 25 Matches', targetCount: 25, rewardCoins: 800, rewardXp: 150, isWeekly: true },
    { missionType: 'win_matches', title: 'Win 10 Matches', targetCount: 10, rewardCoins: 1500, rewardXp: 300, isWeekly: true },
    { missionType: 'invite_friend', title: 'Invite 5 Friends', targetCount: 5, rewardCoins: 500, rewardXp: 100, isWeekly: true }
  ];

  await Mission.insertMany(defaultMissions.map(m => ({ ...m, userId })));
};

// Seed/Initialize user achievements if not present
const initializeUserAchievements = async (userId) => {
  const count = await Achievement.countDocuments({ userId });
  if (count > 0) return;

  const defaultAchievements = [
    { key: 'first_match', title: 'First Steps', description: 'Play your first Ludo Arena match.', targetValue: 1, rewardCoins: 100, rewardXp: 20 },
    { key: 'first_win', title: 'Victor!', description: 'Claim your first victory in Ludo Arena.', targetValue: 1, rewardCoins: 250, rewardXp: 50 },
    { key: 'wins_10', title: 'Ludo General', description: 'Win 10 multiplayer matches.', targetValue: 10, rewardCoins: 1000, rewardXp: 200 },
    { key: 'wins_50', title: 'Ludo Emperor', description: 'Win 50 multiplayer matches.', targetValue: 50, rewardCoins: 5000, rewardXp: 1000 },
    { key: 'use_voice_50', title: 'Vocal Master', description: 'Use the voice assistant 50 times.', targetValue: 50, rewardCoins: 500, rewardXp: 100 }
  ];

  await Achievement.insertMany(defaultAchievements.map(a => ({ ...a, userId })));
};

// Calculate next level boundary threshold
const getXpThreshold = (level) => {
  if (level === 1) return 100;
  if (level === 2) return 250;
  if (level === 3) return 500;
  return level * 250; // Level 4 -> 1000, etc.
};

// GET Rewards Summary
const getRewardsSummary = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!mongoose.Types.ObjectId.isValid(userId)) {
      // Elegant Sandbox Guest Summary Response
      return res.status(200).json({
        success: true,
        coins: 1200,
        xp: 35,
        level: 1,
        streakCount: 2,
        xpThreshold: 100,
        missions: [
          { _id: 'sandbox_m1', title: 'Roll Dice 20 Times', currentCount: 12, targetCount: 20, rewardCoins: 100, rewardXp: 20, isWeekly: false, isClaimed: false },
          { _id: 'sandbox_m2', title: 'Win 1 Match', currentCount: 1, targetCount: 1, rewardCoins: 200, rewardXp: 50, isWeekly: false, isClaimed: false }
        ],
        achievements: [
          { _id: 'sandbox_a1', title: 'First Steps', description: 'Play your first Ludo Arena match.', currentValue: 1, targetValue: 1, rewardCoins: 100, rewardXp: 20, isUnlocked: true, isClaimed: false }
        ]
      });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    await initializeUserMissions(userId);
    await initializeUserAchievements(userId);

    const missions = await Mission.find({ userId });
    const achievements = await Achievement.find({ userId });

    res.status(200).json({
      success: true,
      coins: user.coins,
      xp: user.xp || 0,
      level: user.level || 1,
      streakCount: user.streakCount || 0,
      xpThreshold: getXpThreshold(user.level || 1),
      missions,
      achievements
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// POST Claim Daily Reward
const claimDailyReward = async (req, res) => {
  try {
    const { userId } = req.body;

    if (!userId) {
      return res.status(400).json({ success: false, message: 'User ID is required.' });
    }

    if (!mongoose.Types.ObjectId.isValid(userId)) {
      // Elegant Sandbox Guest Daily Claim Response
      const currentCoins = req.body.currentCoins ? parseInt(req.body.currentCoins) : 1000;
      const streak = req.body.streak ? (parseInt(req.body.streak) % 7) + 1 : 1;
      const rewards = [50, 100, 150, 250, 500, 750, 1000];
      const amount = rewards[streak - 1];

      return res.status(200).json({
        success: true,
        message: `Day ${streak} Daily reward of ${amount} coins claimed successfully (Sandbox Session)!`,
        coins: currentCoins + amount,
        streakCount: streak,
        xp: 15,
        levelUp: false
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
    let currentStreak = user.streakCount || 0;

    if (lastClaim) {
      const timeDiff = now.getTime() - lastClaim.date.getTime();
      const hoursDiff = timeDiff / (1000 * 3600);

      if (hoursDiff < 24) {
        const remainingHours = Math.ceil(24 - hoursDiff);
        return res.status(400).json({
          success: false,
          message: `Daily reward already claimed. Try again in ${remainingHours} hours.`
        });
      }

      if (hoursDiff >= 24 && hoursDiff <= 48) {
        // Continue Streak
        currentStreak = currentStreak >= 7 ? 1 : currentStreak + 1;
      } else {
        // Over 48 hours: Reset Streak
        currentStreak = 1;
      }
    } else {
      // First Claim ever
      currentStreak = 1;
    }

    // Days rewards table
    const dailyRewards = [50, 100, 150, 250, 500, 750, 1000];
    const rewardAmount = dailyRewards[currentStreak - 1];

    user.coins += rewardAmount;
    user.streakCount = currentStreak;
    user.lastLoginDate = now;

    // Grant XP for claiming daily
    let xpGained = 20;
    user.xp = (user.xp || 0) + xpGained;
    
    // Check level up
    let levelUp = false;
    let threshold = getXpThreshold(user.level || 1);
    if (user.xp >= threshold) {
      user.xp -= threshold;
      user.level = (user.level || 1) + 1;
      levelUp = true;
    }

    await user.save();

    const history = new RewardHistory({
      userId,
      rewardType: 'daily',
      amount: rewardAmount
    });
    await history.save();

    res.status(200).json({
      success: true,
      message: `Day ${currentStreak} Daily Reward of ${rewardAmount} coins claimed!`,
      coins: user.coins,
      streakCount: currentStreak,
      xp: user.xp,
      level: user.level,
      levelUp
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// POST Claim Mission
const claimMissionReward = async (req, res) => {
  try {
    const { userId, missionId } = req.body;

    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(200).json({
        success: true,
        message: 'Mission claimed (Sandbox Guest)!',
        coins: 1500,
        xp: 50,
        levelUp: false
      });
    }

    const mission = await Mission.findOne({ _id: missionId, userId });
    if (!mission) {
      return res.status(404).json({ success: false, message: 'Mission not found.' });
    }

    if (mission.isClaimed) {
      return res.status(400).json({ success: false, message: 'Mission reward already claimed.' });
    }

    if (mission.currentCount < mission.targetCount) {
      return res.status(400).json({ success: false, message: 'Mission goals not met yet.' });
    }

    const user = await User.findById(userId);
    user.coins += mission.rewardCoins;
    user.xp = (user.xp || 0) + mission.rewardXp;

    // Check level up
    let levelUp = false;
    let threshold = getXpThreshold(user.level || 1);
    if (user.xp >= threshold) {
      user.xp -= threshold;
      user.level = (user.level || 1) + 1;
      levelUp = true;
    }

    mission.isClaimed = true;
    await mission.save();
    await user.save();

    const history = new RewardHistory({
      userId,
      rewardType: 'match_win', // Generic type
      amount: mission.rewardCoins
    });
    await history.save();

    res.status(200).json({
      success: true,
      message: `Mission "${mission.title}" claimed successfully!`,
      coins: user.coins,
      xp: user.xp,
      level: user.level,
      levelUp
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// POST Claim Achievement
const claimAchievementReward = async (req, res) => {
  try {
    const { userId, achievementId } = req.body;

    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(200).json({
        success: true,
        message: 'Achievement claimed (Sandbox Guest)!',
        coins: 2000,
        xp: 100,
        levelUp: false
      });
    }

    const achievement = await Achievement.findOne({ _id: achievementId, userId });
    if (!achievement) {
      return res.status(404).json({ success: false, message: 'Achievement not found.' });
    }

    if (achievement.isClaimed) {
      return res.status(400).json({ success: false, message: 'Achievement already claimed.' });
    }

    if (!achievement.isUnlocked) {
      return res.status(400).json({ success: false, message: 'Achievement is locked.' });
    }

    const user = await User.findById(userId);
    user.coins += achievement.rewardCoins;
    user.xp = (user.xp || 0) + achievement.rewardXp;

    // Level up logic
    let levelUp = false;
    let threshold = getXpThreshold(user.level || 1);
    if (user.xp >= threshold) {
      user.xp -= threshold;
      user.level = (user.level || 1) + 1;
      levelUp = true;
    }

    achievement.isClaimed = true;
    await achievement.save();
    await user.save();

    res.status(200).json({
      success: true,
      message: `Achievement "${achievement.title}" claimed successfully!`,
      coins: user.coins,
      xp: user.xp,
      level: user.level,
      levelUp
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

// GET Reward History
const getRewardHistory = async (req, res) => {
  try {
    const { userId } = req.params;
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
  getRewardsSummary,
  claimDailyReward,
  claimMissionReward,
  claimAchievementReward,
  getRewardHistory
};
