const express = require('express');
const router = express.Router();
const { claimDailyReward, getRewardHistory } = require('../controllers/rewardController');

router.post('/daily', claimDailyReward);
router.get('/history/:userId', getRewardHistory);

module.exports = router;
