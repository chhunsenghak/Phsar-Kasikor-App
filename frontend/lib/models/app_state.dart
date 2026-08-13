import 'state/base_app_state.dart';
import 'state/location_state.dart';
import 'state/product_state.dart';
import 'state/contract_state.dart';
import 'state/notification_state.dart';
import 'state/forum_state.dart';
import 'state/cart_state.dart';

// Export all states so screens importing app_state.dart get all models automatically
export 'state/base_app_state.dart';
export 'state/location_state.dart';
export 'state/product_state.dart';
export 'state/contract_state.dart';
export 'state/notification_state.dart';
export 'state/forum_state.dart';
export 'state/cart_state.dart';

class AppState extends BaseAppState with
    LocationStateMixin,
    ProductStateMixin,
    ContractStateMixin,
    NotificationStateMixin,
    ForumStateMixin,
    CartStateMixin {
  
  AppState() {
    restoreSavedSession();
    // refreshProducts() resolves each product's raw province code (e.g.
    // "01") through the province map loadLocations() populates — must
    // finish first, or products load with un-resolved codes that never
    // get fixed up until the next explicit refresh.
    loadLocations().then((_) => refreshCategories()).then((_) => refreshProducts());
    refreshMarketPrices();
  }

  // Unified data loader on app boot or login refresh
  @override
  Future<void> loadBackendData() async {
    await loadLocations();
    await refreshCategories();
    await refreshProducts();
    await refreshNotifications();
    await refreshContracts();
    await refreshMarketPrices();
    await refreshAddressRequests();
    await refreshFarmerCertificates();
    await refreshPublicCertificateDirectory();
  }
}
