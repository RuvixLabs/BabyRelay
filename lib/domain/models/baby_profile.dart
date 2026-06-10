import 'package:equatable/equatable.dart';

class BabyProfile extends Equatable {
  const BabyProfile({
    required this.id,
    required this.nickname,
    required this.dob,
    required this.wakeTimeMinutes,
    required this.bedtimeMinutes,
    required this.napsPerDayEstimate,
    this.colorIndex = 0,
    this.scheduleOverrideNaps,
  });

  final String id;
  final String nickname;
  final DateTime dob;

  /// Typical morning wake time, minutes since midnight.
  final int wakeTimeMinutes;

  /// Target bedtime, minutes since midnight.
  final int bedtimeMinutes;
  final int napsPerDayEstimate;

  /// Index into the design system's child palette so each child keeps a
  /// stable accent color across sessions.
  final int colorIndex;

  /// When the parent has confirmed a nap transition, this pins the schedule
  /// instead of the age table.
  final int? scheduleOverrideNaps;

  String get initial =>
      nickname.trim().isEmpty ? '?' : nickname.trim()[0].toUpperCase();

  int ageInWeeksAt(DateTime now) {
    final days = now.difference(dob).inDays;
    return days < 0 ? 0 : days ~/ 7;
  }

  String ageLabelAt(DateTime now) {
    final days = now.difference(dob).inDays;
    if (days < 0) return 'Not born yet';
    if (days < 7 * 12) {
      final weeks = days ~/ 7;
      return weeks == 1 ? '1 week old' : '$weeks weeks old';
    }
    final months = days ~/ 30;
    if (months < 24) {
      return months == 1 ? '1 month old' : '$months months old';
    }
    final years = days ~/ 365;
    return years == 1 ? '1 year old' : '$years years old';
  }

  /// Short age, for tight spots like the child switcher ("7 mo", "2 yr").
  String shortAgeLabelAt(DateTime now) {
    final days = now.difference(dob).inDays;
    if (days < 0) return 'soon';
    if (days < 7 * 12) return '${days ~/ 7} wk';
    final months = days ~/ 30;
    if (months < 24) return '$months mo';
    return '${days ~/ 365} yr';
  }

  BabyProfile copyWith({
    String? nickname,
    DateTime? dob,
    int? wakeTimeMinutes,
    int? bedtimeMinutes,
    int? napsPerDayEstimate,
    int? colorIndex,
    int? scheduleOverrideNaps,
    bool clearScheduleOverride = false,
  }) {
    return BabyProfile(
      id: id,
      nickname: nickname ?? this.nickname,
      dob: dob ?? this.dob,
      wakeTimeMinutes: wakeTimeMinutes ?? this.wakeTimeMinutes,
      bedtimeMinutes: bedtimeMinutes ?? this.bedtimeMinutes,
      napsPerDayEstimate: napsPerDayEstimate ?? this.napsPerDayEstimate,
      colorIndex: colorIndex ?? this.colorIndex,
      scheduleOverrideNaps: clearScheduleOverride
          ? null
          : (scheduleOverrideNaps ?? this.scheduleOverrideNaps),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nickname': nickname,
    'dob': dob.toIso8601String(),
    'wakeTimeMinutes': wakeTimeMinutes,
    'bedtimeMinutes': bedtimeMinutes,
    'napsPerDayEstimate': napsPerDayEstimate,
    'colorIndex': colorIndex,
    'scheduleOverrideNaps': scheduleOverrideNaps,
  };

  factory BabyProfile.fromJson(Map<String, dynamic> json) => BabyProfile(
    // Legacy single-child profiles had no id; the repository assigns one
    // during migration.
    id: json['id'] as String? ?? '',
    nickname: json['nickname'] as String,
    dob: DateTime.parse(json['dob'] as String),
    wakeTimeMinutes: json['wakeTimeMinutes'] as int,
    bedtimeMinutes: json['bedtimeMinutes'] as int,
    napsPerDayEstimate: json['napsPerDayEstimate'] as int? ?? 3,
    colorIndex: json['colorIndex'] as int? ?? 0,
    scheduleOverrideNaps: json['scheduleOverrideNaps'] as int?,
  );

  @override
  List<Object?> get props => [
    id,
    nickname,
    dob,
    wakeTimeMinutes,
    bedtimeMinutes,
    napsPerDayEstimate,
    colorIndex,
    scheduleOverrideNaps,
  ];
}
