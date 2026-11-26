import 'package:flutter/material.dart';

class SessionLabel {
  const SessionLabel({
    required this.id,
    required this.name,
    required this.colorHex,
    this.isArchived = false,
    required this.createdAtMs,
  });

  final String id;
  final String name;
  final String colorHex;
  final bool isArchived;
  final int createdAtMs;

  Color get color {
    final normalized = colorHex.replaceFirst('#', '');
    final value = int.tryParse(
      normalized.length == 6 ? 'FF$normalized' : normalized,
      radix: 16,
    );
    return Color(value ?? 0xFF2563EB);
  }

  SessionLabel copyWith({
    String? id,
    String? name,
    String? colorHex,
    bool? isArchived,
    int? createdAtMs,
  }) {
    return SessionLabel(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      isArchived: isArchived ?? this.isArchived,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'id': id,
      'name': name,
      'color_hex': colorHex,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAtMs,
    };
  }

  factory SessionLabel.fromDbMap(Map<String, Object?> map) {
    return SessionLabel(
      id: map['id'] as String,
      name: map['name'] as String,
      colorHex: map['color_hex'] as String,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      createdAtMs: map['created_at'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color_hex': colorHex,
        'is_archived': isArchived,
        'created_at': createdAtMs,
      };

  factory SessionLabel.fromJson(Map<String, dynamic> json) => SessionLabel(
        id: json['id'] as String,
        name: json['name'] as String,
        colorHex: json['color_hex'] as String,
        isArchived: json['is_archived'] as bool? ?? false,
        createdAtMs: (json['created_at'] as num?)?.toInt() ??
            DateTime.now().millisecondsSinceEpoch,
      );
}
