const User = require('../models/User');

const googleSignIn = async (req, res) => {
  try {
    const { googleId, name, email, avatarUrl, fcmToken } = req.body;

    if (!googleId || !name || !email) {
      return res.status(400).json({ success: false, message: 'Google ID, name, and email are required.' });
    }

    // Find or create user
    let user = await User.findOne({ googleId });

    if (!user) {
      user = new User({
        googleId,
        name,
        email,
        avatarUrl,
        fcmToken: fcmToken || ''
      });
      await user.save();
      console.log(`New user registered: ${name}`);
    } else {
      // Update details if changed
      user.name = name;
      user.email = email;
      if (avatarUrl) user.avatarUrl = avatarUrl;
      if (fcmToken) user.fcmToken = fcmToken;
      await user.save();
    }

    res.status(200).json({
      success: true,
      message: 'User logged in successfully.',
      user
    });
  } catch (error) {
    console.error('Google sign-in error:', error);
    res.status(500).json({ success: false, message: 'Server error during authentication.', error: error.message });
  }
};

const getProfile = async (req, res) => {
  try {
    const { userId } = req.params;
    
    // Fallback/Sandbox check:
    const mongoose = require('mongoose');
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return res.status(200).json({
        success: true,
        user: {
          _id: userId,
          googleId: `google_${userId}`,
          name: 'Sandbox Guest',
          email: 'guest@sandbox.local',
          avatarUrl: `https://api.dicebear.com/7.x/adventurer/png?seed=${userId}`,
          coins: 1250,
          wins: 4,
          losses: 2,
          fcmToken: ''
        }
      });
    }

    const user = await User.findById(userId);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found' });
    }
    res.status(200).json({ success: true, user });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error', error: error.message });
  }
};

module.exports = {
  googleSignIn,
  getProfile
};
