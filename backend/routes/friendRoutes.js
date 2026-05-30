const express = require('express');
const router = express.Router();
const {
  searchUsers,
  sendFriendRequest,
  getFriendRequests,
  acceptFriendRequest,
  rejectFriendRequest,
  getFriendsList
} = require('../controllers/friendController');

router.get('/search', searchUsers);
router.post('/request', sendFriendRequest);
router.get('/requests/:userId', getFriendRequests);
router.post('/accept', acceptFriendRequest);
router.post('/reject', rejectFriendRequest);
router.get('/:userId', getFriendsList);

module.exports = router;
