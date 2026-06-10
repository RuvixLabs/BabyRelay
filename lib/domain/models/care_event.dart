import 'package:equatable/equatable.dart';

enum CareEventType { sleep, feed, diaper, note, nightWaking }

enum FeedKind { bottle, nursing, solids }

enum DiaperKind { wet, dirty, both }

/// A single logged care moment. Sleep events have an open [endAt] while the
/// baby is still asleep; every other type is a point-in-time event.
class CareEvent extends Equatable {
  const CareEvent({
    required this.id,
    required this.childId,
    required this.type,
    required this.startAt,
    this.endAt,
    required this.loggedById,
    this.editedByIds = const [],
    this.note,
    this.feedKind,
    this.diaperKind,
    this.merged = false,
  });

  final String id;

  /// Which child this event belongs to. Always set — every event is scoped
  /// to a child at creation time.
  final String childId;
  final CareEventType type;
  final DateTime startAt;
  final DateTime? endAt;
  final String loggedById;
  final List<String> editedByIds;
  final String? note;
  final FeedKind? feedKind;
  final DiaperKind? diaperKind;
  final bool merged;

  bool get isSleep => type == CareEventType.sleep;
  bool get isOngoingSleep => isSleep && endAt == null;

  Duration? get duration => endAt?.difference(startAt);

  CareEvent copyWith({
    String? childId,
    DateTime? startAt,
    DateTime? endAt,
    bool clearEndAt = false,
    List<String>? editedByIds,
    String? note,
    bool clearNote = false,
    FeedKind? feedKind,
    DiaperKind? diaperKind,
    bool? merged,
  }) {
    return CareEvent(
      id: id,
      childId: childId ?? this.childId,
      type: type,
      startAt: startAt ?? this.startAt,
      endAt: clearEndAt ? null : (endAt ?? this.endAt),
      loggedById: loggedById,
      editedByIds: editedByIds ?? this.editedByIds,
      note: clearNote ? null : (note ?? this.note),
      feedKind: feedKind ?? this.feedKind,
      diaperKind: diaperKind ?? this.diaperKind,
      merged: merged ?? this.merged,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'childId': childId,
    'type': type.name,
    'startAt': startAt.toIso8601String(),
    'endAt': endAt?.toIso8601String(),
    'loggedById': loggedById,
    'editedByIds': editedByIds,
    'note': note,
    'feedKind': feedKind?.name,
    'diaperKind': diaperKind?.name,
    'merged': merged,
  };

  factory CareEvent.fromJson(Map<String, dynamic> json) => CareEvent(
    id: json['id'] as String,
    childId: json['childId'] as String,
    type: CareEventType.values.byName(json['type'] as String),
    startAt: DateTime.parse(json['startAt'] as String),
    endAt: json['endAt'] == null
        ? null
        : DateTime.parse(json['endAt'] as String),
    loggedById: json['loggedById'] as String,
    editedByIds: (json['editedByIds'] as List<dynamic>? ?? []).cast<String>(),
    note: json['note'] as String?,
    feedKind: json['feedKind'] == null
        ? null
        : FeedKind.values.byName(json['feedKind'] as String),
    diaperKind: json['diaperKind'] == null
        ? null
        : DiaperKind.values.byName(json['diaperKind'] as String),
    merged: json['merged'] as bool? ?? false,
  );

  @override
  List<Object?> get props => [
    id,
    childId,
    type,
    startAt,
    endAt,
    loggedById,
    editedByIds,
    note,
    feedKind,
    diaperKind,
    merged,
  ];
}
