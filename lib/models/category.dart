import 'package:flutter/material.dart';

import '../core/utils/icon_data_helper.dart';

class Category {
  final int? id;
  final String name;
  final int iconCodePoint;
  final String? iconFontFamily;
  final int colorValue;
  final bool isDefault;
  final DateTime createdAt;
  final int? monthlyBudgetPaise;
  final int sortOrder;

  const Category({
    this.id,
    required this.name,
    required this.iconCodePoint,
    this.iconFontFamily = 'MaterialIcons',
    required this.colorValue,
    this.isDefault = false,
    required this.createdAt,
    this.monthlyBudgetPaise,
    this.sortOrder = 0,
  });

  IconData get iconData => IconDataHelper.getIcon(iconCodePoint);

  Color get color => Color(colorValue);

  double get monthlyBudgetDouble => (monthlyBudgetPaise ?? 0) / 100.0;

  bool get isBudgetSet => monthlyBudgetPaise != null;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'icon_code': iconCodePoint,
      'icon_font_family': iconFontFamily,
      'color_value': colorValue,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'monthly_budget': monthlyBudgetPaise,
      'sort_order': sortOrder,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      iconCodePoint: map['icon_code'] as int,
      iconFontFamily: map['icon_font_family'] as String?,
      colorValue: map['color_value'] as int,
      isDefault: (map['is_default'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      monthlyBudgetPaise: map['monthly_budget'] as int?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }

  Category copyWith({
    int? id,
    String? name,
    int? iconCodePoint,
    String? iconFontFamily,
    int? colorValue,
    bool? isDefault,
    DateTime? createdAt,
    int? monthlyBudgetPaise,
    bool resetMonthlyBudget = false,
    int? sortOrder,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      colorValue: colorValue ?? this.colorValue,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      monthlyBudgetPaise: resetMonthlyBudget ? null : (monthlyBudgetPaise ?? this.monthlyBudgetPaise),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  static List<Category> get defaultCategories {
    final now = DateTime.now();
    return [
      Category(
        id: 1,
        name: 'Petrol',
        iconCodePoint: Icons.local_gas_station.codePoint,
        colorValue: 0xFFFF9800, // Amber / Orange
        isDefault: true,
        createdAt: now,
        sortOrder: 0,
      ),
      Category(
        id: 2,
        name: 'Groceries',
        iconCodePoint: Icons.shopping_cart.codePoint,
        colorValue: 0xFF4CAF50, // Green
        isDefault: true,
        createdAt: now,
        sortOrder: 1,
      ),
      Category(
        id: 3,
        name: 'Medicine',
        iconCodePoint: Icons.medical_services.codePoint,
        colorValue: 0xFFE91E63, // Pink / Red
        isDefault: true,
        createdAt: now,
        sortOrder: 2,
      ),
      Category(
        id: 4,
        name: 'Vegetables & Fruits',
        iconCodePoint: Icons.eco.codePoint,
        colorValue: 0xFF8BC34A, // Light Green
        isDefault: true,
        createdAt: now,
        sortOrder: 3,
      ),
      Category(
        id: 5,
        name: 'Travel',
        iconCodePoint: Icons.directions_car.codePoint,
        colorValue: 0xFF2196F3, // Blue
        isDefault: true,
        createdAt: now,
        sortOrder: 4,
      ),
      Category(
        id: 6,
        name: 'Transfer',
        iconCodePoint: Icons.swap_horiz.codePoint,
        colorValue: 0xFF6366F1, // Indigo
        isDefault: true,
        createdAt: now,
        sortOrder: 5,
      ),
      Category(
        id: 7,
        name: 'Dress',
        iconCodePoint: Icons.checkroom.codePoint,
        colorValue: 0xFF9C27B0, // Purple
        isDefault: true,
        createdAt: now,
        sortOrder: 6,
      ),
      Category(
        id: 8,
        name: 'Investment',
        iconCodePoint: Icons.trending_up.codePoint,
        colorValue: 0xFF009688, // Teal
        isDefault: true,
        createdAt: now,
        sortOrder: 7,
      ),
      Category(
        id: 9,
        name: 'Insurance',
        iconCodePoint: Icons.shield.codePoint,
        colorValue: 0xFFFF5722, // Deep Orange
        isDefault: true,
        createdAt: now,
        sortOrder: 8,
      ),
      Category(
        id: 10,
        name: 'Misc',
        iconCodePoint: Icons.more_horiz.codePoint,
        colorValue: 0xFF607D8B, // Blue Grey
        isDefault: true,
        createdAt: now,
        sortOrder: 9,
      ),
    ];
  }
}
