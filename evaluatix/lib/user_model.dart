class UserModel {
  final String? id;
  final String email;
  final String? displayName;
  final String? faceImagePath;
  final String? faceImageUrl; // Pour Cloudinary
  final bool useCloud;

  UserModel({
    this.id,
    required this.email,
    this.displayName,
    this.faceImagePath,
    this.faceImageUrl,
    this.useCloud = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'faceImagePath': faceImagePath,
      'faceImageUrl': faceImageUrl,
      'useCloud': useCloud,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email'] ?? '',
      displayName: map['displayName'],
      faceImagePath: map['faceImagePath'],
      faceImageUrl: map['faceImageUrl'],
      useCloud: map['useCloud'] ?? false,
    );
  }
}