class Expense {
  final int? id;
  final int amountMinorUnits; // Integer minor units (e.g., 10050 = 100.50)
  final int categoryId;
  final int? accountId;
  final String? note;
  final DateTime date; // Store date portion (YYYY-MM-DD)
  final String timeString; // HH:mm format
  final DateTime createdAt;
  final DateTime updatedAt;

  const Expense({
    this.id,
    required this.amountMinorUnits,
    required this.categoryId,
    this.accountId,
    this.note,
    required this.date,
    required this.timeString,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Amount in major currency units (e.g., Rupees / Dollars as double for UI display)
  double get amountDouble => amountMinorUnits / 100.0;

  static int doubleToMinorUnits(double value) {
    return (value * 100).round();
  }

  Map<String, dynamic> toMap() {
    final dateIso = "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return {
      if (id != null) 'id': id,
      'amount': amountMinorUnits,
      'category_id': categoryId,
      if (accountId != null) 'account_id': accountId,
      'note': note ?? '',
      'date': dateIso,
      'time': timeString,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    if (map['date'] is String) {
      parsedDate = DateTime.parse(map['date'] as String);
    } else {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(map['date'] as int);
    }

    return Expense(
      id: map['id'] as int?,
      amountMinorUnits: map['amount'] as int,
      categoryId: map['category_id'] as int,
      accountId: map['account_id'] as int?,
      note: (map['note'] as String?).toString().isEmpty ? null : map['note'] as String?,
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      timeString: (map['time'] as String?) ?? '00:00',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Expense copyWith({
    int? id,
    int? amountMinorUnits,
    int? categoryId,
    int? accountId,
    String? note,
    DateTime? date,
    String? timeString,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      note: note ?? this.note,
      date: date ?? this.date,
      timeString: timeString ?? this.timeString,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

