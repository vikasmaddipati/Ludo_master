const express = require('express');
const router = express.Router();

// Mock middleware to check auth header
const verifyToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  if (!authHeader) {
    return res.status(401).json({ success: false, message: 'Authentication required. Authorization header missing.' });
  }
  // Simplified token validation for demo
  next();
};

// @route   POST /api/voice/process
// @desc    Process/validate vocal text intent payload on server side
// @access  Protected
router.post('/process', verifyToken, (req, res) => {
  const { text, action } = req.body;
  
  if (!text || !action) {
    return res.status(400).json({ success: false, message: 'Missing parameters. Both text and action are required.' });
  }

  console.log(`[REST VOICE PROCESS] Logged voice command: "${text}" resolved to action "${action}"`);

  res.status(200).json({
    success: true,
    message: 'Voice command intent processed and validated successfully.',
    action,
    timestamp: new Date()
  });
});

// @route   POST /api/voice/execute
// @desc    Securely authenticate and execute a lobby trigger modification
// @access  Protected
router.post('/execute', verifyToken, (req, res) => {
  const { action, params, userId } = req.body;

  if (!action || !userId) {
    return res.status(400).json({ success: false, message: 'Missing parameters. Both action and userId are required.' });
  }

  console.log(`[REST VOICE EXECUTE] Executing action "${action}" with parameters: ${JSON.stringify(params)} for player ${userId}`);

  res.status(200).json({
    success: true,
    message: `Action '${action}' executed successfully on server.`,
    action,
    timestamp: new Date()
  });
});

module.exports = router;
