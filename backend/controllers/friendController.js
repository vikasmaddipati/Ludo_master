const User = require('../models/User');
const Friendship = require('../models/Friendship');
const mongoose = require('mongoose');

const searchUsers = async (req, res) => {
  try {
    const { query, userId } = req.query;

    if (!query) {
      return res.status(400).json({ success: false, message: 'Search query is required.' });
    }

    // Build filter to exclude current user
    const filter = {
      $or: [
        { name: { $regex: query, $options: 'i' } },
        { email: { $regex: query, $options: 'i' } }
      ]
    };

    if (userId && mongoose.Types.ObjectId.isValid(userId)) {
      filter._id = { $ne: new mongoose.Types.ObjectId(userId) };
    }

    const users = await User.find(filter).limit(20).select('name email avatarUrl wins losses coins');
    res.status(200).json({ success: true, users });
  } catch (error) {
    console.error('Search users error:', error);
    res.status(500).json({ success: false, message: 'Server error searching users.', error: error.message });
  }
};

const sendFriendRequest = async (req, res) => {
  try {
    const { requesterId, recipientId } = req.body;

    if (!requesterId || !recipientId) {
      return res.status(400).json({ success: false, message: 'Requester and recipient IDs are required.' });
    }

    if (requesterId === recipientId) {
      return res.status(400).json({ success: false, message: 'You cannot send a friend request to yourself.' });
    }

    // Convert to ObjectId if valid
    if (!mongoose.Types.ObjectId.isValid(requesterId) || !mongoose.Types.ObjectId.isValid(recipientId)) {
      // Mock/Sandbox success bypass if IDs are custom/sandbox
      return res.status(200).json({ success: true, message: 'Friend request sent (Sandbox Mode).' });
    }

    const reqId = new mongoose.Types.ObjectId(requesterId);
    const recId = new mongoose.Types.ObjectId(recipientId);

    // Check if friendship already exists (in either direction)
    const existingFriendship = await Friendship.findOne({
      $or: [
        { requester: reqId, recipient: recId },
        { requester: recId, recipient: reqId }
      ]
    });

    if (existingFriendship) {
      if (existingFriendship.status === 'accepted') {
        return res.status(400).json({ success: false, message: 'You are already friends.' });
      } else if (existingFriendship.status === 'pending') {
        return res.status(400).json({ success: false, message: 'Friend request already pending.' });
      }
    }

    const newFriendship = new Friendship({
      requester: reqId,
      recipient: recId,
      status: 'pending'
    });

    await newFriendship.save();

    res.status(201).json({ success: true, message: 'Friend request sent successfully.' });
  } catch (error) {
    console.error('Send friend request error:', error);
    res.status(500).json({ success: false, message: 'Server error sending request.', error: error.message });
  }
};

const getFriendRequests = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!userId || !mongoose.Types.ObjectId.isValid(userId)) {
      // Sandbox fallback data
      return res.status(200).json({
        success: true,
        incoming: [
          {
            _id: 'req_1',
            requester: {
              _id: 'user_dummy_1',
              name: 'DiceRollPro 🎲',
              email: 'pro@ludo.net',
              avatarUrl: 'https://api.dicebear.com/7.x/adventurer/png?seed=pro',
              wins: 25,
              losses: 12
            },
            status: 'pending'
          }
        ],
        outgoing: []
      });
    }

    const userObjId = new mongoose.Types.ObjectId(userId);

    const incoming = await Friendship.find({ recipient: userObjId, status: 'pending' })
      .populate('requester', 'name email avatarUrl wins losses coins');

    const outgoing = await Friendship.find({ requester: userObjId, status: 'pending' })
      .populate('recipient', 'name email avatarUrl wins losses coins');

    res.status(200).json({ success: true, incoming, outgoing });
  } catch (error) {
    console.error('Get friend requests error:', error);
    res.status(500).json({ success: false, message: 'Server error getting requests.', error: error.message });
  }
};

const acceptFriendRequest = async (req, res) => {
  try {
    const { requestId } = req.body;

    if (!requestId) {
      return res.status(400).json({ success: false, message: 'Request ID is required.' });
    }

    if (!mongoose.Types.ObjectId.isValid(requestId)) {
      return res.status(200).json({ success: true, message: 'Friend request accepted (Sandbox Mode).' });
    }

    const friendship = await Friendship.findById(requestId);
    if (!friendship) {
      return res.status(404).json({ success: false, message: 'Friend request not found.' });
    }

    friendship.status = 'accepted';
    await friendship.save();

    res.status(200).json({ success: true, message: 'Friend request accepted.', friendship });
  } catch (error) {
    console.error('Accept friend request error:', error);
    res.status(500).json({ success: false, message: 'Server error.', error: error.message });
  }
};

const rejectFriendRequest = async (req, res) => {
  try {
    const { requestId } = req.body;

    if (!requestId) {
      return res.status(400).json({ success: false, message: 'Request ID is required.' });
    }

    if (!mongoose.Types.ObjectId.isValid(requestId)) {
      return res.status(200).json({ success: true, message: 'Friend request removed (Sandbox Mode).' });
    }

    const friendship = await Friendship.findByIdAndDelete(requestId);
    if (!friendship) {
      return res.status(404).json({ success: false, message: 'Friend request not found.' });
    }

    res.status(200).json({ success: true, message: 'Friend request declined/removed.' });
  } catch (error) {
    console.error('Reject friend request error:', error);
    res.status(500).json({ success: false, message: 'Server error.', error: error.message });
  }
};

const getFriendsList = async (req, res) => {
  try {
    const { userId } = req.params;

    if (!userId || !mongoose.Types.ObjectId.isValid(userId)) {
      // Sandbox/Mock fallback
      return res.status(200).json({
        success: true,
        friends: [
          {
            _id: 'friendship_mock_1',
            friend: {
              _id: 'user_dummy_2',
              name: 'LudoStar 🌟',
              email: 'star@ludo.org',
              avatarUrl: 'https://api.dicebear.com/7.x/adventurer/png?seed=star',
              wins: 48,
              losses: 22,
              coins: 3400
            }
          },
          {
            _id: 'friendship_mock_2',
            friend: {
              _id: 'user_dummy_3',
              name: 'BoardMaster 🏆',
              email: 'master@board.com',
              avatarUrl: 'https://api.dicebear.com/7.x/adventurer/png?seed=master',
              wins: 89,
              losses: 45,
              coins: 5200
            }
          }
        ]
      });
    }

    const userObjId = new mongoose.Types.ObjectId(userId);

    const friendships = await Friendship.find({
      $or: [
        { requester: userObjId, status: 'accepted' },
        { recipient: userObjId, status: 'accepted' }
      ]
    }).populate('requester recipient', 'name email avatarUrl wins losses coins');

    // Format output to return a clean list of friends with a unified format
    const friends = friendships.map(f => {
      const isRequester = f.requester._id.toString() === userId;
      const friendData = isRequester ? f.recipient : f.requester;
      return {
        _id: f._id,
        friend: friendData
      };
    });

    res.status(200).json({ success: true, friends });
  } catch (error) {
    console.error('Get friends list error:', error);
    res.status(500).json({ success: false, message: 'Server error getting friends.', error: error.message });
  }
};

module.exports = {
  searchUsers,
  sendFriendRequest,
  getFriendRequests,
  acceptFriendRequest,
  rejectFriendRequest,
  getFriendsList
};
