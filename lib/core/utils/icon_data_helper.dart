import 'package:flutter/material.dart';

class IconDataHelper {
  static final Map<int, IconData> _iconMap = {
    Icons.account_balance.codePoint: Icons.account_balance,
    Icons.account_balance_wallet.codePoint: Icons.account_balance_wallet,
    Icons.savings.codePoint: Icons.savings,
    Icons.credit_card.codePoint: Icons.credit_card,
    Icons.monetization_on.codePoint: Icons.monetization_on,
    Icons.payments.codePoint: Icons.payments,
    Icons.currency_rupee.codePoint: Icons.currency_rupee,
    Icons.attach_money.codePoint: Icons.attach_money,
    Icons.work_outline.codePoint: Icons.work_outline,
    Icons.storefront.codePoint: Icons.storefront,
    Icons.local_gas_station.codePoint: Icons.local_gas_station,
    Icons.shopping_cart.codePoint: Icons.shopping_cart,
    Icons.medical_services.codePoint: Icons.medical_services,
    Icons.eco.codePoint: Icons.eco,
    Icons.directions_car.codePoint: Icons.directions_car,
    Icons.swap_horiz.codePoint: Icons.swap_horiz,
    Icons.checkroom.codePoint: Icons.checkroom,
    Icons.trending_up.codePoint: Icons.trending_up,
    Icons.shield.codePoint: Icons.shield,
    Icons.more_horiz.codePoint: Icons.more_horiz,
    Icons.restaurant.codePoint: Icons.restaurant,
    Icons.receipt_long.codePoint: Icons.receipt_long,
    Icons.shopping_bag.codePoint: Icons.shopping_bag,
    Icons.school.codePoint: Icons.school,
    Icons.movie.codePoint: Icons.movie,
    Icons.home.codePoint: Icons.home,
    Icons.subscriptions.codePoint: Icons.subscriptions,
    Icons.person.codePoint: Icons.person,
    Icons.fitness_center.codePoint: Icons.fitness_center,
    Icons.flight.codePoint: Icons.flight,
    Icons.sports_esports.codePoint: Icons.sports_esports,
    Icons.pets.codePoint: Icons.pets,
    Icons.work.codePoint: Icons.work,
    Icons.card_giftcard.codePoint: Icons.card_giftcard,
    Icons.build.codePoint: Icons.build,
    Icons.category.codePoint: Icons.category,
    Icons.star.codePoint: Icons.star,
  };

  static IconData getIcon(int codePoint, {IconData fallback = Icons.category}) {
    return _iconMap[codePoint] ?? fallback;
  }
}
