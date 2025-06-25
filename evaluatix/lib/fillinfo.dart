import 'dart:io';
import 'package:evaluatix/bienvenue.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:evaluatix/image_picker_service.dart';
import 'package:evaluatix/user_repository.dart';
import 'package:evaluatix/face_recognition_service.dart';

class Fillinfo extends StatefulWidget {
  final String email;
  final bool isSignUp;

  const Fillinfo({Key? key, required this.email, this.isSignUp = false}) : super(key: key);

  @override
  _FillinfoState createState() => _FillinfoState();
}

class _FillinfoState extends State<Fillinfo> {
  bool _obscureText = true;
  bool _obscureConfirmText = true;
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserRepository _userRepository = UserRepository();
  final ImagePickerService _imagePickerService = ImagePickerService();
  final FaceRecognitionService _faceService = FaceRecognitionService(); // Instance correcte
  String _errorMessage = '';
  bool _isLoading = false;
  File? _selectedFaceImage;
  bool _isFaceImageRequired = true;
  bool _useCloud = true;

  @override
  void initState() {
    super.initState();
    _isFaceImageRequired = widget.isSignUp;
  }

  Future<void> _pickFaceImage() async {
    try {
      final File? imageFile = await _imagePickerService.pickImageFromSourceDialog(context);
      if (imageFile != null) {
        if (!mounted) return;
        bool fileExists = await imageFile.exists();
        int fileSize = await imageFile.length();
        if (!fileExists || fileSize <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image invalide, veuillez réessayer')),
          );
          return;
        }
        setState(() {
          _selectedFaceImage = imageFile;
          _errorMessage = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo sélectionnée avec succès')),
        );
        print('Image sélectionnée: ${imageFile.path}, taille: $fileSize bytes');
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune photo sélectionnée')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Erreur lors de la sélection: ${e.toString()}';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    }
  }

  Future<void> _signInOrSignUp() async {
    if (_passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = "Veuillez entrer votre mot de passe";
      });
      return;
    }

    if (widget.isSignUp) {
      if (_passwordController.text != _confirmPasswordController.text) {
        setState(() {
          _errorMessage = "Les mots de passe ne correspondent pas";
        });
        return;
      }
      if (_passwordController.text.length < 6) {
        setState(() {
          _errorMessage = "Le mot de passe doit comporter au moins 6 caractères";
        });
        return;
      }
      if (_selectedFaceImage == null) {
        setState(() {
          _errorMessage = "Veuillez sélectionner une photo pour la reconnaissance faciale";
        });
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (widget.isSignUp) {
        final imagePath = await _faceService.saveFaceImage(_selectedFaceImage!, widget.email, useCloud: _useCloud); // Utilisation de _faceService
        await _userRepository.signUp(
          email: widget.email,
          password: _passwordController.text,
          faceImage: imagePath,
          displayName: _displayNameController.text.isNotEmpty ? _displayNameController.text : null,
          useCloud: _useCloud,
        );
      } else {
        await _auth.signInWithEmailAndPassword(
          email: widget.email,
          password: _passwordController.text,
        );
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Bienvenue()),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _errorMessage = 'Aucun utilisateur trouvé pour cet email.';
        } else if (e.code == 'wrong-password') {
          _errorMessage = 'Mot de passe incorrect.';
        } else if (e.code == 'email-already-in-use') {
          _errorMessage = 'Cet email est déjà utilisé.';
        } else if (e.code == 'weak-password') {
          _errorMessage = 'Le mot de passe est trop faible.';
        } else {
          _errorMessage = 'Erreur: ${e.message}';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur inattendue: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    try {
      await _auth.sendPasswordResetEmail(email: widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email de réinitialisation envoyé')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
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
              Text(
                widget.isSignUp ? 'Créer un compte' : 'Se Connecter',
                style: const TextStyle(
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
              const Text(
                "Nom utilisateur",
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF0F9393),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                enabled: false,
                controller: TextEditingController(text: widget.email),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  filled: true,
                  fillColor: Colors.grey[200],
                ),
              ),
              if (widget.isSignUp) ...[
                const SizedBox(height: 10),
                const Text(
                  "Nom d'utilisateur (optionnel)",
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF0F9393),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _displayNameController,
                  decoration: InputDecoration(
                    hintText: 'Entrez votre nom d\'utilisateur...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              const Text(
                "Mot de passe",
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF0F9393),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  hintText: 'Entrez votre mot de passe...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                ),
              ),
              if (widget.isSignUp) ...[
                const SizedBox(height: 10),
                const Text(
                  "Confirmer le mot de passe",
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF0F9393),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmText,
                  decoration: InputDecoration(
                    hintText: 'Confirmez votre mot de passe...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmText ? Icons.visibility : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmText = !_obscureConfirmText;
                        });
                      },
                    ),
                  ),
                ),
              ],
              if (widget.isSignUp) ...[
                const SizedBox(height: 20),
                const Text(
                  "Photo pour la reconnaissance faciale",
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF0F9393),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Color(0xFF0F9393)),
                  ),
                  child: _selectedFaceImage != null
                      ? ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Image.file(
                      _selectedFaceImage!,
                      fit: BoxFit.cover,
                    ),
                  )
                      : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_a_photo,
                        size: 50,
                        color: Color(0xFF0F9393),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isFaceImageRequired
                            ? "Ajouter une photo (obligatoire)"
                            : "Ajouter une photo",
                        style: const TextStyle(
                          color: Color(0xFF0F9393),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _pickFaceImage,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Sélectionner une photo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F9393),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _isLoading
                  ? const CircularProgressIndicator(color: Color(0xFF7142D2))
                  : ElevatedButton(
                onPressed: _signInOrSignUp,
                child: Text(
                  widget.isSignUp ? 'Créer un compte' : 'Se connecter',
                  style: const TextStyle(color: Colors.white),
                ),
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
              if (!widget.isSignUp)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _resetPassword,
                      child: const Text(
                        "mot de passe oublié ?",
                        style: TextStyle(color: Color(0xFF0F9393)),
                      ),
                    ),
                    TextButton(
                      onPressed: _resetPassword,
                      child: const Text(
                        'Reset here',
                        style: TextStyle(color: Color(0xFF0F9393)),
                      ),
                    ),
                  ],
                ),
              if (!widget.isSignUp) ...[
                const SizedBox(height: 20),
                const Text(
                  "Vous n'avez pas de compte ?",
                  style: TextStyle(
                    fontSize: 13,
                    color: Color.fromARGB(255, 62, 62, 62),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Fillinfo(
                          email: widget.email,
                          isSignUp: true,
                        ),
                      ),
                    );
                  },
                  child: const Text('Créer un compte', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    textStyle: const TextStyle(fontSize: 16),
                    backgroundColor: const Color(0xFF7142D2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                ),
              ],
              if (widget.isSignUp) ...[
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Fillinfo(
                          email: widget.email,
                          isSignUp: false,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    "Vous avez déjà un compte ? Se connecter",
                    style: TextStyle(color: Color(0xFF0F9393)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}