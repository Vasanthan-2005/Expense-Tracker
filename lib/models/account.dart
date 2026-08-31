import 'package:flutter/material.dart';

import '../core/utils/icon_data_helper.dart';

class Account {
  final int? id;
  final String name;
  final int openingBalanceMinorUnits;
  final int iconCodePoint;
  final String? iconFontFamily;
  final int colorValue;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Account({
    this.id,
    required this.name,
    required this.openingBalanceMinorUnits,
    required this.iconCodePoint,
    this.iconFontFamily,
    required this.colorValue,
    this.isDefault = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Opening balance in major currency units (e.g., Rupees as double)
  double get openingBalanceDouble => openingBalanceMinorUnits / 100.0;

  static int doubleToMinorUnits(double value) {
    return (value * 100).round();
  }

  IconData get iconData {
    return IconDataHelper.getIcon(iconCodePoint, fallback: Icons.account_balance);
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'opening_balance': openingBalanceMinorUnits,
      'icon_code': iconCodePoint,
      'icon_font_family': iconFontFamily,
      'color_value': colorValue,
      'is_default': isDefault ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Account.fromMap(Map<String, dynamic> map) {
    return Account(
      id: map['id'] as int?,
      name: map['name'] as String,
      openingBalanceMinorUnits: (map['opening_balance'] as int?) ?? 0,
      iconCodePoint: map['icon_code'] as int,
      iconFontFamily: map['icon_font_family'] as String?,
      colorValue: map['color_value'] as int,
      isDefault: (map['is_default'] as int?) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Account copyWith({
    int? id,
    String? name,
    int? openingBalanceMinorUnits,
    int? iconCodePoint,
    String? iconFontFamily,
    int? colorValue,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      openingBalanceMinorUnits: openingBalanceMinorUnits ?? this.openingBalanceMinorUnits,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      iconFontFamily: iconFontFamily ?? this.iconFontFamily,
      colorValue: colorValue ?? this.colorValue,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static List<Account> get defaultAccounts {
    final now = DateTime.now();
    return [
      Account(
        id: 1,
        name: 'Cash',
        openingBalanceMinorUnits: 0,
        iconCodePoint: Icons.payments.codePoint,
        colorValue: 0xFF10B981, // Emerald green
        isDefault: false,
        createdAt: now,
        updatedAt: now,
      ),
      Account(
        id: 2,
        name: 'Expense Account',
        openingBalanceMinorUnits: 0,
        iconCodePoint: Icons.account_balance_wallet.codePoint,
        colorValue: 0xFF6366F1, // Indigo
        isDefault: true,
        createdAt: now,
        updatedAt: now,
      ),
      Account(
        id: 3,
        name: 'Salary Account',
        openingBalanceMinorUnits: 0,
        iconCodePoint: Icons.account_balance.codePoint,
        colorValue: 0xFF3B82F6, // Blue
        isDefault: false,
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }
}
