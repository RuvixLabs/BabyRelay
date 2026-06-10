import 'package:equatable/equatable.dart';

class BabyProfile extends Equatable {
  const BabyProfile({
    required this.nickname,
    required this.dob,
    required this.wakeTimeMinutes,
    required this.bedtimeMinutes,
    required this.napsPerDayEstimate,
    this.scheduleOverrideNaps,
  });

  final String nickname;
  final DateTime dob;

  /// Typical morning wake time, minutes since midnight.
  final int wakeTimeMinutes;

  /// Target bedtime, minutes since midnight.
  final int bedtimeMinutes;
  final int napsPerDayEstimate;

  /// When the parent has confirmed a nap transition, this pins the schedule
  /// instead of the age table.
  final int? scheduleOverrideNaps;

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

  BabyProfile copyWith({
    String? nickname,
    DateTime? dob,
    int? wakeTimeMinutes,
    int? bedtimeMinutes,
    int? napsPerDayEstimate,
    int? scheduleOverrideNaps,
    bool clearScheduleOverride = false,
  }) {
    return BabyProfile(
      nickname: nickname ?? this.nickname,
      dob: dob ?? this.dob,
      wakeTimeMinutes: wakeTimeMinutes ?? this.wakeTimeMinutes,
      bedtimeMinutes: bedtimeMinutes ?? this.bedtimeMinutes,
      napsPerDayEstimate: napsPerDayEstimate ?? this.napsPerDayEstimate,
      scheduleOverrideNaps: clearScheduleOverride
          ? null
          : (scheduleOverrideNaps ?? this.scheduleOverrideNaps),
    );
  }

  Map<String, dynamic> toJson() => {
    'nickname': nickname,
    'dob': dob.toIso8601String(),
    'wakeTimeMinutes': wakeTimeMinutes,
    'bedtimeMinutes': bedtimeMinutes,
    'napsPerDayEstimate': napsPerDayEstimate,
    'scheduleOverrideNaps': scheduleOverrideNaps,
  };

  factory BabyProfile.fromJson(Map<String, dynamic> json) => BabyProfile(
    nickname: json['nickname'] as String,
    dob: DateTime.parse(json['dob'] as String),
    wakeTimeMinutes: json['wakeTimeMinutes'] as int,
    bedtimeMinutes: json['bedtimeMinutes'] as int,
    napsPerDayEstimate: json['napsPerDayEstimate'] as int? ?? 3,
    scheduleOverrideNaps: json['scheduleOverrideNaps'] as int?,
  );

  @override
  List<Object?> get props => [
    nickname,
    dob,
    wakeTimeMinutes,
    bedtimeMinutes,
    napsPerDayEstimate,
    scheduleOverrideNaps,
  ];
}
