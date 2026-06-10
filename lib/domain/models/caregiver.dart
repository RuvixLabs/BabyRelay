import 'package:equatable/equatable.dart';

enum CaregiverRole { owner, caregiver }

class Caregiver extends Equatable {
  const Caregiver({
    required this.id,
    required this.name,
    required this.role,
    required this.colorIndex,
    required this.joinedAt,
    this.removedAt,
    this.lastActiveAt,
  });

  final String id;
  final String name;
  final CaregiverRole role;

  /// Index into the design system's avatar palette so attribution colors stay
  /// stable across sessions without storing raw color values.
  final int colorIndex;
  final DateTime joinedAt;
  final DateTime? removedAt;
  final DateTime? lastActiveAt;

  bool get isActive => removedAt == null;
  bool get isOwner => role == CaregiverRole.owner;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Caregiver copyWith({
    String? name,
    CaregiverRole? role,
    DateTime? removedAt,
    bool clearRemovedAt = false,
    DateTime? lastActiveAt,
  }) {
    return Caregiver(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      colorIndex: colorIndex,
      joinedAt: joinedAt,
      removedAt: clearRemovedAt ? null : (removedAt ?? this.removedAt),
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role.name,
    'colorIndex': colorIndex,
    'joinedAt': joinedAt.toIso8601String(),
    'removedAt': removedAt?.toIso8601String(),
    'lastActiveAt': lastActiveAt?.toIso8601String(),
  };

  factory Caregiver.fromJson(Map<String, dynamic> json) => Caregiver(
    id: json['id'] as String,
    name: json['name'] as String,
    role: CaregiverRole.values.byName(json['role'] as String),
    colorIndex: json['colorIndex'] as int? ?? 0,
    joinedAt: DateTime.parse(json['joinedAt'] as String),
    removedAt: json['removedAt'] == null
        ? null
        : DateTime.parse(json['removedAt'] as String),
    lastActiveAt: json['lastActiveAt'] == null
        ? null
        : DateTime.parse(json['lastActiveAt'] as String),
  );

  @override
  List<Object?> get props => [
    id,
    name,
    role,
    colorIndex,
    joinedAt,
    removedAt,
    lastActiveAt,
  ];
}
