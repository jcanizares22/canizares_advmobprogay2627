import 'package:flutter/material.dart';
import '../widgets/safe_svg.dart';

import '../models/product.dart';
import '../services/product_service.dart';
import '../widgets/custom_text.dart';
import 'product_screen.dart';
import 'settings_screen.dart';

// Enhancement 1: Search bar and product filtering
// Enhancement 2: Product/article details page

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ProductService _service = ProductService();
  final TextEditingController _searchController = TextEditingController();

  List<Product> _products = [];
  List<Product> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_onSearchChanged);
  }

  int _currentIndex = 0;

  void _loadProducts() async {
    try {
      final data = await _service.fetchProducts();
      setState(() {
        _products = data;
        _filtered = List<Product>.from(_products);
        _loading = false;
      });
      // Log product count when loaded for verification
      try {
        // ignore: avoid_print
        print('HomeScreen: loaded ${_products.length} products');
      } catch (_) {}
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filtered = List<Product>.from(_products));
      return;
    }
    setState(() {
      _filtered = _products.where((p) {
        final title = p.title.toLowerCase();
        final desc = p.description.toLowerCase();
        return title.contains(query) || desc.contains(query);
      }).toList();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SafeSvg.asset('assets/icons/NU_shield.svg', height: 28, width: 28),
            const SizedBox(width: 8),
            const Text('Products'),
          ],
        ),
        actions: [
          IconButton(
            icon: Image.asset('assets/images/nubdexchange_logo.png', width: 24, height: 24),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search products',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    FocusScope.of(context).unfocus();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _filtered.isEmpty
                          ? const Center(child: Text('No products found'))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              itemCount: _filtered.length,
                              itemBuilder: (context, index) {
                                final p = _filtered[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductScreen(product: p))),
                                    child: Row(
                                        children: [
                                          Container(
                                            width: 130,
                                            height: 130,
                                            decoration: BoxDecoration(
                                              borderRadius: const BorderRadius.only(
                                                  topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
                                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                            ),
                                              child: ClipRRect(
                                              borderRadius: const BorderRadius.only(
                                                  topLeft: Radius.circular(14), bottomLeft: Radius.circular(14)),
                                              child: p.image.isNotEmpty
                                                ? Image.network(
                                                  p.image,
                                                  width: 130,
                                                  height: 130,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder: (context, child, loadingProgress) {
                                                  if (loadingProgress == null) return child;
                                                  return Center(
                                                    child: SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child: CircularProgressIndicator(
                                                        value: loadingProgress.expectedTotalBytes != null
                                                          ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                                                          : null)));
                                                  },
                                                  errorBuilder: (context, error, stackTrace) => Image.asset('assets/images/nubdexchange_logo.png', width: 130, height: 130, fit: BoxFit.contain),
                                                )
                                                : Image.asset('assets/images/nubdexchange_logo.png', width: 130, height: 130, fit: BoxFit.contain),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      CustomText(p.title, size: 16, weight: FontWeight.bold),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        p.description,
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        children: [
                                                          const Icon(Icons.star, size: 16, color: Colors.amber),
                                                          const SizedBox(width: 6),
                                                          Text(p.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 13)),
                                                          const SizedBox(width: 8),
                                                          Text('(${p.ratingCount})', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Flexible(
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Flexible(
                                                              child: Chip(
                                                                label: Text(p.category, style: const TextStyle(fontSize: 12)),
                                                                backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(31),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                const Icon(Icons.star, size: 14, color: Colors.amber),
                                                                const SizedBox(width: 4),
                                                                Text(p.rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12)),
                                                                const SizedBox(width: 6),
                                                                Text('(${p.ratingCount})', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                                                        decoration: BoxDecoration(
                                                          color: Theme.of(context).colorScheme.primary,
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: Text('\$${p.price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 1) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Cart'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        ],
      ),
    );
  }
}
