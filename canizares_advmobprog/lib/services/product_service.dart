import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../constants.dart';
import '../models/product.dart';

class ProductService {
  final http.Client _client;

  ProductService([http.Client? client]) : _client = client ?? http.Client();

  /// Fetch products from configured API.
  /// If an `assets/.env` file contains `HOST=...`, it will use that host.
  /// Supports APIs that return either a raw JSON array or an object with
  /// a `products` array (e.g., dummyjson.com).
  Future<List<Product>> fetchProducts() async {
    // Default base
    var base = Constants.apiBase;

    // Try loading assets/.env for HOST override
    try {
      final env = await rootBundle.loadString('assets/.env');
      for (final line in env.split('\n')) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
        final parts = trimmed.split('=');
        if (parts.length >= 2 && parts[0].trim() == 'HOST') {
          base = parts.sublist(1).join('=').trim();
          break;
        }
      }
    } catch (_) {
      // ignore - use default
    }

    // Ensure we have a full URL (add https scheme if missing)
    var normalized = base;
    try {
      final u = Uri.parse(base);
      if (u.scheme.isEmpty) normalized = 'https://$base';
    } catch (_) {
      normalized = 'https://$base';
    }

    final url = Uri.parse(normalized);
    late final http.Response resp;
    try {
      resp = await _client.get(url);
    } catch (e) {
      throw Exception('Network error while fetching products: $e');
    }
    if (resp.statusCode == 200) {
      final decoded = json.decode(resp.body);

      // If API returns an object with 'products' key (dummyjson), extract it
      // Otherwise, if decoded is a List use it. If it's a Map, try to find the
      // first List value (some APIs nest the array under different keys).
      List<dynamic> dataList = [];
      if (decoded is List) {
        dataList = decoded;
      } else if (decoded is Map) {
        if (decoded['products'] is List) {
          dataList = decoded['products'] as List<dynamic>;
        } else {
          // Search for first List value in the map
          for (final v in decoded.values) {
            if (v is List) {
              dataList = v as List<dynamic>;
              break;
            }
          }
        }
      }

      if (dataList.isEmpty) {
        throw Exception('Unexpected API response format: no product list found');
      }

        // Log loaded product count for verification
        try {
          // ignore: avoid_print
          print('ProductService: loaded ${dataList.length} products from $base');
        } catch (_) {}

      return dataList.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to load products: ${resp.statusCode}');
    }
  }
}

