import 'dart:io';
import 'package:http/http.dart' as http; // Pour les requêtes HTTP
import 'dart:convert'; // Pour JSON
import 'package:evaluatix/fillinfo.dart';
import 'package:evaluatix/bienvenue.dart';
import 'package:evaluatix/image_picker_service.dart';
import 'package:evaluatix/user_repository.dart';
import 'package:evaluatix/face_recognition_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Signin extends StatefulWidget {
  const Signin({super.key});

  @override
  _SigninState createState() => _SigninState();
}

class _SigninState extends State<Signin> {
  final TextEditingController _emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserRepository _userRepository = UserRepository();
  final ImagePickerService _imagePickerService = ImagePickerService();
  final FaceRecognitionService _faceService = FaceRecognitionService();

  String _errorMessage = '';
  bool _isLoading = false;
  bool _showFaceRecognition = false;
  File? _selectedFaceImage;
  bool _useCloud = true;

  @override
  void initState() {
    super.initState();
    try {
      FirebaseAuth.instance.authStateChanges();
      print("Firebase Auth est disponible");
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur de configuration Firebase: $e";
      });
      print("Erreur Firebase Auth: $e");
    }
  }

  Future<void> _checkUserExists() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = "Veuillez entrer un email";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Fillinfo(
            email: _emailController.text.trim(),
            isSignUp: false,
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _attemptFaceLogin() async {
    if (_emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = "Veuillez entrer votre email pour la reconnaissance faciale";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _showFaceRecognition = true;
    });

    try {
      final File? faceImage = await _imagePickerService.takePhoto();
      if (faceImage == null) {
        setState(() {
          _errorMessage = "Aucune image sélectionnée";
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _selectedFaceImage = faceImage;
      });

      final QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: _emailController.text.trim())
          .limit(1)
          .get();
      if (querySnapshot.docs.isEmpty) {
        setState(() {
          _errorMessage = "Utilisateur non trouvé. Veuillez vérifier votre email ou créer un compte.";
          _isLoading = false;
        });
        return;
      }

      final String userId = querySnapshot.docs.first.id;
      final bool isMatch = await _faceService.compareFaces(faceImage, userId, useCloud: _useCloud);

      if (isMatch) {
        // Appeler le serveur local pour obtenir un token personnalisé
        final response = await http.post(
          Uri.parse('http://172.20.10.6:3000/generateCustomToken'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'userId': userId,
            'email': _emailController.text.trim(),
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final String customToken = data['token'];
          await _auth.signInWithCustomToken(customToken);

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Bienvenue()),
          );
        } else {
          setState(() {
            _errorMessage = "Erreur lors de la génération du token: ${response.body}";
          });
        }
      } else {
        setState(() {
          _errorMessage = "La reconnaissance faciale a échoué. Veuillez réessayer.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Erreur: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text(''),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                children: <Widget>[
              Center(
              child: Image.asset(
                'lib/iconse/Evaluatix.png',
                width: 100,
                height: 100,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Evaluatix',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF15174C),
              ),
            ),
            const SizedBox(height: 20),
            if (_errorMessage.isNotEmpty)
        Container(
        padding: const EdgeInsets.all(10),
    color: Colors.red.withOpacity(0.1),
    child: Text(
    _errorMessage,
    style: const TextStyle(color: Colors.red),
    ),
    ),
    const SizedBox(height: 10),
    if (_showFaceRecognition && _selectedFaceImage != null) ...[
    ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Image.file(
    _selectedFaceImage!,
    height: 200,
    width: 200,
    fit: BoxFit.cover,
    ),
    ),
    const SizedBox(height: 20),
    ElevatedButton(
    onPressed: _attemptFaceLogin,
    child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
    style: ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
    textStyle: const TextStyle(fontSize: 16),
    backgroundColor: const Color(0xFF7142D2),
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10.0),
    ),
    ),
    ),
    const SizedBox(height: 20),
    TextButton(
    onPressed: () {
    setState(() {
    _showFaceRecognition = false;
    _selectedFaceImage = null;
    });
    },
    child: const Text(
    'Utiliser le mot de passe à la place',
    style: TextStyle(color: Color(0xFF0F9393)),
    ),
    ),
    ] else ...[
    const Text(
    "Entrez votre nom d'utilisateur",
    style: TextStyle(
    fontSize: 16,
    color: Color(0xFF0F9393),
    ),
    ),
    const SizedBox(height: 10),
    TextField(
    controller: _emailController,
    keyboardType: TextInputType.emailAddress,
    decoration: InputDecoration(
    hintText: 'entreprise@gmail.com',
    border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10.0),
    ),
    filled: true,
    fillColor: Colors.white,
    ),
    ),
    const SizedBox(height: 8),
    const Text(
    "L'email est nécessaire pour la reconnaissance faciale",
    style: TextStyle(
    fontSize: 12,
    fontStyle: FontStyle.italic,
    color: Colors.grey,
    ),
    ),
    const SizedBox(height: 5),
    const Text(
    'OU',
    style: TextStyle(fontSize: 16, color: Color(0xFF0F9393)),
    ),
    const SizedBox(height: 15),
    /*
    ElevatedButton.icon(
    onPressed: () {
    // Action pour lire le code QR
    },
    icon: const Icon(Icons.qr_code_scanner),
    label: const Text('LIRE LE CODE QR'),
    style: ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
    textStyle: const TextStyle(fontSize: 16),
    backgroundColor: Colors.white,
    foregroundColor: const Color(0xFF0F9393),
    side: const BorderSide(color: Color(0xFF0F9393)),
    ),
    ),
    const SizedBox(height: 20),*/
    ElevatedButton.icon(
    onPressed: _attemptFaceLogin,
    icon: const Icon(Icons.face),
    label: const Text('Passer Par Face ID'),
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      textStyle: const TextStyle(fontSize: 16),
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF0F9393),
      side: const BorderSide(color: Color(0xFF0F9393)),
    ),
    ),
    const SizedBox(height: 20),
    _isLoading
    ? const CircularProgressIndicator(color: Color(0xFF7142D2))
        : ElevatedButton(
    onPressed: _checkUserExists,
    child: const Text('Next', style: TextStyle(color: Colors.white)),
    style: ElevatedButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
    textStyle: const TextStyle(fontSize: 16),
    backgroundColor: const Color(0xFF7142D2),
    shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(10.0),
    ),
    ),
    ),
    const SizedBox(height: 20),
    Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
    TextButton(
    onPressed: () {
    Navigator.push(
    context,
    MaterialPageRoute(
    builder: (context) => Fillinfo(
    email: _emailController.text.trim(),
    isSignUp: true,
    ),
    ),
    );
    },
    child: const Text(
    "Vous n'avez pas de compte ?",
    style: TextStyle(color: Color(0xFF0F9393)),
    ),
    ),
    TextButton(
    onPressed: () {
    if (_emailController.text.trim().isNotEmpty) {
    _auth.sendPasswordResetEmail(email: _emailController.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Email de réinitialisation envoyé')),
    );
    } else {
    ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Veuillez entrer votre email')),
    );
    }
    },
    child: const Text(
    'Reset here',
    style: TextStyle(color: Color(0xFF0F9393)),
    ),
    ),
    ],
    ),
    ],
    ],
    ),
    ),
    ),
    );
  }
}