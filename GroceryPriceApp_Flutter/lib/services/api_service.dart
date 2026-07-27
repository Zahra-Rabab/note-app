import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProductMatch {
  final bool matched;
  final String? canonicalName;
  final List<String> units;
  final String? defaultUnit;
  final double confidence;
  final List<ProductMatch> suggestions;

  ProductMatch({
    required this.matched,
    this.canonicalName,
    this.units = const [],
    this.defaultUnit,
    this.confidence = 0,
    this.suggestions = const [],
  });

  factory ProductMatch.fromJson(Map<String, dynamic> json) {
    if (json['matched'] == true) {
      return ProductMatch(
        matched: true,
        canonicalName: json['canonicalName'] as String,
        units: List<String>.from(json['units'] as List),
        defaultUnit: json['defaultUnit'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      );
    }
    final rawSuggestions = (json['suggestions'] as List?) ?? [];
    return ProductMatch(
      matched: false,
      suggestions: rawSuggestions
          .map((s) => ProductMatch(
                matched: true,
                canonicalName: s['canonicalName'] as String,
                units: List<String>.from(s['units'] as List),
                defaultUnit: s['defaultUnit'] as String?,
              ))
          .toList(),
    );
  }
}

class StorePrice {
  final String store;
  final double unitPrice;
  StorePrice({required this.store, required this.unitPrice});

  factory StorePrice.fromJson(Map<String, dynamic> json) {
    return StorePrice(
      store: json['store'] as String,
      unitPrice: (json['unitPrice'] as num).toDouble(),
    );
  }
}

class PriceLookupResult {
  final bool found;
  final double? approxAverage;
  final List<StorePrice> storePrices;

  PriceLookupResult({required this.found, this.approxAverage, this.storePrices = const []});

  factory PriceLookupResult.fromJson(Map<String, dynamic> json) {
    final rawStores = (json['storePrices'] as List?) ?? [];
    return PriceLookupResult(
      found: json['found'] as bool,
      approxAverage: (json['approxAverage'] as num?)?.toDouble(),
      storePrices: rawStores.map((s) => StorePrice.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}

/// The backend URL is stored on-device and editable from the Settings
/// screen — NOT a hardcoded constant. This exists specifically because the
/// PC's local IP address changes between Wi-Fi sessions; previously that
/// meant editing this file and doing a full rebuild every time. Now it's
/// a one-time setting you change from the app itself.
class ApiService {
  static const _prefsKey = 'backend_base_url';
  static const String defaultUrl = 'http://10.0.2.2:5000';

  static String _cachedUrl = defaultUrl;

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedUrl = prefs.getString(_prefsKey) ?? defaultUrl;
    return _cachedUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    final trimmed = url.trim().replaceAll(RegExp(r'/+$'), ''); // no trailing slash
    _cachedUrl = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, trimmed);
  }

  /// Quick reachability check for the Settings screen's "Test Connection"
  /// button — hits /health and reports success/failure with a clear reason,
  /// instead of the app failing silently somewhere else later.
  static Future<(bool, String)> testConnection(String url) async {
    try {
      final trimmed = url.trim().replaceAll(RegExp(r'/+$'), '');
      final response = await http
          .get(Uri.parse('$trimmed/health'))
          .timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        return (true, 'Connected — backend is reachable.');
      }
      return (false, 'Backend responded with status ${response.statusCode}.');
    } catch (e) {
      return (false, "Couldn't reach that address. Check the IP, that "
          "python app.py is running, that your phone is on the same "
          "Wi-Fi, and that your PC's firewall allows port 5000.");
    }
  }

  Future<ProductMatch> matchProduct(String query) async {
    final base = await getBaseUrl();
    final url = Uri.parse('$base/match?q=${Uri.encodeComponent(query)}');
    final response = await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Backend returned ${response.statusCode}');
    }
    return ProductMatch.fromJson(jsonDecode(response.body));
  }

  Future<PriceLookupResult> fetchPrice(String product, String unit) async {
    final base = await getBaseUrl();
    final url = Uri.parse(
      '$base/prices?product=${Uri.encodeComponent(product)}&unit=${Uri.encodeComponent(unit)}',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Backend returned ${response.statusCode}');
    }
    return PriceLookupResult.fromJson(jsonDecode(response.body));
  }
}
