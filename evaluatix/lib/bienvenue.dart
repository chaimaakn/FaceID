import 'dart:io';
import 'package:evaluatix/signin.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:evaluatix/image_picker_service.dart';
import 'package:evaluatix/face_recognition_service.dart';
import 'package:evaluatix/user_repository.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class Bienvenue extends StatefulWidget {
  const Bienvenue({Key? key}) : super(key: key);

  @override
  _BienvenueState createState() => _BienvenueState();
}

class _BienvenueState extends State<Bienvenue> with SingleTickerProviderStateMixin {
  final UserRepository _userRepository = UserRepository();
  final ImagePickerService _imagePickerService = ImagePickerService();
  final FaceRecognitionService _faceService = FaceRecognitionService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _userName = '';
  String _userEmail = '';
  File? _faceImage;
  String? _faceImagePath;
  bool _isLoading = true;
  String _message = '';
  bool _isSuccess = false;
  bool _useCloud = true;

  // Contrôleurs pour les champs de gestion de compte
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _newUsernameController = TextEditingController();
  final TextEditingController _newEmailController = TextEditingController();

  // Animation controller
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  int _selectedIndex = 0;
  final List<String> _sectionTitles = ['Profil', 'Sécurité', 'Compte'];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        _navigateToSignIn();
        return;
      }

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        setState(() {
          _userEmail = user.email ?? '';
          _userName = userDoc.data()?['displayName'] ?? '';
          _faceImagePath = userDoc.data()?['faceImageUrl'] ?? userDoc.data()?['faceImagePath'];
        });

        if (_faceImagePath != null) {
          if (_useCloud) {
            final response = await http.get(Uri.parse(_faceImagePath!));
            final bytes = response.bodyBytes;
            final directory = await getTemporaryDirectory();
            final filePath = path.join(directory.path, 'temp_face_image.jpg');
            final file = File(filePath)..writeAsBytesSync(bytes);
            setState(() {
              _faceImage = file;
            });
          } else {
            final imageFile = File(_faceImagePath!);
            if (await imageFile.exists()) {
              setState(() {
                _faceImage = imageFile;
              });
            }
          }
        }
      } else {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
        });
        setState(() {
          _userEmail = user.email ?? '';
        });
      }
    } catch (e) {
      debugPrint('Erreur lors du chargement des données utilisateur: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToSignIn() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const Signin()),
          (Route<dynamic> route) => false,
    );
  }

  Future<void> _updateProfileImage() async {
    try {
      final File? imageFile = await _imagePickerService.pickImageFromSourceDialog(context);
      if (imageFile != null) {
        final User? user = _auth.currentUser;
        if (user != null) {
          setState(() {
            _isLoading = true;
          });

          final imagePath = await _faceService.saveFaceImage(imageFile, user.uid, useCloud: _useCloud);
          await _userRepository.updateUser(
            userId: user.uid,
            newFaceImage: imagePath,
            useCloud: _useCloud,
          );

          setState(() {
            _faceImage = imageFile;
            _message = 'Photo de profil mise à jour avec succès';
            _isSuccess = true;
            _showSnackbar('Photo de profil mise à jour avec succès', true);
          });

          await _loadUserData();
        }
      }
    } catch (e) {
      setState(() {
        _message = 'Erreur lors de la mise à jour de la photo: ${e.toString()}';
        _isSuccess = false;
        _showSnackbar('Erreur lors de la mise à jour de la photo', false);
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testFaceRecognition() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) return;

      final File? testImage = await _imagePickerService.pickImageFromSourceDialog(context);
      if (testImage == null) return;

      setState(() {
        _isLoading = true;
        _message = '';
      });

      final bool isMatch = await _faceService.compareFaces(testImage, user.uid, useCloud: _useCloud);

      setState(() {
        _message = isMatch
            ? 'Reconnaissance faciale réussie !'
            : 'Échec de la reconnaissance faciale. Veuillez réessayer.';
        _isSuccess = isMatch;
        _showSnackbar(_message, isMatch);
      });
    } catch (e) {
      setState(() {
        _message = 'Erreur lors du test de reconnaissance faciale: ${e.toString()}';
        _isSuccess = false;
        _showSnackbar('Erreur lors du test de reconnaissance faciale', false);
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      _showSnackbar('Les mots de passe ne correspondent pas', false);
      return;
    }

    if (_newPasswordController.text.length < 6) {
      _showSnackbar('Le mot de passe doit contenir au moins 6 caractères', false);
      return;
    }

    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        await user.updatePassword(_newPasswordController.text);
        _showSnackbar('Mot de passe changé avec succès !', true);
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } catch (e) {
      _showSnackbar('Erreur: ${e.toString()}', false);
    }
  }

  Future<void> _changeUsername() async {
    if (_newUsernameController.text.isEmpty) {
      _showSnackbar('Veuillez entrer un nouveau nom d\'utilisateur', false);
      return;
    }

    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'displayName': _newUsernameController.text,
        });
        setState(() {
          _userName = _newUsernameController.text;
        });
        _showSnackbar('Nom d\'utilisateur changé avec succès !', true);
        _newUsernameController.clear();
      }
    } catch (e) {
      _showSnackbar('Erreur: ${e.toString()}', false);
    }
  }

  Future<void> _changeEmail() async {
    if (_newEmailController.text.isEmpty) {
      _showSnackbar('Veuillez entrer un nouvel email', false);
      return;
    }

    try {
      final User? user = _auth.currentUser;
      if (user != null) {
        await user.verifyBeforeUpdateEmail(_newEmailController.text);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'email': _newEmailController.text,
        });
        setState(() {
          _userEmail = _newEmailController.text;
        });
        _showSnackbar('Email mis à jour. Vérifiez votre boîte de réception pour confirmer', true);
        _newEmailController.clear();
      }
    } catch (e) {
      _showSnackbar('Erreur: ${e.toString()}', false);
    }
  }

  void _showSnackbar(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message),
            ),
          ],
        ),
        backgroundColor: isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFE57373),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      _navigateToSignIn();
    } catch (e) {
      debugPrint('Erreur lors de la déconnexion: $e');
    }
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 2,
                      blurRadius: 7,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _faceImage != null
                      ? Image.file(_faceImage!, fit: BoxFit.cover)
                      : Container(
                    color: const Color(0xFFEEEEEE),
                    child: const Icon(Icons.person, size: 60, color: Color(0xFF9E9E9E)),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _updateProfileImage,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            _userName.isNotEmpty ? _userName : 'Utilisateur',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _userEmail,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required String title,
    required IconData icon,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color iconColor = const Color(0xFF7142D2),
    bool showDivider = true,
  }) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 22,
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 14,
            ),
          )
              : null,
          trailing: trailing ??
              (onTap != null
                  ? const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Color(0xFFBDBDBD),
              )
                  : null),
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            thickness: 0.5,
            indent: 70,
            endIndent: 20,
          ),
      ],
    );
  }

  Widget _buildFaceRecognitionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 20, top: 20, bottom: 10),
          child: Text(
            'RECONNAISSANCE FACIALE',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF757575),
              letterSpacing: 1.2,
            ),
          ),
        ),
        _buildSettingItem(
          title: 'Tester la reconnaissance',
          subtitle: 'Vérifiez si votre visage est reconnu par le système',
          icon: Icons.face,
          iconColor: const Color(0xFF0F9393),
          onTap: _testFaceRecognition,
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Pour des résultats optimaux, assurez-vous que votre photo est bien éclairée et montre clairement votre visage.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF9E9E9E),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 20, top: 20, bottom: 10),
          child: Text(
            'PARAMÈTRES DU COMPTE',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF757575),
              letterSpacing: 1.2,
            ),
          ),
        ),
        _buildSettingItem(
          title: 'Modifier le nom d\'utilisateur',
          subtitle: _userName.isNotEmpty ? _userName : 'Non défini',
          icon: Icons.person,
          onTap: () => _showUpdateBottomSheet(
            title: 'Modifier le nom d\'utilisateur',
            currentValue: _userName,
            controller: _newUsernameController,
            onSave: _changeUsername,
            icon: Icons.person,
            hint: 'Nouveau nom d\'utilisateur',
          ),
        ),
        _buildSettingItem(
          title: 'Modifier l\'adresse email',
          subtitle: _userEmail,
          icon: Icons.email,
          onTap: () => _showUpdateBottomSheet(
            title: 'Modifier l\'adresse email',
            currentValue: _userEmail,
            controller: _newEmailController,
            onSave: _changeEmail,
            icon: Icons.email,
            hint: 'Nouvelle adresse email',
            keyboardType: TextInputType.emailAddress,
          ),
        ),
        _buildSettingItem(
          title: 'Modifier le mot de passe',
          subtitle: 'Changez votre mot de passe',
          icon: Icons.lock,
          onTap: () => _showPasswordBottomSheet(),
        ),
        _buildSettingItem(
          title: 'Se déconnecter',
          icon: Icons.exit_to_app,
          iconColor: const Color(0xFFE57373),
          onTap: () => _showConfirmBottomSheet(
            title: 'Se déconnecter',
            content: 'Êtes-vous sûr de vouloir vous déconnecter ?',
            onConfirm: _signOut,
          ),
          showDivider: false,
        ),
      ],
    );
  }

  void _showUpdateBottomSheet({
    required String title,
    required String currentValue,
    required TextEditingController controller,
    required VoidCallback onSave,
    required IconData icon,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    controller.text = currentValue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 15),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7142D2).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: const Color(0xFF7142D2)),
                    ),
                    const SizedBox(width: 15),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Input field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: hint,
                    filled: true,
                    fillColor: const Color(0xFFF5F7FA),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: Color(0xFF7142D2), width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Annuler',
                          style: TextStyle(
                            color: Color(0xFF757575),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onSave();
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: const Color(0xFF7142D2),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Enregistrer',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPasswordBottomSheet() {
    _newPasswordController.clear();
    _confirmPasswordController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 15),
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Title
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.lock, color: Color(0xFF7142D2), size: 24),
                    SizedBox(width: 15),
                    Text(
                      'Modifier le mot de passe',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              // Password fields
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    TextField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Nouveau mot de passe',
                        filled: true,
                        fillColor: const Color(0xFFF5F7FA),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: Color(0xFF7142D2), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Confirmer le mot de passe',
                        filled: true,
                        fillColor: const Color(0xFFF5F7FA),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: const BorderSide(color: Color(0xFF7142D2), width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 25),
              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Annuler',
                          style: TextStyle(
                            color: Color(0xFF757575),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _changePassword();
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: const Color(0xFF7142D2),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Enregistrer',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConfirmBottomSheet({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            // Icon
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: const Color(0xFFE57373).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout,
                color: Color(0xFFE57373),
                size: 30,
              ),
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 10),
            // Content
            Text(
              content,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF757575),
              ),
            ),
            const SizedBox(height: 30),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(
                        color: Color(0xFF757575),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: const Color(0xFFE57373),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'Se déconnecter',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    if (_selectedIndex == 0) {
      return Column(
        children: [
          _buildProfileHeader(),
          _buildFaceRecognitionSection(),
        ],
      );
    } else if (_selectedIndex == 1) {
      return Column(
        children: [
          const SizedBox(height: 20),
          _buildFaceRecognitionSection(),
        ],
      );
    } else {
      return _buildAccountSection();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _sectionTitles[_selectedIndex],
          style: const TextStyle(
            color: Color(0xFF333333),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Stack(
        children: [
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.1),
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF7142D2)),
              ),
            )
          else
            Column(
              children: [
                // Tab navigation
                Container(
                  color: Colors.white,
                  child: Row(
                    children: List.generate(
                      _sectionTitles.length,
                          (index) => Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedIndex = index;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: _selectedIndex == index
                                      ? const Color(0xFF7142D2)
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Text(
                              _sectionTitles[index],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _selectedIndex == index
                                    ? const Color(0xFF7142D2)
                                    : const Color(0xFF9E9E9E),
                                fontWeight: _selectedIndex == index
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Content
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      child: _buildContentSection(),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _faceService.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _newUsernameController.dispose();
    _newEmailController.dispose();
    super.dispose();
  }
}