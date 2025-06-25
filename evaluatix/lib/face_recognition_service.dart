import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_ml_kit/google_ml_kit.dart'; // Vous avez résolu le problème, donc on garde cette dépendance
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'dart:convert';
import 'dart:math';

class FaceRecognitionService {
  final FaceDetector _faceDetector = GoogleMlKit.vision.faceDetector(
    FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableTracking: true,
      minFaceSize: 0.1,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<List<Face>> detectFaces(InputImage inputImage) async {
    try {
      final List<Face> faces = await _faceDetector.processImage(inputImage);
      return faces;
    } catch (e) {
      debugPrint('Erreur lors de la détection des visages: $e');
      return [];
    }
  }

  Future<String> saveFaceImage(File imageFile, String userId, {bool useCloud = false}) async {
    try {
      if (useCloud) {
        final String cloudName = 'votre_Cloud_name'; // Remplacez par votre Cloud Name
        final String uploadPreset = 'Preset_name'; // Remplacez par votre preset

        final uri = Uri.parse('cloudinary_pase');
        final request = http.MultipartRequest('POST', uri)
          ..fields['Preset_name'] = uploadPreset
          ..fields['folder'] = 'users/$userId'
          ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

        final response = await request.send();
        final responseData = await response.stream.bytesToString();
        final jsonData = jsonDecode(responseData);

        if (response.statusCode == 200) {
          final String downloadUrl = jsonData['secure_url'];
          debugPrint('Image téléversée sur Cloudinary: $downloadUrl');
          return downloadUrl;
        } else {
          debugPrint('Erreur lors de l\'upload vers Cloudinary: $responseData');
          throw Exception('Erreur lors de l\'upload vers Cloudinary: $responseData');
        }
      } else {
        final directory = await getApplicationDocumentsDirectory();
        final String facesPath = path.join(directory.path, 'faces');
        Directory(facesPath).createSync(recursive: true);
        final String imagePath = path.join(facesPath, '$userId.jpg');
        final File savedImage = await imageFile.copy(imagePath);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('face_image_$userId', imagePath);

        debugPrint('Image stockée localement: $imagePath');
        return imagePath;
      }
    } catch (e) {
      debugPrint('Erreur lors de l\'enregistrement de l\'image: $e');
      throw Exception('Impossible d\'enregistrer l\'image du visage: $e');
    }
  }

  Future<String?> getFaceImagePath(String userId, {bool useCloud = false}) async {
    try {
      if (useCloud) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        return userDoc.data()?['faceImageUrl'];
      } else {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getString('face_image_$userId');
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération du chemin de l\'image: $e');
      return null;
    }
  }

  List<Offset> _extractKeypoints(Face face) {
    List<Offset> keypoints = [];
    final landmarks = [
      FaceLandmarkType.leftEye,
      FaceLandmarkType.rightEye,
      FaceLandmarkType.noseBase,
      FaceLandmarkType.leftMouth,
      FaceLandmarkType.rightMouth,
    ];

    for (var type in landmarks) {
      final point = face.landmarks[type]?.position;
      if (point != null) {
        keypoints.add(Offset(point.x.toDouble(), point.y.toDouble()));
      }
    }

    return keypoints;
  }

  Future<bool> compareFaces(File currentImage, String userId, {bool useCloud = false}) async {
    try {
      File? storedImageFile;
      if (useCloud) {
        final imageUrl = await getFaceImagePath(userId, useCloud: true);
        if (imageUrl == null) return false;
        final response = await http.get(Uri.parse(imageUrl));
        final bytes = response.bodyBytes;
        final directory = await getTemporaryDirectory();
        final filePath = path.join(directory.path, 'temp_face_image.jpg');
        final file = File(filePath)..writeAsBytesSync(bytes);
        storedImageFile = file;
      } else {
        final storedImagePath = await getFaceImagePath(userId);
        if (storedImagePath == null) return false;
        storedImageFile = File(storedImagePath);
      }

      if (storedImageFile == null || !storedImageFile.existsSync()) return false;

      final storedInput = InputImage.fromFile(storedImageFile);
      final currentInput = InputImage.fromFile(currentImage);

      final List<Face> storedFaces = await detectFaces(storedInput);
      final List<Face> currentFaces = await detectFaces(currentInput);

      if (storedFaces.isEmpty || currentFaces.isEmpty) return false;

      final storedFace = storedFaces.first;
      final currentFace = currentFaces.first;

      final List<Offset> storedKeypoints = _normalizeKeypoints(storedFace);
      final List<Offset> currentKeypoints = _normalizeKeypoints(currentFace);

      if (storedKeypoints.length < 5 || currentKeypoints.length < 5) {
        debugPrint('Nombre insuffisant de points faciaux détectés.');
        return false;
      }

      double totalDistance = 0;
      for (int i = 0; i < storedKeypoints.length; i++) {
        totalDistance += _euclideanDistance(storedKeypoints[i], currentKeypoints[i]);
      }

      final double avgDistance = totalDistance / storedKeypoints.length;
      debugPrint('Distance moyenne normalisée : $avgDistance');

      final bool success = avgDistance < 0.5;

      if (success) {
        await playSoundSuccess();
      } else {
        await playSoundFailure();
      }

      return success;
    } catch (e) {
      debugPrint('Erreur dans la comparaison : $e');
      await playSoundFailure();
      return false;
    }
  }

  List<Offset> _normalizeKeypoints(Face face) {
    final landmarks = _extractKeypoints(face);
    if (landmarks.length < 2) return landmarks;

    final leftEye = face.landmarks[FaceLandmarkType.leftEye]?.position;
    final rightEye = face.landmarks[FaceLandmarkType.rightEye]?.position;
    if (leftEye == null || rightEye == null) return landmarks;

    final double eyeDistance = _euclideanDistance(
      Offset(leftEye.x.toDouble(), leftEye.y.toDouble()),
      Offset(rightEye.x.toDouble(), rightEye.y.toDouble()),
    );

    return landmarks.map((point) => Offset(
      point.dx / eyeDistance,
      point.dy / eyeDistance,
    )).toList();
  }

  double _euclideanDistance(Offset p1, Offset p2) {
    return sqrt(pow(p1.dx - p2.dx, 2) + pow(p1.dy - p2.dy, 2));
  }

  Future<void> playSoundSuccess() async {
    try {
      debugPrint('Tentative de lecture du son de succès...');
      await _audioPlayer.play(AssetSource('sounds/success.mp3'));
      debugPrint('Son de succès joué avec succès');
    } catch (e) {
      debugPrint('Erreur lors de la lecture du son de succès: $e');
    }
  }

  Future<void> playSoundFailure() async {
    try {
      debugPrint('Tentative de lecture du son d\'échec...');
      await _audioPlayer.play(AssetSource('sounds/failure.mp3'));
      debugPrint('Son d\'échec joué avec succès');
    } catch (e) {
      debugPrint('Erreur lors de la lecture du son d\'échec: $e');
    }
  }

  Future<void> testSound() async {
    try {
      debugPrint('Test de lecture du son...');
      await _audioPlayer.play(AssetSource('sounds/success.mp3'));
      debugPrint('Test réussi');
    } catch (e) {
      debugPrint('Erreur lors du test de lecture: $e');
    }
  }

  void dispose() {
    _faceDetector.close();
    _audioPlayer.dispose();
  }
}