import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/cart.dart';
import '../model/cart_service.dart';
import '../model/user.dart';
import '../models/product.dart';
import 'product_screen.dart';

class CartScreen extends StatefulWidget {
  final int? userId;

  const CartScreen({super.key, this.userId});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _service = CartService();
  late Future<List<Cart>> _cartsFuture;

  @override
  void initState() {
    super.initState();
    _cartsFuture = _loadCartsForSavedUser();
  }

  Future<List<Cart>> _loadCartsForSavedUser() async {
    var userId = widget.userId;
    if (userId == null) {
      const userDataKey = 'savedUser';
      final preferences = await SharedPreferences.getInstance();
      final savedUser = preferences.getString(userDataKey);
      if (savedUser == null || savedUser.isEmpty) {
        throw Exception('No saved user data found');
      }

      final decoded = jsonDecode(savedUser);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid saved user data');
      }
      userId = User.fromJson(decoded).id;
    }

    final remoteCarts = await _service.fetchCartsByUserId(userId);
    final preferences = await SharedPreferences.getInstance();
    final savedProducts = preferences.getStringList('localCartProducts_$userId');
    if (savedProducts == null || savedProducts.isEmpty) return remoteCarts;

    final remoteProductIds = remoteCarts
        .expand((cart) => cart.products)
        .map((product) => product.id)
        .toSet();
    final localProducts = savedProducts
        .map(jsonDecode)
        .whereType<Map<String, dynamic>>()
        .map(CartProduct.fromJson)
        .where((product) => !remoteProductIds.contains(product.id))
        .toList();
    if (localProducts.isEmpty) return remoteCarts;

    return [
      ...remoteCarts,
      Cart(
        id: -1,
        userId: userId,
        products: localProducts,
        total: localProducts.fold(0, (sum, product) => sum + product.total),
        discountedTotal: localProducts.fold(
          0,
          (sum, product) => sum + product.discountedTotal,
        ),
        totalProducts: localProducts.length,
        totalQuantity: localProducts.fold(
          0,
          (sum, product) => sum + product.quantity,
        ),
      ),
    ];
  }

  Product _productFromCartItem(CartProduct item) {
    return Product(
      id: item.id,
      title: item.title,
      description: '',
      price: item.price,
      category: '',
      image: item.thumbnail,
      rating: 0,
      ratingCount: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: FutureBuilder<List<Cart>>(
        future: _cartsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final carts = snapshot.data ?? [];
          final items = carts.expand((cart) => cart.products).toList();

          if (items.isEmpty) {
            return const Center(child: Text('No cart items found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: SizedBox(
                    width: 64,
                    height: 64,
                    child: item.thumbnail.isEmpty
                        ? const Icon(Icons.image_not_supported)
                        : Image.network(
                            item.thumbnail,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.broken_image),
                          ),
                  ),
                  title: Text(item.title),
                  subtitle: Text(
                    'Quantity: ${item.quantity}\n\$${item.price.toStringAsFixed(2)} each',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    '\$${item.total.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ProductScreen(product: _productFromCartItem(item)),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
