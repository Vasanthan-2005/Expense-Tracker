class Income {
  final int? id;
  final int amountMinorUnits; // Paise
  final int accountId;
  final int? categoryId;
  final String? sourceOrNote;
  final DateTime date;
  final String timeString; // HH:mm format
  final DateTime createdAt;
  final DateTime updatedAt;

  const Income({
    this.id,
    required this.amountMinorUnits,
    required this.accountId,
    this.categoryId,
    this.sourceOrNote,
    required this.date,
    required this.timeString,
    required this.createdAt,
    required this.updatedAt,
  });

  double get amountDouble => amountMinorUnits / 100.0;
  String? get note => sourceOrNote;

  static int doubleToMinorUnits(double value) {
    return (value * 100).round();
  }

  Map<String, dynamic> toMap() {
    final dateIso = "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return {
      if (id != null) 'id': id,
      'amount': amountMinorUnits,
      'account_id': accountId,
      if (categoryId != null) 'category_id': categoryId,
      'source_or_note': sourceOrNote ?? '',
      'date': dateIso,
      'time': timeString,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Income.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    if (map['date'] is String) {
      parsedDate = DateTime.parse(map['date'] as String);
    } else {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(map['date'] as int);
    }

    return Income(
      id: map['id'] as int?,
      amountMinorUnits: map['amount'] as int,
      accountId: map['account_id'] as int,
      categoryId: map['category_id'] as int?,
      sourceOrNote: (map['source_or_note'] as String?).toString().isEmpty ? null : map['source_or_note'] as String?,
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      timeString: (map['time'] as String?) ?? '00:00',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Income copyWith({
    int? id,
    int? amountMinorUnits,
    int? accountId,
    int? categoryId,
    bool resetCategoryId = false,
    String? sourceOrNote,
    DateTime? date,
    String? timeString,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Income(
      id: id ?? this.id,
      amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
      accountId: accountId ?? this.accountId,
      categoryId: resetCategoryId ? null : (categoryId ?? this.categoryId),
      sourceOrNote: sourceOrNote ?? this.sourceOrNote,
      date: date ?? this.date,
      timeString: timeString ?? this.timeString,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
