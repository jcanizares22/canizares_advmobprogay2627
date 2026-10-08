import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../model/cart.dart';
import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../widgets/safe_svg.dart';
import 'product_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class CartScreen extends StatefulWidget {
  final String? userId;

  const CartScreen({super.key, this.userId});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late Future<List<Cart>> _cartsFuture;

  @override
  void initState() {
    super.initState();
    _cartsFuture = _loadCartsForSavedUser();
  }

  Future<List<Cart>> _loadCartsForSavedUser() async {
    final userId = await _getUserId();
    final preferences = await SharedPreferences.getInstance();
    final savedProducts = preferences.getStringList(
      'localCartProducts_$userId',
    );
    final products =
        savedProducts
            ?.map(jsonDecode)
            .whereType<Map<String, dynamic>>()
            .map(CartProduct.fromJson)
            .toList() ??
        <CartProduct>[];
    if (products.isEmpty) return [];

    final total = products.fold<double>(
      0,
      (sum, product) => sum + product.total,
    );
    final discountedTotal = products.fold<double>(
      0,
      (sum, product) => sum + product.discountedTotal,
    );
    return [
      Cart(
        id: 1,
        userId: 1,
        products: products,
        total: total,
        discountedTotal: discountedTotal,
        totalProducts: products.length,
        totalQuantity: products.fold(
          0,
          (sum, product) => sum + product.quantity,
        ),
      ),
    ];
  }

  Future<String> _getUserId() async {
    if (widget.userId != null) return widget.userId!;
    final userId = context.read<AuthProvider>().user?.uid;
    if (userId == null) throw Exception('No authenticated user is signed in.');
    return userId;
  }

  Future<void> _changeQuantity(CartProduct item, int change) async {
    final quantity = item.quantity + change;
    if (quantity < 1) return;

    try {
      final userId = await _getUserId();
      final preferences = await SharedPreferences.getInstance();
      final key = 'localCartProducts_$userId';
      final savedProducts = preferences.getStringList(key) ?? [];
      final updatedProduct = item.toJson()
        ..['quantity'] = quantity
        ..['total'] = item.price * quantity
        ..['discountedTotal'] =
            item.price * (1 - item.discountPercentage / 100) * quantity;
      final savedIndex = savedProducts.indexWhere((savedProduct) {
        final decoded = jsonDecode(savedProduct);
        return decoded is Map<String, dynamic> && decoded['id'] == item.id;
      });

      if (savedIndex == -1) {
        savedProducts.add(jsonEncode(updatedProduct));
      } else {
        savedProducts[savedIndex] = jsonEncode(updatedProduct);
      }
      await preferences.setStringList(key, savedProducts);

      if (!mounted) return;
      setState(() => _cartsFuture = _loadCartsForSavedUser());
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update quantity: $error')),
      );
    }
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            SafeSvg.asset('assets/icons/NU_shield.svg', height: 28, width: 28),
            const SizedBox(width: 8),
            const Text('Products API'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
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
          final summaryCart = carts.isEmpty ? null : carts.first;
          final items = carts.expand((cart) => cart.products).toList();

          if (items.isEmpty) {
            return const Center(child: Text('No cart items found'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length + 3,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'My Cart',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                );
              }

              if (index == 1 && summaryCart != null) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cart #${summaryCart.id > 0 ? summaryCart.id : 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Account • ${summaryCart.totalQuantity} items',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        Text(
                          '\$${summaryCart.total.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (index == 2) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Cart Items',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              }

              final item = items[index - 3];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ProductScreen(product: _productFromCartItem(item)),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        SizedBox(
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${item.price.toStringAsFixed(2)}',
                                style: TextStyle(color: Colors.orange.shade800),
                              ),
                              Text(
                                'Qty ${item.quantity} | Total \$${item.total.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Increase quantity',
                              onPressed: () => _changeQuantity(item, 1),
                              icon: const Icon(Icons.add, size: 18),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFFFC107),
                                foregroundColor: Colors.black87,
                                minimumSize: const Size(32, 32),
                                maximumSize: const Size(32, 32),
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            Text('${item.quantity}'),
                            IconButton(
                              tooltip: 'Decrease quantity',
                              onPressed: item.quantity > 1
                                  ? () => _changeQuantity(item, -1)
                                  : null,
                              icon: const Icon(Icons.remove, size: 18),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black12,
                                foregroundColor: Colors.black87,
                                disabledForegroundColor: Colors.black26,
                                minimumSize: const Size(32, 32),
                                maximumSize: const Size(32, 32),
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.popUntil(context, (route) => route.isFirst);
          } else if (index == 2) {
            Navigator.popUntil(context, (route) => route.isFirst);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            label: 'Shop',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
