const mongoose = require('mongoose');
const GameRoom = require('./models/GameRoom');

const run = async () => {
  try {
    await mongoose.connect('mongodb://localhost:27017/ludomaster');
    console.log('DB Connected.');
    const room = await GameRoom.findOne({ roomCode: '296850' });
    console.log('Room info:', JSON.stringify(room, null, 2));
  } catch (err) {
    console.error(err);
  } finally {
    await mongoose.disconnect();
  }
};

run();
