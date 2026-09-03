import 'package:flutter/material.dart';

import '../model/cart.dart';
import '../model/cart_service.dart';
import '../models/product.dart';
import 'product_screen.dart';

class CartScreen extends StatefulWidget {
  final int userId;

  const CartScreen({super.key, this.userId = 1});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _service = CartService();
  late Future<List<Cart>> _cartsFuture;

  @override
  void initState() {
    super.initState();
    _cartsFuture = _service.fetchCartsByUserId(widget.userId);
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
