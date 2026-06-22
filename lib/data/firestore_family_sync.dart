import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/models/baby_profile.dart';
import '../domain/models/care_event.dart';
import '../domain/models/caregiver.dart';
import 'family_repository.dart';

class FirestoreFamilySyncAdapter implements FamilySyncAdapter {
  FirestoreFamilySyncAdapter._({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required User user,
  }) : _auth = auth,
       _firestore = firestore,
       _user = user;

  /// Keep the live listener bounded. BabyRelay's active product surfaces need
  /// today's/recent care context; older history remains in Firestore and can be
  /// paged/exported later without making every device listen to years of logs.
  static const int liveEventLimit = 500;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final User _user;
  final Map<String, FamilyState> _lastSyncedStateByFamily = {};

  static Future<FirestoreFamilySyncAdapter> create({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) async {
    final resolvedAuth = auth ?? FirebaseAuth.instance;
    final resolvedFirestore = firestore ?? FirebaseFirestore.instance;
    final user =
        resolvedAuth.currentUser ??
        (await resolvedAuth.signInAnonymously()).user;
    if (user == null) {
      throw StateError('Firebase Auth did not return an anonymous user.');
    }
    return FirestoreFamilySyncAdapter._(
      auth: resolvedAuth,
      firestore: resolvedFirestore,
      user: user,
    );
  }

  @override
  String get userId => _user.uid;

  @override
  String newFamilyId() => _firestore.collection('families').doc().id;

  DocumentReference<Map<String, dynamic>> _familyRef(String familyId) =>
      _firestore.collection('families').doc(familyId);

  CollectionReference<Map<String, dynamic>> _childrenRef(String familyId) =>
      _familyRef(familyId).collection('children');

  CollectionReference<Map<String, dynamic>> _caregiversRef(String familyId) =>
      _familyRef(familyId).collection('caregivers');

  CollectionReference<Map<String, dynamic>> _eventsRef(String familyId) =>
      _familyRef(familyId).collection('events');

  DocumentReference<Map<String, dynamic>> _inviteRef(String code) =>
      _firestore.collection('inviteCodes').doc(code.toUpperCase());

  Map<String, dynamic> _familyDocument(
    FamilyState state, {
    required bool isNewFamily,
  }) {
    final memberIds = state.activeCaregivers.map((c) => c.id).toSet().toList()
      ..sort();
    final ownerId = state.caregivers
        .where((c) => c.isOwner)
        .map((c) => c.id)
        .firstOrNull;
    return {
      'schemaVersion': FamilyState.schemaVersion,
      'ownerId': ownerId,
      'memberIds': memberIds,
      'inviteCode': state.inviteCode.toUpperCase(),
      'selectedChildId': state.selectedChildId,
      'familySubscriptionActive': state.familySubscriptionActive,
      'familySubscriptionPlanId': state.familySubscriptionPlanId,
      'familySubscriptionOwnerId': state.familySubscriptionOwnerId,
      'onboarded': state.onboarded,
      'liveEventLimit': liveEventLimit,
      'updatedBy': userId,
      'updatedAt': FieldValue.serverTimestamp(),
      if (isNewFamily) 'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> _childDocument(BabyProfile child, int sortIndex) => {
    ...child.toJson(),
    'sortIndex': sortIndex,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Map<String, dynamic> _caregiverDocument(Caregiver caregiver, int sortIndex) =>
      {
        ...caregiver.toJson(),
        'sortIndex': sortIndex,
        'active': caregiver.isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> _eventDocument(CareEvent event) => {
    ...event.toJson(),
    'startAtMillis': event.startAt.millisecondsSinceEpoch,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  @override
  Stream<FamilyState> watchFamily(String familyId) {
    final controller = StreamController<FamilyState>();
    final subscriptions = <StreamSubscription<dynamic>>[];
    Map<String, dynamic>? familyData;
    final children = <String, _ChildDocument>{};
    final caregivers = <String, _CaregiverDocument>{};
    final events = <String, CareEvent>{};
    var familyReady = false;
    var childrenReady = false;
    var caregiversReady = false;
    var eventsReady = false;

    void emitIfReady() {
      final data = familyData;
      if (data == null ||
          !familyReady ||
          !childrenReady ||
          !caregiversReady ||
          !eventsReady ||
          controller.isClosed) {
        return;
      }
      final memberIds = (data['memberIds'] as List<dynamic>? ?? const [])
          .cast<String>();
      if (!memberIds.contains(userId)) return;

      final state = _stateFromParts(
        familyId: familyId,
        familyData: data,
        children: children.values.toList(),
        caregivers: caregivers.values.toList(),
        events: events.values.toList(),
        currentCaregiverId: userId,
      );
      _lastSyncedStateByFamily[familyId] = state;
      controller.add(state);
    }

    void addError(Object error, StackTrace stackTrace) {
      if (!controller.isClosed) controller.addError(error, stackTrace);
    }

    subscriptions.add(
      _familyRef(familyId).snapshots().listen((snapshot) {
        if (!snapshot.exists) return;
        familyData = snapshot.data();
        familyReady = true;
        emitIfReady();
      }, onError: addError),
    );
    subscriptions.add(
      _childrenRef(familyId).snapshots().listen((snapshot) {
        _applyDocumentChanges(snapshot, children, _childFromSnapshot);
        childrenReady = true;
        emitIfReady();
      }, onError: addError),
    );
    subscriptions.add(
      _caregiversRef(familyId).snapshots().listen((snapshot) {
        _applyDocumentChanges(snapshot, caregivers, _caregiverFromSnapshot);
        caregiversReady = true;
        emitIfReady();
      }, onError: addError),
    );
    subscriptions.add(
      _eventsRef(familyId)
          .orderBy('startAtMillis', descending: true)
          .limit(liveEventLimit)
          .snapshots()
          .listen((snapshot) {
            _applyDocumentChanges(snapshot, events, _eventFromSnapshot);
            eventsReady = true;
            emitIfReady();
          }, onError: addError),
    );

    controller.onCancel = () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    };
    return controller.stream;
  }

  void _applyDocumentChanges<T>(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    Map<String, T> target,
    T Function(DocumentSnapshot<Map<String, dynamic>> doc) decode,
  ) {
    for (final change in snapshot.docChanges) {
      if (change.type == DocumentChangeType.removed) {
        target.remove(change.doc.id);
      } else {
        target[change.doc.id] = decode(change.doc);
      }
    }
  }

  @override
  Future<void> saveFamily(
    FamilyState state, {
    String? previousInviteCode,
  }) async {
    if (state.familyId.isEmpty) return;
    final previous = _lastSyncedStateByFamily[state.familyId];
    final batch = _firestore.batch();
    var writeCount = 0;
    final removedChildIds = previous == null
        ? <String>{}
        : previous.children
              .map((child) => child.id)
              .where((id) => !state.children.any((child) => child.id == id))
              .toSet();

    bool familyMetadataChanged() {
      if (previous == null) return true;
      return !_sameIds(previous.caregivers, state.caregivers, (c) => c.id) ||
          !_sameIds(
            previous.activeCaregivers,
            state.activeCaregivers,
            (c) => c.id,
          ) ||
          previous.inviteCode.toUpperCase() != state.inviteCode.toUpperCase() ||
          previous.selectedChildId != state.selectedChildId ||
          previous.familySubscriptionActive != state.familySubscriptionActive ||
          previous.familySubscriptionPlanId != state.familySubscriptionPlanId ||
          previous.familySubscriptionOwnerId !=
              state.familySubscriptionOwnerId ||
          previous.onboarded != state.onboarded;
    }

    if (familyMetadataChanged()) {
      batch.set(
        _familyRef(state.familyId),
        _familyDocument(state, isNewFamily: previous == null),
      );
      writeCount++;
    }

    writeCount += _syncCollectionDelta<BabyProfile>(
      batch: batch,
      collection: _childrenRef(state.familyId),
      previous: previous?.children ?? const [],
      next: state.children,
      idOf: (child) => child.id,
      encode: (child) => _childDocument(child, state.children.indexOf(child)),
    );

    writeCount += _syncCollectionDelta<Caregiver>(
      batch: batch,
      collection: _caregiversRef(state.familyId),
      previous: previous?.caregivers ?? const [],
      next: state.caregivers,
      idOf: (caregiver) => caregiver.id,
      encode: (caregiver) =>
          _caregiverDocument(caregiver, state.caregivers.indexOf(caregiver)),
    );

    writeCount += _syncCollectionDelta<CareEvent>(
      batch: batch,
      collection: _eventsRef(state.familyId),
      previous: previous?.events ?? const [],
      next: state.events,
      idOf: (event) => event.id,
      encode: _eventDocument,
    );

    final nextCode = state.inviteCode.toUpperCase();
    if (previousInviteCode != null &&
        previousInviteCode.isNotEmpty &&
        previousInviteCode.toUpperCase() != nextCode) {
      batch.delete(_inviteRef(previousInviteCode));
      writeCount++;
    }
    if (nextCode.isNotEmpty &&
        (previous == null ||
            previous.inviteCode.toUpperCase() != nextCode ||
            previous.familyId != state.familyId)) {
      final ownerId =
          state.caregivers
              .where((c) => c.isOwner)
              .map((c) => c.id)
              .firstOrNull ??
          state.currentCaregiverId;
      batch.set(_inviteRef(nextCode), {
        'code': nextCode,
        'familyId': state.familyId,
        'ownerId': ownerId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      writeCount++;
    }

    if (writeCount == 0) {
      _lastSyncedStateByFamily[state.familyId] = state;
      await _deleteEventsForRemovedChildren(state.familyId, removedChildIds);
      return;
    }
    await batch.commit();
    _lastSyncedStateByFamily[state.familyId] = state;
    await _deleteEventsForRemovedChildren(state.familyId, removedChildIds);
  }

  int _syncCollectionDelta<T>({
    required WriteBatch batch,
    required CollectionReference<Map<String, dynamic>> collection,
    required List<T> previous,
    required List<T> next,
    required String Function(T item) idOf,
    required Map<String, dynamic> Function(T item) encode,
  }) {
    var writes = 0;
    final previousById = {for (final item in previous) idOf(item): item};
    final nextById = {for (final item in next) idOf(item): item};

    for (final item in next) {
      final id = idOf(item);
      if (previousById[id] != item) {
        batch.set(collection.doc(id), encode(item));
        writes++;
      }
    }

    for (final id in previousById.keys) {
      if (!nextById.containsKey(id)) {
        batch.delete(collection.doc(id));
        writes++;
      }
    }
    return writes;
  }

  bool _sameIds<T>(
    Iterable<T> left,
    Iterable<T> right,
    String Function(T item) idOf,
  ) {
    final leftIds = left.map(idOf).toSet();
    final rightIds = right.map(idOf).toSet();
    return leftIds.length == rightIds.length && leftIds.containsAll(rightIds);
  }

  @override
  Future<FamilyState> joinFamilyByInviteCode({
    required String code,
    required Caregiver caregiver,
    required int freeCaregiverLimit,
    required bool allowOverFreeCaregiverLimit,
  }) async {
    final normalizedCode = code
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    final now = DateTime.now();
    final familyId = await _firestore.runTransaction((transaction) async {
      final inviteSnapshot = await transaction.get(_inviteRef(normalizedCode));
      final invite = inviteSnapshot.data();
      final inviteFamilyId = invite?['familyId'] as String?;
      if (inviteFamilyId == null || inviteFamilyId.isEmpty) {
        throw StateError('Invite code not found.');
      }

      final familyReference = _familyRef(inviteFamilyId);
      final familySnapshot = await transaction.get(familyReference);
      final family = familySnapshot.data();
      if (!familySnapshot.exists || family == null) {
        throw StateError('This care team is no longer available.');
      }

      final memberIds = (family['memberIds'] as List<dynamic>? ?? const [])
          .cast<String>();
      final familySubscriptionActive =
          family['familySubscriptionActive'] as bool? ?? false;
      final wouldIncreaseActiveMembers = !memberIds.contains(caregiver.id);
      if (!allowOverFreeCaregiverLimit &&
          !familySubscriptionActive &&
          wouldIncreaseActiveMembers &&
          memberIds.length >= freeCaregiverLimit) {
        throw StateError('This care team is full on the free plan.');
      }

      final nextMembers = {...memberIds, caregiver.id}.toList()..sort();
      transaction.update(familyReference, {
        'memberIds': nextMembers,
        'updatedBy': userId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(
        _caregiversRef(inviteFamilyId).doc(caregiver.id),
        _caregiverDocument(
          caregiver.copyWith(
            role: CaregiverRole.caregiver,
            clearRemovedAt: true,
            lastActiveAt: now,
          ),
          nextMembers.length - 1,
        ),
      );
      return inviteFamilyId;
    });

    final joined = await _fetchFamilyState(
      familyId,
      currentCaregiverId: caregiver.id,
    );
    _lastSyncedStateByFamily[familyId] = joined;
    return joined;
  }

  Future<FamilyState> _fetchFamilyState(
    String familyId, {
    required String currentCaregiverId,
  }) async {
    final familySnapshot = await _familyRef(familyId).get();
    final familyData = familySnapshot.data();
    if (!familySnapshot.exists || familyData == null) {
      throw StateError('This care team is no longer available.');
    }
    final memberIds = (familyData['memberIds'] as List<dynamic>? ?? const [])
        .cast<String>();
    if (!memberIds.contains(userId)) {
      throw StateError('This care team is no longer available.');
    }

    final childrenSnapshot = await _childrenRef(familyId).get();
    final caregiversSnapshot = await _caregiversRef(familyId).get();
    final eventsSnapshot = await _eventsRef(
      familyId,
    ).orderBy('startAtMillis', descending: true).limit(liveEventLimit).get();

    return _stateFromParts(
      familyId: familyId,
      familyData: familyData,
      children: childrenSnapshot.docs.map(_childFromSnapshot).toList(),
      caregivers: caregiversSnapshot.docs.map(_caregiverFromSnapshot).toList(),
      events: eventsSnapshot.docs.map(_eventFromSnapshot).toList(),
      currentCaregiverId: currentCaregiverId,
    );
  }

  @override
  Future<void> deleteFamily(FamilyState state) async {
    if (state.familyId.isEmpty) return;
    await _deleteCollectionDocuments(_eventsRef(state.familyId));
    await _deleteCollectionDocuments(_childrenRef(state.familyId));
    await _deleteCollectionDocuments(_caregiversRef(state.familyId));
    final batch = _firestore.batch();
    batch.delete(_familyRef(state.familyId));
    if (state.inviteCode.isNotEmpty) {
      batch.delete(_inviteRef(state.inviteCode));
    }
    await batch.commit();
    _lastSyncedStateByFamily.remove(state.familyId);
  }

  Future<void> _deleteCollectionDocuments(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    await _deleteQueryDocuments(collection.limit(450));
  }

  Future<void> _deleteEventsForRemovedChildren(
    String familyId,
    Set<String> removedChildIds,
  ) async {
    for (final childId in removedChildIds) {
      await _deleteQueryDocuments(
        _eventsRef(familyId).where('childId', isEqualTo: childId).limit(450),
      );
    }
  }

  Future<void> _deleteQueryDocuments(Query<Map<String, dynamic>> query) async {
    QuerySnapshot<Map<String, dynamic>> snapshot;
    do {
      snapshot = await query.get();
      if (snapshot.docs.isEmpty) return;
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snapshot.docs.length == 450);
  }

  @override
  Future<void> dispose() async {
    await _auth.currentUser?.reload();
  }

  FamilyState _stateFromParts({
    required String familyId,
    required Map<String, dynamic> familyData,
    required List<_ChildDocument> children,
    required List<_CaregiverDocument> caregivers,
    required List<CareEvent> events,
    required String currentCaregiverId,
  }) {
    children.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    caregivers.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    events.sort((a, b) => a.startAt.compareTo(b.startAt));

    final childProfiles = children.map((c) => c.profile).toList();
    var selectedChildId = familyData['selectedChildId'] as String? ?? '';
    if (childProfiles.isNotEmpty &&
        !childProfiles.any((c) => c.id == selectedChildId)) {
      selectedChildId = childProfiles.first.id;
    }

    final caregiverProfiles = caregivers.map((c) => c.caregiver).toList();
    final fallbackOwnerId = caregiverProfiles
        .where((c) => c.isOwner)
        .map((c) => c.id)
        .firstOrNull;
    final activeCurrentCaregiverId =
        caregiverProfiles.any((c) => c.id == currentCaregiverId && c.isActive)
        ? currentCaregiverId
        : (fallbackOwnerId ?? '');

    return FamilyState(
      familyId: familyId,
      children: childProfiles,
      selectedChildId: selectedChildId,
      caregivers: caregiverProfiles,
      events: events,
      currentCaregiverId: activeCurrentCaregiverId,
      inviteCode: familyData['inviteCode'] as String? ?? '',
      familySubscriptionActive:
          familyData['familySubscriptionActive'] as bool? ?? false,
      familySubscriptionPlanId:
          familyData['familySubscriptionPlanId'] as String? ?? '',
      familySubscriptionOwnerId:
          familyData['familySubscriptionOwnerId'] as String? ?? '',
      onboarded: familyData['onboarded'] as bool? ?? childProfiles.isNotEmpty,
    );
  }

  _ChildDocument _childFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Child ${doc.id} is missing data.');
    }
    return _ChildDocument(
      profile: BabyProfile.fromJson(data),
      sortIndex: data['sortIndex'] as int? ?? 0,
    );
  }

  _CaregiverDocument _caregiverFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Caregiver ${doc.id} is missing data.');
    }
    return _CaregiverDocument(
      caregiver: Caregiver.fromJson(data),
      sortIndex: data['sortIndex'] as int? ?? 0,
    );
  }

  CareEvent _eventFromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Care event ${doc.id} is missing data.');
    }
    return CareEvent.fromJson(data);
  }
}

class _ChildDocument {
  const _ChildDocument({required this.profile, required this.sortIndex});

  final BabyProfile profile;
  final int sortIndex;
}

class _CaregiverDocument {
  const _CaregiverDocument({required this.caregiver, required this.sortIndex});

  final Caregiver caregiver;
  final int sortIndex;
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
