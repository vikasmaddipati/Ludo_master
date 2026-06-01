const express = require('express');
const router = express.Router();
const {
  getRewardsSummary,
  claimDailyReward,
  claimMissionReward,
  claimAchievementReward,
  getRewardHistory
} = require('../controllers/rewardController');

router.get('/summary/:userId', getRewardsSummary);
router.post('/claim-daily', claimDailyReward);
router.post('/claim-mission', claimMissionReward);
router.post('/claim-achievement', claimAchievementReward);
router.get('/history/:userId', getRewardHistory);

module.exports = router;
