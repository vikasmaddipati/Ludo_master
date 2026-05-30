const express = require('express');
const router = express.Router();
const { createRoom, getRoomDetails, getLiveKitToken } = require('../controllers/gameController');

router.post('/create', createRoom);
router.get('/room/:code', getRoomDetails);
router.get('/livekit-token', getLiveKitToken);

module.exports = router;
