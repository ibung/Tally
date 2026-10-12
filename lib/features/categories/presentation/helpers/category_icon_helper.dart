import 'package:flutter/material.dart';

class CategoryIconHelper {
  static const List<({String key, String label, IconData icon})> availableIcons = [
    (key: 'food', label: 'Makanan', icon: Icons.restaurant_outlined),
    (key: 'transport', label: 'Transport', icon: Icons.directions_car_outlined),
    (key: 'shopping', label: 'Belanja', icon: Icons.shopping_bag_outlined),
    (key: 'bill', label: 'Tagihan', icon: Icons.receipt_outlined),
    (key: 'entertainment', label: 'Hiburan', icon: Icons.movie_outlined),
    (key: 'health', label: 'Kesehatan', icon: Icons.medical_services_outlined),
    (key: 'education', label: 'Pendidikan', icon: Icons.school_outlined),
    (key: 'salary', label: 'Gaji', icon: Icons.payments_outlined),
    (key: 'freelance', label: 'Kerja', icon: Icons.work_outline_rounded),
    (key: 'investment', label: 'Investasi', icon: Icons.trending_up_rounded),
    (key: 'gift', label: 'Hadiah', icon: Icons.card_giftcard_outlined),
    (key: 'fitness', label: 'Olahraga', icon: Icons.fitness_center_rounded),
    (key: 'travel', label: 'Liburan', icon: Icons.flight_outlined),
    (key: 'home', label: 'Rumah', icon: Icons.home_outlined),
    (key: 'pets', label: 'Hewan', icon: Icons.pets_outlined),
    (key: 'coffee', label: 'Kopi', icon: Icons.coffee_outlined),
    (key: 'savings', label: 'Tabungan', icon: Icons.savings_outlined),
    (key: 'other', label: 'Lainnya', icon: Icons.category_outlined),
  ];

  static IconData getIcon(String? iconKey) {
    if (iconKey == null) return Icons.category_outlined;
    final match = availableIcons.where((item) => item.key == iconKey);
    if (match.isNotEmpty) return match.first.icon;

    // Backward compatibility with possible material icon names
    switch (iconKey) {
      case 'fastfood':
      case 'restaurant':
        return Icons.restaurant_outlined;
      case 'directions_car':
        return Icons.directions_car_outlined;
      case 'shopping_cart':
        return Icons.shopping_bag_outlined;
      case 'receipt':
        return Icons.receipt_outlined;
      case 'movie':
        return Icons.movie_outlined;
      case 'medical_services':
        return Icons.medical_services_outlined;
      case 'school':
        return Icons.school_outlined;
      default:
        return Icons.category_outlined;
    }
  }
}
