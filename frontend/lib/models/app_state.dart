import 'package:flutter/material.dart';

class MarketProduct {
  final String id;
  final String name;
  final String category;
  final double price; // per kg or unit
  final String unit;
  final double quantity; // in stock
  final String farmerName;
  final String location;
  final String description;
  final String imageUrl;
  final bool isVerifiedFarmer;

  MarketProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.unit,
    required this.quantity,
    required this.farmerName,
    required this.location,
    required this.description,
    required this.imageUrl,
    this.isVerifiedFarmer = false,
  });
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
  String status; // 'pending', 'approved', 'rejected'

  FarmerVerification({
    required this.id,
    required this.name,
    required this.farmName,
    required this.location,
    required this.cropTypes,
    required this.docUrl,
    this.status = 'pending',
  });
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
  // App Modes: 'buyer', 'farmer', 'admin'
  String _currentRole = 'buyer';
  String get currentRole => _currentRole;

  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  String _userName = 'Guest User';
  String get userName => _userName;

  void setRole(String role) {
    _currentRole = role;
    if (role == 'farmer') {
      _userName = 'Chan Sopheap (Farmer)';
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
    addNotification('Welcome back, $_userName!', 'You are logged in under the $role dashboard.');
  }

  void logout() {
    _isLoggedIn = false;
    _currentRole = 'buyer';
    _userName = 'Guest User';
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

  // --- Mock Notifications ---
  final List<Map<String, dynamic>> _notifications = [
    {
      'id': '1',
      'title': 'New Bid Received',
      'body': 'Kosal Pich placed a bid of \$1.10/kg on Jasmine Rice.',
      'time': '5 mins ago',
      'isRead': false
    },
    {
      'id': '2',
      'title': 'Price Alert',
      'body': 'Jasmine Rice prices went up by 3.5% today.',
      'time': '2 hours ago',
      'isRead': false
    },
    {
      'id': '3',
      'title': 'Verification Status',
      'body': 'Your farm document verification is currently under review by Admin.',
      'time': '1 day ago',
      'isRead': true
    }
  ];
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
    }
    notifyListeners();
  }

  // --- Mock Marketplace Products ---
  final List<MarketProduct> _products = [
    MarketProduct(
      id: 'p1',
      name: 'Organic Jasmine Rice',
      category: 'Grains',
      price: 1.20,
      unit: 'kg',
      quantity: 500,
      farmerName: 'Chan Sopheap',
      location: 'Battambang',
      description: 'Premium quality organic Jasmine Rice, direct from the heart of Battambang. Chemical-free cultivation with high nutrition value and fragrant smell.',
      imageUrl: 'https://lh3.googleusercontent.com/d/1Xl0yC88w2j8kP14e9H3vL3U5iW_cQG8S=s400',
      isVerifiedFarmer: true,
    ),
    MarketProduct(
      id: 'p2',
      name: 'Sweet Honey Mangoes',
      category: 'Fruits',
      price: 0.90,
      unit: 'kg',
      quantity: 250,
      farmerName: 'Sokha Kiri',
      location: 'Kampong Speu',
      description: 'Sweet Keo Romeat Mangoes. Freshly harvested from Kampong Speu orchards. Ripe, juicy, and naturally sweet.',
      imageUrl: 'https://lh3.googleusercontent.com/d/1Yd0yC88w2j8kP14e9H3vL3U5iW_cQG8S=s400',
      isVerifiedFarmer: true,
    ),
    MarketProduct(
      id: 'p3',
      name: 'Fresh Red Tomatoes',
      category: 'Vegetables',
      price: 0.65,
      unit: 'kg',
      quantity: 120,
      farmerName: 'Rithy Seng',
      location: 'Kandal',
      description: 'Plump, ripe red tomatoes harvested this morning. Perfect for salads and cooking.',
      imageUrl: 'https://lh3.googleusercontent.com/d/1Zd0yC88w2j8kP14e9H3vL3U5iW_cQG8S=s400',
      isVerifiedFarmer: false,
    ),
    MarketProduct(
      id: 'p4',
      name: 'Premium Yellow Corn',
      category: 'Grains',
      price: 0.50,
      unit: 'kg',
      quantity: 800,
      farmerName: 'Chan Sopheap',
      location: 'Battambang',
      description: 'Sweet feed corn, high grade starch content. Grown under optimal climatic conditions in Pailin/Battambang borders.',
      imageUrl: 'https://lh3.googleusercontent.com/d/1_d0yC88w2j8kP14e9H3vL3U5iW_cQG8S=s400',
      isVerifiedFarmer: true,
    ),
    MarketProduct(
      id: 'p5',
      name: 'Organic Bananas (Namwa)',
      category: 'Fruits',
      price: 0.40,
      unit: 'hand',
      quantity: 100,
      farmerName: 'Srey Leak',
      location: 'Kampong Cham',
      description: 'Local organic sweet Namwa Bananas, naturally ripened. Freshly cut from farm stems.',
      imageUrl: 'https://lh3.googleusercontent.com/d/2Ad0yC88w2j8kP14e9H3vL3U5iW_cQG8S=s400',
      isVerifiedFarmer: false,
    ),
  ];
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

  void addProduct(MarketProduct product) {
    _products.insert(0, product);
    addNotification('Product Added Successfully', 'Your product "${product.name}" is now live on the marketplace.');
    notifyListeners();
  }

  // --- Mock Negotiations (Bids) ---
  final List<BidOffer> _negotiations = [];
  List<BidOffer> get negotiations => _negotiations;

  void placeBid(MarketProduct product, double price, double qty) {
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

  void counterOffer(String bidId, double newPrice) {
    final index = _negotiations.indexWhere((n) => n.id == bidId);
    if (index != -1) {
      _negotiations[index].offeredPrice = newPrice;
      _negotiations[index].status = 'counter_offered';
      _negotiations[index].chatMessages.add('Farmer: Counter-offered at \$$newPrice');
      notifyListeners();
    }
  }

  void acceptBid(String bidId) {
    final index = _negotiations.indexWhere((n) => n.id == bidId);
    if (index != -1) {
      _negotiations[index].status = 'accepted';
      _negotiations[index].chatMessages.add('System: Bid accepted by Farmer!');
      addNotification('Bid Accepted!', 'Your bid on ${_negotiations[index].product.name} was accepted!');
      notifyListeners();
    }
  }

  void rejectBid(String bidId) {
    final index = _negotiations.indexWhere((n) => n.id == bidId);
    if (index != -1) {
      _negotiations[index].status = 'rejected';
      _negotiations[index].chatMessages.add('System: Offer declined.');
      notifyListeners();
    }
  }

  // --- Farmer Verification Queue (Admin) ---
  final List<FarmerVerification> _verifications = [
    FarmerVerification(
      id: 'v1',
      name: 'Rithy Seng',
      farmName: 'Seng Organic Veggies',
      location: 'Kandal Province',
      cropTypes: 'Tomatoes, Cabbages, Cucumbers',
      docUrl: 'kandal_farm_permit.pdf',
    ),
    FarmerVerification(
      id: 'v2',
      name: 'Srey Leak',
      farmName: 'Mekong River Banana Farm',
      location: 'Kampong Cham',
      cropTypes: 'Bananas, Coconuts',
      docUrl: 'mekong_permit.pdf',
    ),
  ];
  List<FarmerVerification> get verifications => _verifications;

  void approveFarmer(String verificationId) {
    final idx = _verifications.indexWhere((v) => v.id == verificationId);
    if (idx != -1) {
      _verifications[idx].status = 'approved';
      final name = _verifications[idx].name;
      // Also update products verification status
      for (var p in _products) {
        if (p.farmerName == name) {
          // In a real app we'd link by ID, but for prototype name is fine
          // Let's copy it or create new product with verified flag
        }
      }
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
  final List<ForumPost> _forumPosts = [
    ForumPost(
      id: 'fp1',
      author: 'Dr. Keo Dara',
      role: 'Expert',
      title: 'Managing Crop Diseases during Rainy Season',
      content: 'With the heavy rains in Cambodia, tomato growers should look out for blight. Ensure raised beds have excellent drainage, apply copper-based organic fungicides early, and prune lower leaves to increase aeration.',
      time: '3 hours ago',
      likes: 24,
      comments: [
        'Chan Sopheap: Extremely helpful tip. I lost half my crop last season due to blight.',
        'Sokha Kiri: Should I spray once a week or twice during heavy rain?'
      ],
    ),
    ForumPost(
      id: 'fp2',
      author: 'Chan Sopheap',
      role: 'Farmer',
      title: 'Organic Rice Yield Improvements',
      content: 'We swapped to composted cow manure mixed with biochar in Battambang. Saw a 15% increase in soil moisture retention and larger rice grains. Highly recommend farmers in the west to try this.',
      time: '1 day ago',
      likes: 18,
      comments: [
        'Kosal Pich: Great to see organic sustainable methods yielding well!',
        'Rithy Seng: Where can I buy biochar in bulk?'
      ],
    ),
  ];
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
  final List<MarketPrice> _marketPrices = [
    MarketPrice(name: 'Phka Rumduol Jasmine Rice', currentPrice: 1.15, changePercentage: 2.4, trend: 'up'),
    MarketPrice(name: 'Red Corn (Pailin)', currentPrice: 0.48, changePercentage: -1.2, trend: 'down'),
    MarketPrice(name: 'Fresh Cassava Roots', currentPrice: 0.12, changePercentage: 0.0, trend: 'stable'),
    MarketPrice(name: 'Cashew Nuts (Raw)', currentPrice: 1.65, changePercentage: 4.8, trend: 'up'),
    MarketPrice(name: 'Kampot Black Pepper', currentPrice: 6.50, changePercentage: 1.5, trend: 'up'),
  ];
  List<MarketPrice> get marketPrices => _marketPrices;
}
