class FridgeItem {
  final String name;
  final DateTime addedAt;
  final DateTime? expiryDate;

  const FridgeItem({required this.name, required this.addedAt, this.expiryDate});

  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    final today = DateTime.now();
    final d = DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day);
    final t = DateTime(today.year, today.month, today.day);
    return d.difference(t).inDays;
  }

  bool get isExpired => daysUntilExpiry != null && daysUntilExpiry! < 0;
  bool get expiresSoon => daysUntilExpiry != null && daysUntilExpiry! >= 0 && daysUntilExpiry! <= 2;
  bool get needsAlert => isExpired || expiresSoon;

  FridgeItem copyWith({DateTime? expiryDate, bool clearExpiry = false}) => FridgeItem(
        name: name,
        addedAt: addedAt,
        expiryDate: clearExpiry ? null : (expiryDate ?? this.expiryDate),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'addedAt': addedAt.toIso8601String(),
        if (expiryDate != null) 'expiryDate': expiryDate!.toIso8601String(),
      };

  factory FridgeItem.fromJson(Map<String, dynamic> json) => FridgeItem(
        name: json['name'] as String,
        addedAt: DateTime.parse(json['addedAt'] as String),
        expiryDate: json['expiryDate'] != null
            ? DateTime.parse(json['expiryDate'] as String)
            : null,
      );

  factory FridgeItem.simple(String name) =>
      FridgeItem(name: name, addedAt: DateTime.now());
}
