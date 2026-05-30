const express = require('express');
const router = express.Router();
const { googleSignIn, getProfile } = require('../controllers/authController');

router.post('/google', googleSignIn);
router.get('/profile/:userId', getProfile);

module.exports = router;
