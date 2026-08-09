import 'package:flutter/material.dart';
import '../../services/api/locations_api.dart';
import '../../services/api/user_api.dart';
import 'base_app_state.dart';

mixin LocationStateMixin on BaseAppState {
  Map<String, dynamic> _rawLocations = {"provinces": []};
  Map<String, dynamic> get rawLocations => _rawLocations;

  Map<String, dynamic> get cambodiaLocations {
    final lang = currentLanguage;
    final Map<String, dynamic> result = {};

    final provincesList = _rawLocations['provinces'] as List<dynamic>? ?? [];
    for (var p in provincesList) {
      final pNames = p['name'] as Map<String, dynamic>?;
      final String pName = pNames?[lang] ?? pNames?['en'] ?? '';
      if (pName.isEmpty) continue;

      final Map<String, dynamic> districtsMap = {};
      final districtsList = p['districts'] as List<dynamic>? ?? [];
      for (var d in districtsList) {
        final dNames = d['name'] as Map<String, dynamic>?;
        final String dName = dNames?[lang] ?? dNames?['en'] ?? '';
        if (dName.isEmpty) continue;

        final Map<String, dynamic> communesMap = {};
        final communesList = d['communes'] as List<dynamic>? ?? [];
        for (var c in communesList) {
          final cNames = c['name'] as Map<String, dynamic>?;
          final String cName = cNames?[lang] ?? cNames?['en'] ?? '';
          if (cName.isEmpty) continue;

          final List<String> villagesList = [];
          final vList = c['villages'] as List<dynamic>? ?? [];
          for (var v in vList) {
            final vNames = v['name'] as Map<String, dynamic>?;
            final String vName = vNames?[lang] ?? vNames?['en'] ?? '';
            if (vName.isNotEmpty) {
              villagesList.add(vName);
            }
          }
          communesMap[cName] = villagesList;
        }
        districtsMap[dName] = communesMap;
      }
      result[pName] = districtsMap;
    }

    return result;
  }

  // Get all provinces: Map of id -> localizedName
  Map<String, String> getProvincesMap() {
    final String lang = currentLanguage;
    final provinces = _rawLocations['provinces'] as List<dynamic>? ?? [];
    final Map<String, String> result = {};
    for (var p in provinces) {
      final String id = p['id']?.toString() ?? '';
      final names = p['name'] as Map<String, dynamic>?;
      final String name = names?[lang] ?? names?['en'] ?? '';
      if (id.isNotEmpty && name.isNotEmpty) {
        result[id] = name;
      }
    }
    return result;
  }

  // Get districts for a province: Map of id -> localizedName
  Map<String, String> getDistrictsMap(String provinceId) {
    final String lang = currentLanguage;
    final provinces = _rawLocations['provinces'] as List<dynamic>? ?? [];
    final Map<String, String> result = {};
    for (var p in provinces) {
      if (p['id']?.toString() == provinceId) {
        final districts = p['districts'] as List<dynamic>? ?? [];
        for (var d in districts) {
          final String id = d['id']?.toString() ?? '';
          final names = d['name'] as Map<String, dynamic>?;
          final String name = names?[lang] ?? names?['en'] ?? '';
          if (id.isNotEmpty && name.isNotEmpty) {
            result[id] = name;
          }
        }
        break;
      }
    }
    return result;
  }

  // Get communes for a district: Map of id -> localizedName
  Map<String, String> getCommunesMap(String districtId) {
    final String lang = currentLanguage;
    final provinces = _rawLocations['provinces'] as List<dynamic>? ?? [];
    final Map<String, String> result = {};
    for (var p in provinces) {
      final districts = p['districts'] as List<dynamic>? ?? [];
      for (var d in districts) {
        if (d['id']?.toString() == districtId) {
          final communes = d['communes'] as List<dynamic>? ?? [];
          for (var c in communes) {
            final String id = c['id']?.toString() ?? '';
            final names = c['name'] as Map<String, dynamic>?;
            final String name = names?[lang] ?? names?['en'] ?? '';
            if (id.isNotEmpty && name.isNotEmpty) {
              result[id] = name;
            }
          }
          break;
        }
      }
    }
    return result;
  }

  // Get villages for a commune: Map of id -> localizedName
  Map<String, String> getVillagesMap(String communeId) {
    final String lang = currentLanguage;
    final provinces = _rawLocations['provinces'] as List<dynamic>? ?? [];
    final Map<String, String> result = {};
    for (var p in provinces) {
      final districts = p['districts'] as List<dynamic>? ?? [];
      for (var d in districts) {
        final communes = d['communes'] as List<dynamic>? ?? [];
        for (var c in communes) {
          if (c['id']?.toString() == communeId) {
            final villages = c['villages'] as List<dynamic>? ?? [];
            for (var v in villages) {
              final String id = v['id']?.toString() ?? '';
              final names = v['name'] as Map<String, dynamic>?;
              final String name = names?[lang] ?? names?['en'] ?? '';
              if (id.isNotEmpty && name.isNotEmpty) {
                result[id] = name;
              }
            }
            break;
          }
        }
      }
    }
    return result;
  }

  Future<void> loadLocations() async {
    try {
      final data = await LocationsApi.fetchLocations();
      if (data.isNotEmpty) {
        _rawLocations = data;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load locations from API: $e');
    }
  }

  String translateLocation(dynamic value) {
    if (value == null) return '';
    final String valStr = value.toString().trim();
    if (valStr.isEmpty) return '';
    
    final lang = currentLanguage;
    final provincesList = _rawLocations['provinces'] as List<dynamic>? ?? [];
    
    // 1. Search in Provinces
    for (var p in provincesList) {
      final pNames = p['name'] as Map<String, dynamic>?;
      if (pNames != null) {
        if (pNames['en'] == valStr || pNames['kh'] == valStr || p['id'] == valStr) {
          return pNames[lang] ?? pNames['en'] ?? valStr;
        }
      }
      
      // 2. Search in Districts
      final districtsList = p['districts'] as List<dynamic>? ?? [];
      for (var d in districtsList) {
        final dNames = d['name'] as Map<String, dynamic>?;
        if (dNames != null) {
          if (dNames['en'] == valStr || dNames['kh'] == valStr || d['id'] == valStr) {
            return dNames[lang] ?? dNames['en'] ?? valStr;
          }
        }
        
        // 3. Search in Communes
        final communesList = d['communes'] as List<dynamic>? ?? [];
        for (var c in communesList) {
          final cNames = c['name'] as Map<String, dynamic>?;
          if (cNames != null) {
            if (cNames['en'] == valStr || cNames['kh'] == valStr || c['id'] == valStr) {
              return cNames[lang] ?? cNames['en'] ?? valStr;
            }
          }
          
          // 4. Search in Villages
          final villagesList = c['villages'] as List<dynamic>? ?? [];
          for (var v in villagesList) {
            final vNames = v['name'] as Map<String, dynamic>?;
            if (vNames != null) {
              if (vNames['en'] == valStr || vNames['kh'] == valStr || v['id'] == valStr) {
                return vNames[lang] ?? vNames['en'] ?? valStr;
              }
            }
          }
        }
      }
    }
    
    return valStr;
  }

  bool get isLocationComplete {
    if (userProfile == null) return false;
    final province = userProfile!['province']?.toString().trim() ?? '';
    final district = userProfile!['district']?.toString().trim() ?? '';
    final commune = userProfile!['commune']?.toString().trim() ?? '';
    final village = userProfile!['village']?.toString().trim() ?? '';
    return province.isNotEmpty && district.isNotEmpty && commune.isNotEmpty && village.isNotEmpty;
  }

  // --- Address Change Requests Queue (Admin) ---
  List<AddressChangeRequest> _addressRequests = [];
  List<AddressChangeRequest> get addressRequests => _addressRequests;

  bool hasPendingAddressRequest(String username) {
    return _addressRequests.any((r) => r.username == username && r.status == 'pending');
  }

  Future<void> refreshAddressRequests() async {
    if (token == null) return;
    try {
      final List<dynamic> list = await UserApi.fetchAddressRequests(token!);
      final List<AddressChangeRequest> loaded = [];
      for (var json in list) {
        final oldAddr = json['oldAddress'] as Map<String, dynamic>? ?? {};
        final newAddr = json['newAddress'] as Map<String, dynamic>? ?? {};
        loaded.add(AddressChangeRequest(
          id: json['id']?.toString() ?? '',
          username: json['username']?.toString() ?? '',
          role: json['role']?.toString() ?? 'farmer',
          oldAddress: {
            'province': oldAddr['province']?.toString() ?? '',
            'district': oldAddr['district']?.toString() ?? '',
            'commune': oldAddr['commune']?.toString() ?? '',
            'village': oldAddr['village']?.toString() ?? '',
            'street_address': oldAddr['street_address']?.toString() ?? '',
          },
          newAddress: {
            'province': newAddr['province']?.toString() ?? '',
            'district': newAddr['district']?.toString() ?? '',
            'commune': newAddr['commune']?.toString() ?? '',
            'village': newAddr['village']?.toString() ?? '',
            'street_address': newAddr['street_address']?.toString() ?? '',
          },
          status: (json['status']?.toString() ?? 'pending').toLowerCase(),
          timestamp: (json['timestamp'] ?? json['created_at'])?.toString() ?? '',
        ));
      }
      _addressRequests = loaded;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh address requests: $e');
    }
  }

  Future<String?> submitAddressRequest({
    required String province,
    required String district,
    required String commune,
    required String village,
    required String streetAddress,
  }) async {
    if (token == null) {
      final oldAddressMap = {
        'province': userProfile?['province']?.toString() ?? '',
        'district': userProfile?['district']?.toString() ?? '',
        'commune': userProfile?['commune']?.toString() ?? '',
        'village': userProfile?['village']?.toString() ?? '',
        'street_address': userProfile?['street_address']?.toString() ?? '',
      };

      final newRequest = AddressChangeRequest(
        id: 'addr_req_${DateTime.now().millisecondsSinceEpoch}',
        username: userName,
        role: currentRole,
        oldAddress: oldAddressMap,
        newAddress: {
          'province': province,
          'district': district,
          'commune': commune,
          'village': village,
          'street_address': streetAddress,
        },
        status: 'pending',
        timestamp: DateTime.now().toIso8601String(),
      );

      _addressRequests.add(newRequest);
      notifyListeners();
      return null;
    }

    try {
      await UserApi.submitAddressRequest(
        token!,
        province: province,
        district: district,
        commune: commune,
        village: village,
        streetAddress: streetAddress,
        role: currentRole,
      );
      await refreshAddressRequests();
      return null;
    } catch (e) {
      final errMsg = e.toString().replaceAll('Exception: ', '');
      debugPrint('Failed to submit address request: $errMsg');
      return errMsg;
    }
  }

  /// Returns null on success, or the raw backend error code on failure —
  /// same convention as `ProductStateMixin.deleteProduct`. Without a return
  /// value, the admin has no way to know an approval silently failed (e.g.
  /// the request was already resolved by someone else).
  Future<String?> approveAddressRequest(String requestId) async {
    if (token == null) {
      final idx = _addressRequests.indexWhere((r) => r.id == requestId);
      if (idx != -1) {
        _addressRequests[idx].status = 'approved';
        final req = _addressRequests[idx];

        if (userProfile != null && userProfile!['username'] == req.username) {
          userProfile!['province'] = req.newAddress['province']!;
          userProfile!['district'] = req.newAddress['district']!;
          userProfile!['commune'] = req.newAddress['commune']!;
          userProfile!['village'] = req.newAddress['village']!;
          userProfile!['street_address'] = req.newAddress['street_address']!;
        }
        addNotification('Address Update Approved', 'Your request to update address has been approved.');
        notifyListeners();
      }
      return null;
    }

    try {
      await UserApi.approveAddressRequest(token!, requestId);

      AddressChangeRequest? req;
      for (var r in _addressRequests) {
        if (r.id == requestId) {
          req = r;
          break;
        }
      }
      if (req != null && userProfile != null && userProfile!['username'] == req.username) {
        userProfile!['province'] = req.newAddress['province']!;
        userProfile!['district'] = req.newAddress['district']!;
        userProfile!['commune'] = req.newAddress['commune']!;
        userProfile!['village'] = req.newAddress['village']!;
        userProfile!['street_address'] = req.newAddress['street_address']!;
      }

      addNotification('Address Update Approved', 'Your request to update address has been approved.');
      await refreshAddressRequests();
      return null;
    } catch (e) {
      final errMsg = e.toString().replaceAll('Exception: ', '');
      debugPrint('Failed to approve address request: $errMsg');
      return errMsg;
    }
  }

  /// Returns null on success, or the raw backend error code on failure —
  /// see [approveAddressRequest].
  Future<String?> rejectAddressRequest(String requestId) async {
    if (token == null) {
      final idx = _addressRequests.indexWhere((r) => r.id == requestId);
      if (idx != -1) {
        _addressRequests[idx].status = 'rejected';
        addNotification('Address Update Rejected', 'Your request to update address was rejected.');
        notifyListeners();
      }
      return null;
    }

    try {
      await UserApi.rejectAddressRequest(token!, requestId);
      addNotification('Address Update Rejected', 'Your request to update address was rejected.');
      await refreshAddressRequests();
      return null;
    } catch (e) {
      final errMsg = e.toString().replaceAll('Exception: ', '');
      debugPrint('Failed to reject address request: $errMsg');
      return errMsg;
    }
  }
}
