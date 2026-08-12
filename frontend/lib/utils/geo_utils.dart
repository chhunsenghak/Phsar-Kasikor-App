import 'dart:math' as math;

const double _earthRadiusKm = 6371.0;

/// Great-circle distance between two lat/lng points, in kilometers — exact
/// port of backend/app/services/geo_service.py's haversine_km, so a
/// distance shown client-side (e.g. farm_map_directory.dart) matches what
/// the backend would compute for the same two points. Good enough for
/// "how far is this farm" — it undercounts actual road distance, but
/// there's no routing API in play here.
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  final double phi1 = lat1 * math.pi / 180;
  final double phi2 = lat2 * math.pi / 180;
  final double dPhi = (lat2 - lat1) * math.pi / 180;
  final double dLambda = (lng2 - lng1) * math.pi / 180;

  final double a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
      math.cos(phi1) * math.cos(phi2) * math.sin(dLambda / 2) * math.sin(dLambda / 2);
  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return _earthRadiusKm * c;
}
