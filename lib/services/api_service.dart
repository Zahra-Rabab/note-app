import 'dart:convert';
import 'package:http/http.dart' as http;

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

class ApiService {
  /// adb reverse tcp:5000 tcp:5000 forwards the phone's localhost:5000
  /// to the PC's localhost:5000 over USB — works regardless of Wi-Fi/firewall.
  static const String baseUrl = 'http://127.0.0.1:5000';

  /// Matches free-text (any language/spelling) to a known product.
  Future<ProductMatch> matchProduct(String query) async {
    final url = Uri.parse('$baseUrl/match?q=${Uri.encodeComponent(query)}');
    final response = await http.get(url).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Backend returned ${response.statusCode}');
    }
    return ProductMatch.fromJson(jsonDecode(response.body));
  }

  /// Gets prices for a specific product+unit from every store that has it.
  Future<PriceLookupResult> fetchPrice(String product, String unit) async {
    final url = Uri.parse(
      '$baseUrl/prices?product=${Uri.encodeComponent(product)}&unit=${Uri.encodeComponent(unit)}',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Backend returned ${response.statusCode}');
    }
    return PriceLookupResult.fromJson(jsonDecode(response.body));
  }
}
