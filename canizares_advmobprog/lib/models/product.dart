class Product {
  final int id;
  final String title;
  final String description;
  final double price;
  final String category;
  final String image;
  final double rating;
  final int ratingCount;

  Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.image,
    required this.rating,
    required this.ratingCount,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String? ?? '',
      // dummyjson uses 'thumbnail' while fakestoreapi uses 'image'
      image: json['image'] as String? ?? json['thumbnail'] as String? ?? '',
      // Rating may be an object ({rate, count}) or a number.
      rating: (() {
        final r = json['rating'];
        if (r is Map) return (r['rate'] as num?)?.toDouble() ?? 0.0;
        if (r is num) return r.toDouble();
        return (json['rating'] as num?)?.toDouble() ?? 0.0;
      })(),
      ratingCount: (() {
        final r = json['rating'];
        if (r is Map) return (r['count'] as num?)?.toInt() ?? 0;
        return (json['rating_count'] as num?)?.toInt() ?? 0;
      })(),
    );
  }
}
