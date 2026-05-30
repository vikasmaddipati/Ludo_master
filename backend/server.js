require('dotenv').config();
const express = require('express');
const http = require('http');
const cors = require('cors');
const socketIo = require('socket.io');

const connectDB = require('./config/db');
const authRoutes = require('./routes/authRoutes');
const gameRoutes = require('./routes/gameRoutes');
const rewardRoutes = require('./routes/rewardRoutes');
const leaderboardRoutes = require('./routes/leaderboardRoutes');
const { initSocket } = require('./sockets/gameSocket');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// Connect to Database
connectDB();

// Middleware
app.use(cors());
app.use(express.json());

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/game', gameRoutes);
app.use('/api/rewards', rewardRoutes);
app.use('/api/leaderboard', leaderboardRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'OK', message: 'Ludo backend server is active.' });
});

// Socket.io initialization
initSocket(io);

// Start Server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Ludo Backend Server running on port ${PORT}`);
});
