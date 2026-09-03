import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../constants.dart';
import 'cart.dart';

class CartService {
  final http.Client _client;

  CartService([http.Client? client]) : _client = client ?? http.Client();

  Future<List<Cart>> fetchCarts() async {
    final base = await _loadApiBase();
    final response = await _client.get(Uri.parse('$base/carts'));

    if (response.statusCode != 200) {
      throw Exception('Failed to load carts: ${response.statusCode}');
    }

    try {
      final decoded = json.decode(response.body);
      final carts = decoded is Map<String, dynamic>
          ? decoded['carts']
          : decoded;

      if (carts is! List) {
        throw const FormatException('Expected a carts list');
      }

      return carts
          .map((cart) => Cart.fromJson(cart as Map<String, dynamic>))
          .toList();
    } on FormatException catch (error) {
      throw Exception('Invalid cart API response: $error');
    } on TypeError catch (error) {
      throw Exception('Invalid cart API response: $error');
    }
  }

  Future<List<Cart>> fetchCartsByUserId(int userId) async {
    final base = await _loadApiBase();
    final response = await _client.get(Uri.parse('$base/carts/user/$userId'));

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load carts for user $userId: ${response.statusCode}',
      );
    }

    try {
      final decoded = json.decode(response.body);
      final carts = decoded is Map<String, dynamic>
          ? decoded['carts']
          : decoded;

      if (carts is! List) {
        throw const FormatException('Expected a carts list');
      }

      return carts
          .map((cart) => Cart.fromJson(cart as Map<String, dynamic>))
          .toList();
    } on FormatException catch (error) {
      throw Exception('Invalid cart API response: $error');
    } on TypeError catch (error) {
      throw Exception('Invalid cart API response: $error');
    }
  }

  Future<Cart> addToCart({
    required int userId,
    required int productId,
    int quantity = 1,
  }) async {
    final base = await _loadApiBase();
    final response = await _client.post(
      Uri.parse('$base/carts/add'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'userId': userId,
        'products': [
          {'id': productId, 'quantity': quantity},
        ],
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add product to cart: ${response.statusCode}');
    }

    try {
      return Cart.fromJson(json.decode(response.body) as Map<String, dynamic>);
    } on FormatException catch (error) {
      throw Exception('Invalid add-cart API response: $error');
    } on TypeError catch (error) {
      throw Exception('Invalid add-cart API response: $error');
    }
  }

  Future<String> _loadApiBase() async {
    var base = Constants.apiBase;

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
      // Use the configured fallback when the optional environment asset is unavailable.
    }

    final uri = Uri.tryParse(base);
    if (uri == null || uri.host.isEmpty) {
      throw Exception('Invalid API base URL: $base');
    }

    final path = uri.path.endsWith('/products')
        ? uri.path.substring(0, uri.path.length - '/products'.length)
        : uri.path;
    return uri.replace(path: path).toString().replaceFirst(RegExp(r'/$'), '');
  }
}
