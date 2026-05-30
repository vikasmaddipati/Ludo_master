const User = require('../models/User');

const getLeaderboard = async (req, res) => {
  try {
    const { sortBy } = req.query; // 'wins' or 'coins'
    const sortField = sortBy === 'coins' ? 'coins' : 'wins';

    // Retrieve top 50 players with at least 1 win
    const topPlayers = await User.find({ wins: { $gt: 0 } })
      .sort({ [sortField]: -1 })
      .limit(50)
      .select('name email avatarUrl wins coins');

    // Calculate current requesting user's dynamic rank if userId is provided
    const { userId } = req.query;
    let userRank = null;

    if (userId) {
      const allUsers = await User.find({ wins: { $gt: 0 } }).sort({ [sortField]: -1 }).select('_id');
      const index = allUsers.findIndex(u => u._id.toString() === userId);
      if (index !== -1) {
        userRank = index + 1;
      }
    }

    res.status(200).json({
      success: true,
      leaderboard: topPlayers,
      userRank
    });
  } catch (error) {
    console.error('Error fetching leaderboard:', error);
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

module.exports = {
  getLeaderboard
};
