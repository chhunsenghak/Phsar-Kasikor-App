import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config_service.dart';

class AuthApi {
  static String get baseUrl {
    final String configuredUrl = ConfigService.get('API_URL', defaultValue: 'http://localhost:8000');
    if (kIsWeb) {
      return configuredUrl;
    }
    try {
      if (Platform.isAndroid) {
        return configuredUrl.replaceAll('localhost', '10.0.2.2').replaceAll('127.0.0.1', '10.0.2.2');
      }
    } catch (_) {}
    return configuredUrl;
  }

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: ConfigService.get('GOOGLE_WEB_CLIENT_ID'),
  );
  static final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  /// Perform standard login via Username/Phone & Password
  static Future<Map<String, dynamic>> login(String identifier, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/login'),
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'username': identifier,
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      try {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Login failed');
      } catch (_) {
        throw Exception('Server communication error');
      }
    }
  }

  /// Perform registration of a new user
  static Future<Map<String, dynamic>> register({
    required String name,
    required String phone,
    required String password,
    required int roleId,
    String? email,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/users/register'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'username': name,
        'phoneNumber': phone,
        'password': password,
        'role_id': roleId,
        'email': (email == null || email.isEmpty) ? null : email,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      try {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Registration failed');
      } catch (_) {
        throw Exception('Server communication error');
      }
    }
  }

  /// Perform Google sign-in and authenticate with the FastAPI backend
  static Future<Map<String, dynamic>> signInWithGoogle() async {
    User? firebaseUser;

    if (kIsWeb) {
      // On Web, use Firebase's native popup sign-in flow
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      final UserCredential userCredential = await _firebaseAuth.signInWithPopup(googleProvider);
      firebaseUser = userCredential.user;
    } else {
      // On Mobile (Android/iOS), use GoogleSignIn SDK flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception('Google Sign-In was cancelled by the user');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      firebaseUser = userCredential.user;
    }

    if (firebaseUser == null) {
      throw Exception('Firebase authentication failed');
    }

    // 4. Retrieve the Firebase ID Token (JWT)
    final String? idToken = await firebaseUser.getIdToken();
    if (idToken == null) {
      throw Exception('Could not retrieve Firebase ID Token');
    }

    // 5. Send ID Token to FastAPI backend to login/register and get application token
    final response = await http.post(
      Uri.parse('$baseUrl/api/v1/auth/google-login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'id_token': idToken,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      try {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['detail'] ?? 'Backend Google login failed');
      } catch (_) {
        throw Exception('Server communication error');
      }
    }
  }

  /// Retrieve current user profile details using the JWT access token
  static Future<Map<String, dynamic>> fetchUserProfile(String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/v1/users/me'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch user profile');
    }
  }
}
