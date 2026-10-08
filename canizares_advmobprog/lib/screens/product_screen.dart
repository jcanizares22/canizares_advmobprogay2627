import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/product.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_text.dart';

// Enhancement 2: Product/article details page
class ProductScreen extends StatelessWidget {
  final Product product;

  const ProductScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(product.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: product.image.isNotEmpty
                      ? Image.network(
                          product.image,
                          height: 220,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                            (loadingProgress
                                                    .expectedTotalBytes ??
                                                1)
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) =>
                              Image.asset(
                                'assets/images/nubdexchange_logo.png',
                                height: 220,
                                fit: BoxFit.contain,
                              ),
                        )
                      : Image.asset(
                          'assets/images/nubdexchange_logo.png',
                          height: 220,
                        ),
                ),
                const SizedBox(height: 16),
                CustomText(product.title, size: 20, weight: FontWeight.bold),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber),
                    const SizedBox(width: 6),
                    Text(
                      product.rating.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${product.ratingCount} reviews)',
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CustomText('\$${product.price.toStringAsFixed(2)}', size: 18),
                const SizedBox(height: 12),
                CustomText(product.description),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final userId = context.read<AuthProvider>().user?.uid;
                        if (userId == null) {
                          throw StateError(
                            'Sign in to add products to your cart.',
                          );
                        }
                        final preferences =
                            await SharedPreferences.getInstance();
                        await _saveLocalCartProduct(preferences, userId);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Product added to cart'),
                          ),
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Unable to add product: $error'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Add to Cart'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveLocalCartProduct(
    SharedPreferences preferences,
    String userId,
  ) async {
    final key = 'localCartProducts_$userId';
    final savedProducts = preferences.getStringList(key) ?? [];
    final productData = jsonEncode({
      'id': product.id,
      'title': product.title,
      'price': product.price,
      'quantity': 1,
      'total': product.price,
      'discountPercentage': 0,
      'discountedTotal': product.price,
      'thumbnail': product.image,
    });

    final existingIndex = savedProducts.indexWhere((item) {
      final data = jsonDecode(item);
      return data is Map<String, dynamic> && data['id'] == product.id;
    });
    if (existingIndex == -1) {
      savedProducts.add(productData);
    } else {
      final data = jsonDecode(savedProducts[existingIndex]);
      if (data is Map<String, dynamic>) {
        final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
        data['quantity'] = quantity + 1;
        data['total'] = product.price * (quantity + 1);
        data['discountedTotal'] = product.price * (quantity + 1);
        savedProducts[existingIndex] = jsonEncode(data);
      }
    }
    await preferences.setStringList(key, savedProducts);
  }
}
