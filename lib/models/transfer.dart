class Transfer {
  final int? id;
  final int amountMinorUnits; // Paise
  final int fromAccountId;
  final int toAccountId;
  final String? note;
  final DateTime date;
  final String timeString; // HH:mm format
  final DateTime createdAt;
  final DateTime updatedAt;

  const Transfer({
    this.id,
    required this.amountMinorUnits,
    required this.fromAccountId,
    required this.toAccountId,
    this.note,
    required this.date,
    required this.timeString,
    required this.createdAt,
    required this.updatedAt,
  });

  double get amountDouble => amountMinorUnits / 100.0;

  static int doubleToMinorUnits(double value) {
    return (value * 100).round();
  }

  Map<String, dynamic> toMap() {
    final dateIso = "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    return {
      if (id != null) 'id': id,
      'amount': amountMinorUnits,
      'from_account_id': fromAccountId,
      'to_account_id': toAccountId,
      'note': note ?? '',
      'date': dateIso,
      'time': timeString,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory Transfer.fromMap(Map<String, dynamic> map) {
    DateTime parsedDate;
    if (map['date'] is String) {
      parsedDate = DateTime.parse(map['date'] as String);
    } else {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(map['date'] as int);
    }

    return Transfer(
      id: map['id'] as int?,
      amountMinorUnits: map['amount'] as int,
      fromAccountId: map['from_account_id'] as int,
      toAccountId: map['to_account_id'] as int,
      note: (map['note'] as String?).toString().isEmpty ? null : map['note'] as String?,
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      timeString: (map['time'] as String?) ?? '00:00',
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Transfer copyWith({
    int? id,
    int? amountMinorUnits,
    int? fromAccountId,
    int? toAccountId,
    String? note,
    DateTime? date,
    String? timeString,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Transfer(
      id: id ?? this.id,
      amountMinorUnits: amountMinorUnits ?? this.amountMinorUnits,
      fromAccountId: fromAccountId ?? this.fromAccountId,
      toAccountId: toAccountId ?? this.toAccountId,
      note: note ?? this.note,
      date: date ?? this.date,
      timeString: timeString ?? this.timeString,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
