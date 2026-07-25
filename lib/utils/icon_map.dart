import 'package:flutter/material.dart';

/// Mapeamento de nomes de ícone (string) para IconData, permitindo
/// persistir a escolha de ícone das categorias customizadas.
const Map<String, IconData> iconMap = {
  'category': Icons.category_rounded,
  'event': Icons.celebration_rounded,
  'directions_car': Icons.directions_car_rounded,
  'home': Icons.home_rounded,
  'account_balance': Icons.account_balance_rounded,
  'restaurant': Icons.restaurant_rounded,
  'sports_esports': Icons.sports_esports_rounded,
  'school': Icons.school_rounded,
  'local_hospital': Icons.local_hospital_rounded,
  'volunteer_activism': Icons.volunteer_activism_rounded,
  'attach_money': Icons.attach_money_rounded,
  'flight': Icons.flight_rounded,
  'shopping_bag': Icons.shopping_bag_rounded,
  'savings': Icons.savings_rounded,
  'trending_up': Icons.trending_up_rounded,
  'card_giftcard': Icons.card_giftcard_rounded,
  'pets': Icons.pets_rounded,
  'fitness_center': Icons.fitness_center_rounded,
  'phone_iphone': Icons.phone_iphone_rounded,
  'more_horiz': Icons.more_horiz_rounded,
};

IconData iconFor(String key) => iconMap[key] ?? Icons.category_rounded;

const List<String> iconKeys = [
  'category',
  'event',
  'directions_car',
  'home',
  'account_balance',
  'restaurant',
  'sports_esports',
  'school',
  'local_hospital',
  'volunteer_activism',
  'attach_money',
  'flight',
  'shopping_bag',
  'savings',
  'trending_up',
  'card_giftcard',
  'pets',
  'fitness_center',
  'phone_iphone',
  'more_horiz',
];
