## Evaluatix - Face Recognition Authentication App
## Overview
Evaluatix is a mobile application developed using Flutter for Android devices, designed to provide secure user authentication through facial recognition. It integrates Firebase for user authentication and data storage, Google ML Kit for face detection and comparison, and a Node.js server for generating custom authentication tokens. The app allows users to sign up, log in with email/password or Face ID, and manage their profiles, with facial images stored locally or on Cloudinary.

## Features

**User Authentication**: Sign up, log in, and log out using email/password or Face ID.

**Facial Recognition**: Detects and compares faces using Google ML Kit, with a normalized Euclidean distance threshold (<0.5) for successful recognition.

**Image Management**: Capture or select images via camera/gallery, stored locally or uploaded to Cloudinary.

**User Profile**: View and update user details (name, email, profile picture).

**Password Reset**: Email-based password reset functionality.

**Audio Feedback**: Success/error audio cues using the audioplayers package.

**Secure Token Generation**: A Node.js server generates custom Firebase authentication tokens.

## Technologies Used
## Frontend (Flutter)

**Flutter**: Framework for building the cross-platform UI (version 3.22.x as of May 2025).

**Dart**: Programming language for app logic and UI.
## Dependencies:
**firebase_auth**: ^5.4.3 - User authentication.

**cloud_firestore**: ^5.4.3 - NoSQL database for user data.

**google_ml_kit** :^0.16.0 - Face detection and comparison.

**image_picker**: ^1.0.4 - Image selection from camera/gallery.

**path_provider**: ^2.1.1 - Local file storage.

**path**: ^1.8.3 - File path manipulation.

**http**: ^1.1.0 - HTTP requests for Cloudinary uploads.

**audioplayers**: ^5.2.1 - Audio feedback.

**shared_preferences**: ^2.2.2 - Persistent storage for image paths and biometric email.



## Backend (Node.js)

**Express.js**: Framework for handling HTTP routes.

**Firebase Admin SDK**: Generates custom authentication tokens.

## Configuration Files:
**google-services.json**: Firebase configuration for Android.

**login-signin20-firebase-adminsdk-fbsvc-96f6018a84.json**: Firebase service account key.

**package.json**: Node.js dependencies.



## External Services

**Firebase**: Authentication and Firestore database.

**Cloudinary**: Cloud storage for facial images (Cloud Name: duw46pcyo, Upload Preset: flutter_upload).

## Project Structure
```bash
evaluatix/
├── lib/
│   ├── main.dart               # App entry point, Firebase initialization
│   ├── bienvenue.dart         # Main screen for user info and face recognition
│   ├── face_recognition_service.dart  # Face detection and comparison logic
│   ├── image_picker_service.dart      # Image selection from camera/gallery
│   ├── user_repository.dart    # User operations (sign-up, update, fetch)
│   ├── user_model.dart         # User data model
│   ├── signin.dart             # Login screen with Face ID option
│   └── fillinfo.dart           # Screen for entering user details
├── server/
│   ├── server.js               # Node.js server for token generation
│   ├── login-signin20-firebase-adminsdk-fbsvc-96f6018a84.json  # Firebase service key
│   ├── package.json            # Node.js dependencies
│   └── package-lock.json       # Dependency lock file
├── pubspec.yaml               # Flutter dependencies and configuration
└── android/                   # Android-specific configurations
```
## Prerequisites

**Flutter SDK**: Version 3.22.x or later.

**Dart**: Included with Flutter.

**Android Studio**: For Android development and debugging.

**Node.js**: Version 14.x or later for the backend server.

**Firebase Account**: For Authentication and Firestore.

**Cloudinary Account**: For cloud image storage.

**Android device/emulator** with API level 21 or higher.

## Installation

**1.Clone the Repository**:
```bash
git clone https://github.com/chaimaakn/mobile.git
cd evaluatix
```

**2.Install Flutter Dependencies**:
```bash
flutter pub get
```

## Set Up Firebase:
1. Create a Firebase project at Firebase Console.
2. Add an Android app to your Firebase project.
3. Download google-services.json and place it in the android/app/ directory.
4. Enable Email/Password authentication in Firebase Authentication.
5. Set up Firestore with a users collection.


## Set Up Cloudinary:

1. Create a Cloudinary account and note your Cloud Name (******) and Upload Preset (flutter_upload).
2. Configure the upload preset for unsigned uploads.


## Set Up Node.js Server:
```bash
cd server
npm install
```
Place login-signin20-firebase-adminsdk-fbsvc-96f6018a84.json in the server/ directory.
Run the server:
```bash
node server.js
```



## Run the App:
```bash
flutter run
```


## Usage

**Sign Up:**

1. Open the app and navigate to the sign-up screen.
2. Enter your email (e.g., entreprise@gmail.com) and password.
3. Optionally, enable Face ID by capturing a facial image.


**Log In:**

1. On the sign-in screen, enter your email and password, or select "Passer Par Face ID".
2. For Face ID, ensure good lighting and a clear view of your face.


**Profile Management:**

1. Access the profile screen to view/update your name, email, or profile picture.
2. Test facial recognition via the "Tester la reconnaissance" button.


**Password Reset:**

Click "Reset here" on the sign-in screen, enter your email, and follow the reset link sent to your inbox.



**Face Recognition Flow**

**Image Capture:** Select or capture an image using ImagePickerService.
**Face Comparison:** FaceRecognitionService compares the captured image with the stored image using Google ML Kit (threshold <0.5 for success).
**Token Generation:** If recognition succeeds, a POST request is sent to http://localhost:3000/generateCustomToken with userId and email.
**Session Authentication:** The returned token is stored locally and used to authenticate the user with Firebase, redirecting to the Bienvenue screen.

## Troubleshooting

**"No account found with this email" Error:**
Ensure the email is correctly registered in Firebase Authentication.
Check SharedPreferences for the stored biometric_email (use the debug button in signin.dart).
Verify the email case sensitivity and normalize to lowercase.


**Face ID Failure:**
Ensure the image is well-lit and shows a clear face.
Check that biometricsEnabled is true in the Firestore users collection.


**Server Issues:**
Ensure the Node.js server is running on http://localhost:3000.
Verify the Firebase service account key is correctly placed.

Made by [@chaimaakn](https://github.com/chaimaakn) and [@meriemhcn](https://github.com/meriemhcn)
