const express = require('express');
const admin = require('firebase-admin');
const app = express();

// Charger les identifiants Firebase
const serviceAccount = require('./yourfirebasefileee.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

app.use(express.json());

// Route pour générer un token personnalisé
app.post('/generateCustomToken', async (req, res) => {
  const { userId, email } = req.body;
  if (!userId || !email) {
    return res.status(400).json({ error: 'User ID and email are required' });
  }

  try {
    // Vérifier l'utilisateur dans Firestore
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    if (!userDoc.exists || userDoc.data().email !== email) {
      return res.status(404).json({ error: 'User not found or email mismatch' });
    }

    // Générer un token personnalisé
    const token = await admin.auth().createCustomToken(userId);
    res.json({ token });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});