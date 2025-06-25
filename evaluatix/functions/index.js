/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const {onRequest} = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.generateCustomToken = functions.https.onCall(async (data, context) => {
  const { userId, email } = data;
  if (!userId || !email) {
    throw new functions.https.HttpsError('invalid-argument', 'User ID and email are required');
  }

  const userDoc = await admin.firestore().collection('users').doc(userId).get();
  if (!userDoc.exists || userDoc.data().email !== email) {
    throw new functions.https.HttpsError('not-found', 'User not found or email mismatch');
  }

  const token = await admin.auth().createCustomToken(userId);
  return { token };
});
