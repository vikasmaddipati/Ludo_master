const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

let fcmInitialized = false;

// Initialize Firebase Admin SDK
try {
  const serviceAccountPath = process.env.FIREBASE_SERVICE_ACCOUNT_JSON || './config/firebase-service-account.json';
  const absolutePath = path.resolve(serviceAccountPath);

  if (fs.existsSync(absolutePath)) {
    const serviceAccount = require(absolutePath);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    });
    fcmInitialized = true;
    console.log('Firebase Admin SDK initialized successfully for notifications.');
  } else {
    console.warn(`Firebase credentials not found at ${absolutePath}. FCM service running in fallback/debug mode.`);
  }
} catch (error) {
  console.error('Failed to initialize Firebase Admin SDK:', error.message);
}

/**
 * Send a push notification to a specific user device
 * @param {string} token - The FCM registration token
 * @param {string} title - Title of the notification
 * @param {string} body - Body content of the notification
 * @param {object} data - Optional payload dictionary
 */
const sendPushNotification = async (token, title, body, data = {}) => {
  if (!token) return;

  if (!fcmInitialized) {
    console.log(`[Notification Fallback] Mock Send to token ${token.substring(0, 8)}...: Title: "${title}", Body: "${body}"`);
    return;
  }

  try {
    const message = {
      notification: {
        title,
        body
      },
      data: {
        ...data,
        click_action: 'FLUTTER_NOTIFICATION_CLICK'
      },
      token: token
    };

    const response = await admin.messaging().send(message);
    console.log('Notification sent successfully:', response);
    return response;
  } catch (error) {
    console.error('Error sending push notification via FCM:', error);
  }
};

module.exports = {
  sendPushNotification
};
