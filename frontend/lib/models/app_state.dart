import 'package:flutter/material.dart';
import '../services/api/base_api.dart';
import '../services/api/product_api.dart';
import '../services/api/contract_api.dart';
import '../services/api/notification_api.dart';
import '../services/api/market_price_api.dart';
import '../services/api/locations_api.dart';
import '../constants/translations.dart';

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

class ForumPost {
  final String id;
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

class AppState extends ChangeNotifier {
  AppState() {
    loadLocations();
    refreshProducts();
    refreshMarketPrices();
  }

  Map<String, dynamic> _rawLocations = {
    "provinces": [
      {
        "id": "phnom_penh",
        "name": {"en": "Phnom Penh", "kh": "ភ្នំពេញ"},
        "districts": [
          {
            "id": "chamkar_mon",
            "name": {"en": "Chamkar Mon", "kh": "ចំការមន"},
            "communes": [
              {
                "id": "tonle_bassac",
                "name": {"en": "Tonle Bassac", "kh": "ទន្លេបាសាក់"},
                "villages": [
                  {"id": "v3", "name": {"en": "Village 3", "kh": "ភូមិ ៣"}},
                  {"id": "v4", "name": {"en": "Village 4", "kh": "ភូមិ ៤"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "battambang",
        "name": {"en": "Battambang", "kh": "បាត់ដំបង"},
        "districts": [
          {
            "id": "sangkae",
            "name": {"en": "Sangkae", "kh": "សង្កែ"},
            "communes": [
              {
                "id": "wat_ta_mim",
                "name": {"en": "Wat Ta Mim", "kh": "វត្តតាមិម"},
                "villages": [
                  {"id": "o_sralau", "name": {"en": "O Sralau", "kh": "អូរស្រឡៅ"}},
                  {"id": "anlong_vil", "name": {"en": "Anlong Vil", "kh": "អន្លង់វិល"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "siem_reap",
        "name": {"en": "Siem Reap", "kh": "សៀមរាប"},
        "districts": [
          {
            "id": "krong_siem_reap",
            "name": {"en": "Krong Siem Reap", "kh": "ក្រុងសៀមរាប"},
            "communes": [
              {
                "id": "slor_kram",
                "name": {"en": "Slor Kram", "kh": "ស្លក្រាម"},
                "villages": [
                  {"id": "mondul_3", "name": {"en": "Mondul 3", "kh": "មណ្ឌល ៣"}},
                  {"id": "wat_bo", "name": {"en": "Wat Bo", "kh": "វត្តបូព៌"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "kampong_cham",
        "name": {"en": "Kampong Cham", "kh": "កំពង់ចាម"},
        "districts": [
          {
            "id": "krong_kampong_cham",
            "name": {"en": "Krong Kampong Cham", "kh": "ក្រុងកំពង់ចាម"},
            "communes": [
              {
                "id": "veal_vong",
                "name": {"en": "Veal Vong", "kh": "វាលវង់"},
                "villages": [
                  {"id": "v4", "name": {"en": "Village 4", "kh": "ភូមិ ៤"}},
                  {"id": "v5", "name": {"en": "Village 5", "kh": "ភូមិ ៥"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "kandal",
        "name": {"en": "Kandal", "kh": "កណ្តាល"},
        "districts": [
          {
            "id": "ta_khmau",
            "name": {"en": "Ta Khmau", "kh": "តាខ្មៅ"},
            "communes": [
              {
                "id": "ta_khmau_c",
                "name": {"en": "Ta Khmau", "kh": "តាខ្មៅ"},
                "villages": [
                  {"id": "prek_samraong", "name": {"en": "Prek Samraong", "kh": "ព្រែកសំរោង"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "banteay_meanchey",
        "name": {"en": "Banteay Meanchey", "kh": "បន្ទាយមានជ័យ"},
        "districts": [
          {
            "id": "serei_sohpon",
            "name": {"en": "Serei Sophorn", "kh": "សិរីសោភ័ណ"},
            "communes": [
              {
                "id": "preah_ponlea",
                "name": {"en": "Preah Ponlea", "kh": "ព្រះពន្លា"},
                "villages": [
                  {"id": "v1", "name": {"en": "Village 1", "kh": "ភូមិ ១"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "kampong_chhnang",
        "name": {"en": "Kampong Chhnang", "kh": "កំពង់ឆ្នាំង"},
        "districts": [
          {
            "id": "krong_kampong_chhnang",
            "name": {"en": "Krong Kampong Chhnang", "kh": "ក្រុងកំពង់ឆ្នាំង"},
            "communes": [
              {
                "id": "phsar_chhnang",
                "name": {"en": "Phsar Chhnang", "kh": "ផ្សារឆ្នាំង"},
                "villages": [
                  {"id": "v1", "name": {"en": "Village 1", "kh": "ភូមិ ១"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "kampong_speu",
        "name": {"en": "Kampong Speu", "kh": "កំពង់ស្ពឺ"},
        "districts": [
          {
            "id": "chbar_mon",
            "name": {"en": "Chbar Mon", "kh": "ច្បារមន"},
            "communes": [
              {
                "id": "rokar_thmei",
                "name": {"en": "Rokar Thmei", "kh": "រកាធំ"},
                "villages": [
                  {"id": "v1", "name": {"en": "Village 1", "kh": "ភូមិ ១"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "kampong_thom",
        "name": {"en": "Kampong Thom", "kh": "កំពង់ធំ"},
        "districts": [
          {
            "id": "stueng_sen",
            "name": {"en": "Stueng Sen", "kh": "ស្ទឹងសែន"},
            "communes": [
              {
                "id": "damrei_choan_khla",
                "name": {"en": "Damrei Choan Khla", "kh": "ដំរីជាន់ខ្លា"},
                "villages": [
                  {"id": "v1", "name": {"en": "Village 1", "kh": "ភូមិ ១"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "kampot",
        "name": {"en": "Kampot", "kh": "កំពត"},
        "districts": [
          {
            "id": "krong_kampot",
            "name": {"en": "Krong Kampot", "kh": "ក្រុងកំពត"},
            "communes": [
              {
                "id": "kampong_bay",
                "name": {"en": "Kampong Bay", "kh": "កំពង់បាយ"},
                "villages": [
                  {"id": "v1", "name": {"en": "Village 1", "kh": "ភូមិ ១"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "kep",
        "name": {"en": "Kep", "kh": "កែប"},
        "districts": [
          {
            "id": "krong_kep",
            "name": {"en": "Krong Kep", "kh": "ក្រុងកែប"},
            "communes": [
              {
                "id": "kep_c",
                "name": {"en": "Kep", "kh": "កែប"},
                "villages": [
                  {"id": "v1", "name": {"en": "Village 1", "kh": "ភូមិ ១"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "koh_kong",
        "name": {"en": "Koh Kong", "kh": "កោះកុង"},
        "districts": [
          {
            "id": "khemara_phoumin",
            "name": {"en": "Khemarak Phoumin", "kh": "ខេមរភូមិន្ទ"},
            "communes": [
              {
                "id": "smach_mean_chey",
                "name": {"en": "Smach Mean Chey", "kh": "ស្មាច់មានជ័យ"},
                "villages": [
                  {"id": "v1", "name": {"en": "Village 1", "kh": "ភូមិ ១"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "kratie",
        "name": {"en": "Kratie", "kh": "ក្រចេះ"},
        "districts": [
          {
            "id": "krong_kratie",
            "name": {"en": "Krong Kratie", "kh": "ក្រុងក្រចេះ"},
            "communes": [
              {
                "id": "kratie_c",
                "name": {"en": "Kratie", "kh": "ក្រចេះ"},
                "villages": [
                  {"id": "v1", "name": {"en": "Village 1", "kh": "ភូមិ ១"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "mondulkiri",
        "name": {"en": "Mondulkiri", "kh": "មណ្ឌលគីរី"},
        "districts": [
          {
            "id": "sen_monorom",
            "name": {"en": "Sen Monorom", "kh": "សែនមនោរម្យ"},
            "communes": [
              {
                "id": "spaan_mean_chey",
                "name": {"en": "Spaan Mean Chey", "kh": "ស្ពានមានជ័យ"},
                "villages": [
                  {"id": "v1", "name": {"en": "Village 1", "kh": "ភូមិ ១"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "otdar_meanchey",
        "name": {"en": "Otdar Meanchey", "kh": "ឧត្តរមានជ័យ"},
        "districts": [
          {
            "id": "samraong",
            "name": {"en": "Samraong", "kh": "សំរោង"},
            "communes": [
              {
                "id": "samraong_c",
                "name": {"en": "Samraong", "kh": "សំរោង"},
                "villages": [
                  {"id": "v1", "name": {"en": "Village 1", "kh": "ភូមិ ១"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "pailin",
        "name": {"en": "Pailin", "kh": "ប៉ៃលិន"},
        "districts": [
          {
            "id": "krong_pailin",
            "name": {"en": "Krong Pailin", "kh": "ក្រុងប៉ៃលិន"},
            "communes": [
              {
                "id": "pailin_c",
                "name": {"en": "Pailin", "kh": "ប៉ៃលិន"},
                "villages": [
                  {"id": "v1", "name": {"en": "Village 1", "kh": "ភូមិ ១"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "preah_sihanouk",
        "name": {"en": "Preah Sihanouk", "kh": "ព្រះសីហនុ"},
        "districts": [
          {
            "id": "krong_preah_sihanouk",
            "name": {"en": "Krong Preah Sihanouk", "kh": "ក្រុងព្រះសីហនុ"},
            "communes": [
              {
                "id": "commune_1",
                "name": {"en": "Commune 1", "kh": "សង្កាត់លេខ១"},
                "villages": [
                  {"id": "v1", "name": {"en": "Village 1", "kh": "ភូមិ ១"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "preah_vihear",
        "name": {"en": "Preah Vihear", "kh": "ព្រះវិហារ"},
        "districts": [
          {
            "id": "tbeng_mean_chey",
            "name": {"en": "Tbeng Meanchey", "kh": "ត្បែងមានជ័យ"},
            "communes": [
              {
                "id": "kampoul_roak",
                "name": {"en": "Kampoul Roak", "kh": "កំពូលរ៉ក់"},
                "villages": [
                  {"id": "v1", "name": {"en": "Village 1", "kh": "ភូមិ ១"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "prey_veng",
        "name": {"en": "Prey Veng", "kh": "ព្រៃវែង"},
        "districts": [
          {
            "id": "krong_prey_veng",
            "name": {"en": "Krong Prey Veng", "kh": "ក្រុងព្រៃវែង"},
            "communes": [
              {
                "id": "kampong_leav",
                "name": {"en": "Kampong Leav", "kh": "កំពង់លាវ"},
                "villages": [
                  {"id": "v1", "name": {"en": "Village 1", "kh": "ភូមិ ១"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "pursat",
        "name": {"en": "Pursat", "kh": "ពោធិ៍សាត់"},
        "districts": [
          {
            "id": "krong_pursat",
            "name": {"en": "Krong Pursat", "kh": "ក្រុងពោធិ៍សាត់"},
            "communes": [
              {
                "id": "roleap",
                "name": {"en": "Roleap", "kh": "រលាប"},
                "villages": [
                  {"id": "v1", "name": {"en": "Village 1", "kh": "ភូមិ ១"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "ratanakiri",
        "name": {"en": "Ratanakiri", "kh": "រតនគីរី"},
        "districts": [
          {
            "id": "banlung",
            "name": {"en": "Banlung", "kh": "បានលុង"},
            "communes": [
              {
                "id": "labansiek",
                "name": {"en": "Labansiek", "kh": "ឡាបានសៀក"},
                "villages": [
                  {"id": "v1", "name": {"en": "Village 1", "kh": "ភូមិ ១"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "stung_treng",
        "name": {"en": "Stung Treng", "kh": "ស្ទឹងត្រែង"},
        "districts": [
          {
            "id": "krong_stung_treng",
            "name": {"en": "Krong Stung Treng", "kh": "ក្រុងស្ទឹងត្រែង"},
            "communes": [
              {
                "id": "stung_treng_c",
                "name": {"en": "Stung Treng", "kh": "ស្ទឹងត្រែង"},
                "villages": [
                  {"id": "v1", "name": {"en": "Village 1", "kh": "ភូមិ ១"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "svay_rieng",
        "name": {"en": "Svay Rieng", "kh": "ស្វាយរៀង"},
        "districts": [
          {
            "id": "krong_svay_rieng",
            "name": {"en": "Krong Svay Rieng", "kh": "ក្រុងស្វាយរៀង"},
            "communes": [
              {
                "id": "svay_rieng_c",
                "name": {"en": "Svay Rieng", "kh": "ស្វាយរៀង"},
                "villages": [
                  {"id": "v1", "name": {"en": "Village 1", "kh": "ភូមិ ១"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "takeo",
        "name": {"en": "Takeo", "kh": "តាកែវ"},
        "districts": [
          {
            "id": "doun_kaev",
            "name": {"en": "Doun Kaev", "kh": "ដូនកែវ"},
            "communes": [
              {
                "id": "rokar_knong",
                "name": {"en": "Rokar Knong", "kh": "រកាក្នុង"},
                "villages": [
                  {"id": "v1", "name": {"en": "Village 1", "kh": "ភូមិ ១"}}
                ]
              }
            ]
          }
        ]
      },
      {
        "id": "tboung_khmum",
        "name": {"en": "Tboung Khmum", "kh": "ត្បូងឃ្មុំ"},
        "districts": [
          {
            "id": "suong",
            "name": {"en": "Suong", "kh": "សួង"},
            "communes": [
              {
                "id": "suong_c",
                "name": {"en": "Suong", "kh": "សួង"},
                "villages": [
                  {"id": "v1", "name": {"en": "Village 1", "kh": "ភូមិ ១"}}
                ]
              }
            ]
          }
        ]
      }
    ]
  };

  Map<String, dynamic> get cambodiaLocations {
    final lang = _currentLanguage;
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

  int _currentNavIndex = 0;
  int get currentNavIndex => _currentNavIndex;

  void setNavIndex(int index) {
    _currentNavIndex = index;
    notifyListeners();
  }

  String translateLocation(dynamic value) {
    if (value == null) return '';
    final String valStr = value.toString().trim();
    if (valStr.isEmpty) return '';
    
    final lang = _currentLanguage;
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
    if (_userProfile == null) return false;
    final province = _userProfile!['province']?.toString().trim() ?? '';
    final district = _userProfile!['district']?.toString().trim() ?? '';
    final commune = _userProfile!['commune']?.toString().trim() ?? '';
    final village = _userProfile!['village']?.toString().trim() ?? '';
    return province.isNotEmpty && district.isNotEmpty && commune.isNotEmpty && village.isNotEmpty;
  }

  void updateProfileLocation({
    required String province,
    required String district,
    required String commune,
    required String village,
    required String streetAddress,
  }) {
    if (_userProfile == null) {
      _userProfile = {};
    }
    _userProfile!['province'] = province;
    _userProfile!['district'] = district;
    _userProfile!['commune'] = commune;
    _userProfile!['village'] = village;
    _userProfile!['street_address'] = streetAddress;
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
    addNotification(
      translate('welcome_back_notif', arguments: {'name': _userName}),
      translate('login_sub_notif', arguments: {'role': role}),
    );
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

    addNotification(
      translate('welcome_back_notif', arguments: {'name': _userName}),
      translate('login_sub_notif', arguments: {'role': _currentRole}),
    );
    loadBackendData();
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    _currentRole = 'buyer';
    _userName = 'Guest User';
    _token = null;
    _userProfile = null;
    notifyListeners();
  }

  // --- Search and Filtering ---
  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  String _selectedCategory = 'All';
  String get selectedCategory => _selectedCategory;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  String _mapUnitToBackend(String unit) {
    switch (unit.toLowerCase()) {
      case 'kg':
        return 'KG';
      case 'bag':
        return 'SACK';
      case 'ton':
        return 'TON';
      case 'hand':
        return 'BUNCH';
      default:
        return 'KG';
    }
  }

  String _mapUnitToFrontend(String? unitType) {
    if (unitType == null) return 'kg';
    switch (unitType.toUpperCase()) {
      case 'KG':
        return 'kg';
      case 'SACK':
        return 'bag';
      case 'TON':
        return 'ton';
      case 'BUNCH':
        return 'hand';
      default:
        return 'kg';
    }
  }

  Future<void> refreshProducts() async {
    try {
      final List<dynamic> backendProds = await ProductApi.fetchProducts();
      final List<MarketProduct> loaded = [];
      for (var json in backendProds) {
        loaded.add(MarketProduct(
          id: json['id'] ?? '',
          name: json['product_name'] ?? '',
          category: json['category'] ?? 'Grains',
          price: (json['price_per_unit'] as num?)?.toDouble() ?? 0.0,
          unit: _mapUnitToFrontend(json['unit_type']),
          currency: json['currency'] ?? 'USD',
          quantity: (json['quantity_available'] as num?)?.toDouble() ?? 0.0,
          farmerName: json['seller_name'] ?? json['seller_username'] ?? 'Farmer',
          location: json['seller_province'] ?? 'Cambodia',
          description: json['quality_certification_metadata'] ?? 'No description.',
          imageUrl: json['image_url'] ?? 'https://images.unsplash.com/photo-1592982537447-7440770cbfc9?w=600',
          isVerifiedFarmer: true,
          sellerId: json['seller_id'],
        ));
      }
      _products.clear();
      _products.addAll(loaded);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh products: $e');
    }
  }

  Future<void> refreshNotifications() async {
    if (_token == null) return;
    try {
      final List<dynamic> backendNotifs = await NotificationApi.fetchNotifications(_token!);
      _notifications.clear();
      for (var json in backendNotifs) {
        _notifications.add({
          'id': json['id'] ?? '',
          'title': json['title'] ?? '',
          'body': json['message'] ?? '',
          'time': json['sent_at'] != null ? json['sent_at'].toString().split('T')[0] : 'Just now',
          'isRead': json['is_read'] ?? false,
        });
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh notifications: $e');
    }
  }

  Future<void> refreshContracts() async {
    if (_token == null) return;
    try {
      final List<dynamic> backendContracts = await ContractApi.fetchContracts(_token!);
      final List<BidOffer> loaded = [];
      for (var json in backendContracts) {
        final List<dynamic> items = json['items'] ?? [];
        if (items.isEmpty) continue;
        final item = items[0];
        final String prodId = item['product_id'] ?? '';
        
        MarketProduct prod = _products.firstWhere(
          (p) => p.id == prodId,
          orElse: () => MarketProduct(
            id: prodId,
            name: 'Crop Product',
            category: 'Grains',
            price: (item['agreed_price'] as num?)?.toDouble() ?? 0.0,
            unit: _mapUnitToFrontend(item['unit_type']),
            currency: 'USD',
            quantity: (item['agreed_quantity'] as num?)?.toDouble() ?? 0.0,
            farmerName: 'Farmer',
            location: 'Cambodia',
            description: '',
            imageUrl: 'https://images.unsplash.com/photo-1592982537447-7440770cbfc9?w=600',
          ),
        );
        
        String uiStatus = 'pending';
        if (json['contract_status'] == 'ACTIVE') {
          uiStatus = 'accepted';
        } else if (json['contract_status'] == 'TERMINATED') {
          uiStatus = 'rejected';
        }
        
        loaded.add(BidOffer(
          id: json['id'] ?? '',
          product: prod,
          buyerName: json['buyer_name'] ?? 'Buyer',
          offeredPrice: (item['agreed_price'] as num?)?.toDouble() ?? 0.0,
          quantity: (item['agreed_quantity'] as num?)?.toDouble() ?? 0.0,
          status: uiStatus,
          chatMessages: ['System: Negotiation started.'],
        ));
      }
      _negotiations.clear();
      _negotiations.addAll(loaded);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh contracts: $e');
    }
  }

  Future<void> refreshMarketPrices() async {
    try {
      final List<dynamic> backendPrices = await MarketPriceApi.fetchMarketPrices();
      final List<MarketPrice> loaded = [];
      for (var json in backendPrices) {
        final double avg = (json['average_market_price'] as num?)?.toDouble() ?? 0.0;
        final double low = (json['lowest_price'] as num?)?.toDouble() ?? avg * 0.95;
        final double high = (json['highest_price'] as num?)?.toDouble() ?? avg * 1.05;
        
        String trend = 'stable';
        double change = 0.0;
        if (high > avg) {
          trend = 'up';
          change = ((high - avg) / avg) * 100;
        } else if (low < avg) {
          trend = 'down';
          change = ((low - avg) / avg) * 100;
        }
        
        loaded.add(MarketPrice(
          name: json['commodity_name'] ?? 'Crop',
          currentPrice: avg,
          changePercentage: double.parse(change.toStringAsFixed(1)),
          trend: trend,
        ));
      }
      _marketPrices.clear();
      _marketPrices.addAll(loaded);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to refresh market prices: $e');
    }
  }

  Future<void> loadBackendData() async {
    await refreshProducts();
    await refreshNotifications();
    await refreshContracts();
    await refreshMarketPrices();
  }

  // --- Notifications ---
  final List<Map<String, dynamic>> _notifications = [];
  List<Map<String, dynamic>> get notifications => _notifications;

  void addNotification(String title, String body) {
    _notifications.insert(0, {
      'id': DateTime.now().toString(),
      'title': title,
      'body': body,
      'time': 'Just now',
      'isRead': false,
    });
    notifyListeners();
  }

  void markAllNotificationsRead() {
    for (var n in _notifications) {
      n['isRead'] = true;
      if (_token != null) {
        try {
          NotificationApi.markNotificationAsRead(_token!, n['id']);
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  // --- Marketplace Products ---
  final List<MarketProduct> _products = [];
  List<MarketProduct> get products => _products;

  List<MarketProduct> get filteredProducts {
    return _products.where((p) {
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                            p.farmerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            p.location.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || p.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> addProduct(MarketProduct product) async {
    if (_token == null) {
      _products.insert(0, product);
      notifyListeners();
      return;
    }
    try {
      await ProductApi.createProduct(_token!, {
        'product_name': product.name,
        'category_id': 'c8a24b17-3bf7-42f4-8a4a-9ef8540dc6cf',
        'price_per_unit': product.price,
        'unit_type': _mapUnitToBackend(product.unit),
        'currency': product.currency,
        'quantity_available': product.quantity,
        'harvest_date': DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T')[0],
        'quality_certification_metadata': product.description,
        'image_url': product.imageUrl,
      });
      await refreshProducts();
    } catch (e) {
      debugPrint('Failed to create product: $e');
    }
  }

  Future<void> updateProduct(String productId, MarketProduct product) async {
    if (_token == null) {
      final index = _products.indexWhere((p) => p.id == productId);
      if (index != -1) {
        _products[index] = product;
        notifyListeners();
      }
      return;
    }
    try {
      await ProductApi.updateProduct(_token!, productId, {
        'product_name': product.name,
        'category_id': 'c8a24b17-3bf7-42f4-8a4a-9ef8540dc6cf',
        'price_per_unit': product.price,
        'unit_type': _mapUnitToBackend(product.unit),
        'currency': product.currency,
        'quantity_available': product.quantity,
        'harvest_date': DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T')[0],
        'quality_certification_metadata': product.description,
        'image_url': product.imageUrl,
      });
      await refreshProducts();
    } catch (e) {
      debugPrint('Failed to update product: $e');
    }
  }

  // --- Negotiations (Bids) ---
  final List<BidOffer> _negotiations = [];
  List<BidOffer> get negotiations => _negotiations;

  void _placeBidMock(MarketProduct product, double price, double qty) {
    final existingIndex = _negotiations.indexWhere((n) => n.product.id == product.id && n.buyerName == 'Kosal Pich');
    if (existingIndex != -1) {
      _negotiations[existingIndex].offeredPrice = price;
      _negotiations[existingIndex].quantity = qty;
      _negotiations[existingIndex].status = 'pending';
      _negotiations[existingIndex].chatMessages.add('Buyer: Offered \$$price / $qty units');
    } else {
      _negotiations.add(
        BidOffer(
          id: 'b_${DateTime.now().millisecondsSinceEpoch}',
          product: product,
          buyerName: 'Kosal Pich',
          offeredPrice: price,
          quantity: qty,
          chatMessages: [
            'System: Negotiation started.',
            'Buyer: I would like to offer \$$price per ${product.unit} for $qty ${product.unit}s.'
          ],
        ),
      );
    }
    addNotification('Bid Placed', 'You offered \$$price/$qty for ${product.name}.');
    notifyListeners();
  }

  Future<void> placeBid(MarketProduct product, double price, double qty) async {
    if (_token == null) {
      _placeBidMock(product, price, qty);
      return;
    }
    try {
      await ContractApi.createContract(_token!, {
        'seller_id': product.sellerId ?? 'c8a24b17-3bf7-42f4-8a4a-9ef8540dc6cf',
        'buyer_id': _userProfile?['id'] ?? '',
        'terms_description': 'Negotiation for ${product.name}',
        'start_date': DateTime.now().add(const Duration(days: 1)).toUtc().toIso8601String(),
        'end_date': DateTime.now().add(const Duration(days: 30)).toUtc().toIso8601String(),
        'contract_status': 'DRAFT',
        'items': [
          {
            'product_id': product.id,
            'agreed_price': price,
            'agreed_quantity': qty,
            'unit_type': _mapUnitToBackend(product.unit),
          }
        ]
      });
      await refreshContracts();
      addNotification('Bid Placed', 'You offered \$$price/$qty for ${product.name}.');
    } catch (e) {
      debugPrint('Failed to place bid: $e');
    }
  }

  void _counterOfferMock(String bidId, double newPrice) {
    final index = _negotiations.indexWhere((n) => n.id == bidId);
    if (index != -1) {
      _negotiations[index].offeredPrice = newPrice;
      _negotiations[index].status = 'counter_offered';
      _negotiations[index].chatMessages.add('Farmer: Counter-offered at \$$newPrice');
      notifyListeners();
    }
  }

  Future<void> counterOffer(String bidId, double newPrice) async {
    if (_token == null) {
      _counterOfferMock(bidId, newPrice);
      return;
    }
    try {
      final bid = _negotiations.firstWhere((n) => n.id == bidId);
      await ContractApi.updateContract(_token!, bidId, {
        'items': [
          {
            'product_id': bid.product.id,
            'agreed_price': newPrice,
            'agreed_quantity': bid.quantity,
            'unit_type': _mapUnitToBackend(bid.product.unit),
          }
        ]
      });
      await refreshContracts();
    } catch (e) {
      debugPrint('Failed to submit counter offer: $e');
    }
  }

  void _acceptBidMock(String bidId) {
    final index = _negotiations.indexWhere((n) => n.id == bidId);
    if (index != -1) {
      _negotiations[index].status = 'accepted';
      _negotiations[index].chatMessages.add('System: Bid accepted by Farmer!');
      addNotification('Bid Accepted!', 'Your bid on ${_negotiations[index].product.name} was accepted!');
      notifyListeners();
    }
  }

  Future<void> acceptBid(String bidId) async {
    if (_token == null) {
      _acceptBidMock(bidId);
      return;
    }
    try {
      await ContractApi.updateContract(_token!, bidId, {
        'contract_status': 'ACTIVE',
      });
      await refreshContracts();
    } catch (e) {
      debugPrint('Failed to accept bid: $e');
    }
  }

  void _rejectBidMock(String bidId) {
    final index = _negotiations.indexWhere((n) => n.id == bidId);
    if (index != -1) {
      _negotiations[index].status = 'rejected';
      _negotiations[index].chatMessages.add('System: Offer declined.');
      notifyListeners();
    }
  }

  Future<void> rejectBid(String bidId) async {
    if (_token == null) {
      _rejectBidMock(bidId);
      return;
    }
    try {
      await ContractApi.updateContract(_token!, bidId, {
        'contract_status': 'TERMINATED',
      });
      await refreshContracts();
    } catch (e) {
      debugPrint('Failed to reject bid: $e');
    }
  }

  // --- Farmer Verification Queue (Admin) ---
  final List<FarmerVerification> _verifications = [
    FarmerVerification(
      id: 'v_1',
      name: 'Keo Sarath',
      farmName: 'Battambang Rice Farms',
      location: 'Battambang',
      cropTypes: 'Jasmine Rice, Brown Rice',
      docUrl: 'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?q=80&w=600',
      certType: 'organic',
      status: 'pending',
    ),
    FarmerVerification(
      id: 'v_2',
      name: 'Nguon Srey',
      farmName: 'Srey Mango Plantation',
      location: 'Kampong Cham',
      cropTypes: 'Keo Romeat Mango',
      docUrl: 'https://images.unsplash.com/photo-1601597111158-2fceff270190?q=80&w=600',
      certType: 'gap',
      status: 'pending',
    ),
  ];
  List<FarmerVerification> get verifications => _verifications;

  String getFarmerCertType(String farmerName) {
    final cleanName = farmerName.replaceAll(RegExp(r'\s*\(Farmer\)\s*'), '').trim().toLowerCase();
    for (var v in _verifications) {
      final cleanVName = v.name.replaceAll(RegExp(r'\s*\(Farmer\)\s*'), '').trim().toLowerCase();
      final cleanVFarm = v.farmName.toLowerCase();
      if ((cleanVName == cleanName || cleanVFarm == cleanName || cleanVName.contains(cleanName)) && v.status == 'approved') {
        return v.certType;
      }
    }
    // Fallback: Chan Sopheap is organic certified
    if (cleanName == 'chan sopheap' || cleanName == 'chan sopheap (farmer)') {
      return 'organic';
    }
    return 'none';
  }

  void addVerification(FarmerVerification verification) {
    _verifications.add(verification);
    notifyListeners();
  }

  void approveFarmer(String verificationId) {
    final idx = _verifications.indexWhere((v) => v.id == verificationId);
    if (idx != -1) {
      _verifications[idx].status = 'approved';
      final name = _verifications[idx].name;
      addNotification('Farmer Verified', '$name\'s farm has been approved.');
      notifyListeners();
    }
  }

  void rejectFarmer(String verificationId) {
    final idx = _verifications.indexWhere((v) => v.id == verificationId);
    if (idx != -1) {
      _verifications[idx].status = 'rejected';
      notifyListeners();
    }
  }

  // --- Forum Posts (Community) ---
  final List<ForumPost> _forumPosts = [];
  List<ForumPost> get forumPosts => _forumPosts;

  void likePost(String id) {
    final idx = _forumPosts.indexWhere((fp) => fp.id == id);
    if (idx != -1) {
      _forumPosts[idx].likes++;
      notifyListeners();
    }
  }

  void addComment(String postId, String commentText) {
    final idx = _forumPosts.indexWhere((fp) => fp.id == postId);
    if (idx != -1) {
      _forumPosts[idx].comments.add('$userName: $commentText');
      notifyListeners();
    }
  }

  void createPost(String title, String content) {
    _forumPosts.insert(
      0,
      ForumPost(
        id: 'fp_${DateTime.now().millisecondsSinceEpoch}',
        author: userName,
        role: _currentRole == 'farmer' ? 'Farmer' : (_currentRole == 'admin' ? 'Expert' : 'Buyer'),
        title: title,
        content: content,
        time: 'Just now',
        comments: [],
      ),
    );
    notifyListeners();
  }

  // --- Live Commodity Prices ---
  final List<MarketPrice> _marketPrices = [];
  List<MarketPrice> get marketPrices => _marketPrices;
}
