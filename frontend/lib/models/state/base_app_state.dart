import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api/base_api.dart';
import '../../services/api/user_api.dart';
import '../../services/web_download.dart';
import '../../constants/translations.dart';

class MarketProduct {
  final String id;
  final String name;
  final String category;
  final double price; // per kg or unit
  final String unit;
  final String currency; // 'USD' or 'KHR'
  final double quantity; // in stock
  final String farmerName;
  final String location;
  final String description;
  final String imageUrl;
  final bool isVerifiedFarmer;
  final String? sellerId;

  MarketProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.unit,
    this.currency = 'USD',
    required this.quantity,
    required this.farmerName,
    required this.location,
    required this.description,
    required this.imageUrl,
    this.isVerifiedFarmer = false,
    this.sellerId,
  });

  String get formattedPrice {
    if (currency == 'KHR') {
      final String val = price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
      return '$val ៛';
    } else {
      return '\$${price.toStringAsFixed(2)}';
    }
  }

  String get resolvedImageUrl {
    if (imageUrl.isEmpty) {
      return 'https://images.unsplash.com/photo-1592982537447-7440770cbfc9?w=600';
    }
    if (imageUrl.startsWith('/')) {
      return '${BaseApi.baseUrl}$imageUrl';
    }
    return imageUrl;
  }
}

class BidOffer {
  final String id;
  final MarketProduct product;
  final String buyerName;
  double offeredPrice;
  double quantity;
  String status; // 'pending', 'accepted', 'counter_offered', 'rejected'
  List<String> chatMessages;

  BidOffer({
    required this.id,
    required this.product,
    required this.buyerName,
    required this.offeredPrice,
    required this.quantity,
    this.status = 'pending',
    required this.chatMessages,
  });
}

class FarmerVerification {
  final String id;
  final String name;
  final String farmName;
  final String location;
  final String cropTypes;
  final String docUrl;
  final String certType; // 'organic', 'gap', 'gi', 'general'
  String status; // 'pending', 'approved', 'rejected'

  FarmerVerification({
    required this.id,
    required this.name,
    required this.farmName,
    required this.location,
    required this.cropTypes,
    required this.docUrl,
    required this.certType,
    this.status = 'pending',
  });

  String get resolvedDocUrl {
    if (docUrl.isEmpty) {
      return '';
    }
    if (docUrl.startsWith('/')) {
      return '${BaseApi.baseUrl}$docUrl';
    }
    return docUrl;
  }
}

class AddressChangeRequest {
  final String id;
  final String username;
  final String role;
  final Map<String, String> oldAddress;
  final Map<String, String> newAddress;
  String status; // 'pending', 'approved', 'rejected'
  final String timestamp;

  AddressChangeRequest({
    required this.id,
    required this.username,
    required this.role,
    required this.oldAddress,
    required this.newAddress,
    this.status = 'pending',
    required this.timestamp,
  });

  AddressChangeRequest copyWith({String? status}) {
    return AddressChangeRequest(
      id: id,
      username: username,
      role: role,
      oldAddress: oldAddress,
      newAddress: newAddress,
      status: status ?? this.status,
      timestamp: timestamp,
    );
  }
}

class ForumPost {
  String id;
  final String author;
  final String role; // 'Farmer', 'Buyer', 'Expert'
  final String title;
  final String content;
  final String time;
  int likes;
  List<String> comments;

  ForumPost({
    required this.id,
    required this.author,
    required this.role,
    required this.title,
    required this.content,
    required this.time,
    this.likes = 0,
    required this.comments,
  });
}

class MarketPrice {
  final String name;
  final double currentPrice;
  final double changePercentage; // e.g. 2.5 means +2.5%, -1.2 means -1.2%
  final String trend; // 'up', 'down', 'stable'

  MarketPrice({
    required this.name,
    required this.currentPrice,
    required this.changePercentage,
    required this.trend,
  });
}

class BaseAppState extends ChangeNotifier {
  // App Languages: 'kh' (Khmer - default), 'en' (English)
  String _currentLanguage = 'kh';
  String get currentLanguage => _currentLanguage;

  void setLanguage(String lang) {
    _currentLanguage = lang;
    notifyListeners();
  }

  String translate(String key, {Map<String, String>? arguments}) {
    String text = Translations.values[_currentLanguage]?[key] ?? key;
    if (arguments != null) {
      arguments.forEach((k, v) {
        text = text.replaceAll('{$k}', v);
      });
    }
    return text;
  }

  bool hasTranslation(String key) {
    return Translations.values['en']?[key] != null || Translations.values['kh']?[key] != null;
  }

  // App Modes: 'buyer', 'farmer', 'admin'
  String _currentRole = 'buyer';
  String get currentRole => _currentRole;

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  String _userName = 'Guest User';
  String get userName => _userName;

  String? _token;
  String? get token => _token;

  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? get userProfile => _userProfile;

  String? _profileImagePath;
  String? get profileImagePath => _profileImagePath;

  Uint8List? _profileImageBytes;
  Uint8List? get profileImageBytes => _profileImageBytes;

  void updateProfileImage({String? path, Uint8List? bytes}) {
    _profileImagePath = path;
    _profileImageBytes = bytes;
    if (_userProfile != null) {
      _userProfile!['profile_image_path'] = path;
    }
    notifyListeners();
  }

  int _currentNavIndex = 0;
  int get currentNavIndex => _currentNavIndex;

  void setNavIndex(int index) {
    _currentNavIndex = index;
    notifyListeners();
  }

  void setRole(String role) {
    _currentRole = role;
    if (role == 'farmer' || role == 'association') {
      _userName = role == 'association' ? 'Sokha Association (Cooperative)' : 'Chan Sopheap (Farmer)';
    } else if (role == 'admin') {
      _userName = 'Sokha Ly (Admin)';
    } else {
      _userName = 'Kosal Pich (Buyer)';
    }
    notifyListeners();
  }

  Future<void> restoreSavedSession() async {
    try {
      String? savedToken;
      String? savedProfileStr;
      String? savedRole;

      if (kIsWeb) {
        savedToken = getWebStorage('auth_token');
        savedProfileStr = getWebStorage('user_profile_json');
        savedRole = getWebStorage('saved_role');
      }

      if (savedProfileStr == null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          savedToken ??= prefs.getString('auth_token');
          savedProfileStr ??= prefs.getString('user_profile_json');
          savedRole ??= prefs.getString('saved_role');
        } catch (_) {}
      }

      if (savedProfileStr != null) {
        final profile = jsonDecode(savedProfileStr) as Map<String, dynamic>;
        _token = savedToken;
        _userProfile = profile;
        _isLoggedIn = true;

        if (savedRole != null && savedRole.isNotEmpty) {
          _currentRole = savedRole;
        } else {
          final int roleId = profile['role_id'] ?? 6;
          if (roleId == 1) {
            _currentRole = 'admin';
          } else if (roleId == 3) {
            _currentRole = 'farmer';
          } else if (roleId == 2) {
            _currentRole = 'association';
          } else {
            _currentRole = 'buyer';
          }
        }
        _userName = profile['username'] ?? profile['email'] ?? 'User';

        loadBackendData();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error restoring saved session: $e');
    }
  }

  Future<void> _saveSessionToStorage() async {
    try {
      if (kIsWeb) {
        if (_token != null) saveWebStorage('auth_token', _token!);
        if (_userProfile != null) saveWebStorage('user_profile_json', jsonEncode(_userProfile));
        saveWebStorage('saved_role', _currentRole);
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_token != null) await prefs.setString('auth_token', _token!);
        if (_userProfile != null) await prefs.setString('user_profile_json', jsonEncode(_userProfile));
        await prefs.setString('saved_role', _currentRole);
      } catch (_) {}
    } catch (e) {
      debugPrint('Error saving session to storage: $e');
    }
  }

  Future<void> _clearSessionFromStorage() async {
    try {
      if (kIsWeb) {
        removeWebStorage('auth_token');
        removeWebStorage('user_profile_json');
        removeWebStorage('saved_role');
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('auth_token');
        await prefs.remove('user_profile_json');
        await prefs.remove('saved_role');
      } catch (_) {}
    } catch (e) {
      debugPrint('Error clearing session from storage: $e');
    }
  }

  void login(String identifier, String role) {
    _isLoggedIn = true;
    setRole(role);
    _userProfile = {
      'id': 'u_mock',
      'username': _userName,
      'email': '$role@phsarkasikor.com',
      'phoneNumber': '+85512223333',
      'role_id': role == 'admin' ? 1 : (role == 'association' ? 2 : (role == 'farmer' ? 3 : 6)),
      'province': 'Battambang',
      'district': 'Sangkae',
      'commune': 'Wat Ta Mim',
      'village': 'O Sralau',
      'street_address': 'Street 105',
    };
    _saveSessionToStorage();
  }

  Future<void> loadBackendData() async {
    // Overridden by child AppState class
  }

  Future<void> addNotification(String title, String body) async {
    // Overridden by NotificationStateMixin
  }

  void loginWithProfile(String token, Map<String, dynamic> profile) {
    _token = token;
    _userProfile = profile;
    _isLoggedIn = true;

    // Resolve role based on role_id
    final int roleId = profile['role_id'] ?? 6;
    String roleStr = 'buyer';
    if (roleId == 1) {
      roleStr = 'admin';
    } else if (roleId == 3) {
      roleStr = 'farmer';
    } else if (roleId == 5) {
      roleStr = 'technician';
    } else if (roleId == 2) {
      roleStr = 'association';
    }

    _currentRole = roleStr;
    _userName = profile['username'] ?? profile['email'] ?? 'User';

    _saveSessionToStorage();
    loadBackendData();
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    _currentRole = 'buyer';
    _userName = 'Guest User';
    _token = null;
    _userProfile = null;
    _clearSessionFromStorage();
    notifyListeners();
  }

  void updateProfileLocation({
    required String province,
    required String district,
    required String commune,
    required String village,
    required String streetAddress,
  }) {
    _userProfile ??= {};
    _userProfile!['province'] = province;
    _userProfile!['district'] = district;
    _userProfile!['commune'] = commune;
    _userProfile!['village'] = village;
    _userProfile!['street_address'] = streetAddress;
    notifyListeners();

    if (_token != null) {
      UserApi.updateProfileLocation(
        _token!,
        province: province,
        district: district,
        commune: commune,
        village: village,
        streetAddress: streetAddress,
      ).catchError((e) {
        debugPrint('Failed to save profile location on backend: $e');
        return <String, dynamic>{};
      });
    }
  }

  Future<void> updateProfileInfo({
    required String username,
    required String phoneNumber,
    required String email,
  }) async {
    _userProfile ??= {};
    _userProfile!['username'] = username;
    _userProfile!['phoneNumber'] = phoneNumber;
    _userProfile!['email'] = email;
    _userName = username;
    notifyListeners();

    if (_token != null) {
      await UserApi.updateProfileInfo(
        _token!,
        username: username,
        phoneNumber: phoneNumber,
        email: email,
      ).catchError((e) {
        debugPrint('Failed to save profile info on backend: $e');
        return <String, dynamic>{};
      });
    }
  }
}
