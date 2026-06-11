import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final User _user;

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

  DocumentReference<Map<String, dynamic>> _inviteRef(String code) =>
      _firestore.collection('inviteCodes').doc(code.toUpperCase());

  Map<String, dynamic> _familyDocument(FamilyState state) {
    final memberIds = state.activeCaregivers.map((c) => c.id).toSet().toList()
      ..sort();
    return {
      'schemaVersion': FamilyState.schemaVersion,
      'state': state.toJson(),
      'ownerId': state.caregivers
          .where((c) => c.isOwner)
          .map((c) => c.id)
          .firstOrNull,
      'memberIds': memberIds,
      'inviteCode': state.inviteCode,
      'updatedBy': userId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  Stream<FamilyState> watchFamily(String familyId) {
    return _familyRef(familyId)
        .snapshots()
        .where((snapshot) {
          final data = snapshot.data();
          final members = (data?['memberIds'] as List<dynamic>? ?? const []);
          return snapshot.exists && members.contains(userId);
        })
        .map((snapshot) => _stateFromDocument(snapshot.id, snapshot.data()!));
  }

  @override
  Future<void> saveFamily(
    FamilyState state, {
    String? previousInviteCode,
  }) async {
    if (state.familyId.isEmpty) return;
    final batch = _firestore.batch();
    batch.set(_familyRef(state.familyId), _familyDocument(state));

    final nextCode = state.inviteCode.toUpperCase();
    if (previousInviteCode != null &&
        previousInviteCode.isNotEmpty &&
        previousInviteCode.toUpperCase() != nextCode) {
      batch.delete(_inviteRef(previousInviteCode));
    }
    if (nextCode.isNotEmpty) {
      batch.set(_inviteRef(nextCode), {
        'code': nextCode,
        'familyId': state.familyId,
        'ownerId': state.currentCaregiverId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  Future<FamilyState> joinFamilyByInviteCode({
    required String code,
    required Caregiver caregiver,
    required int freeCaregiverLimit,
    required bool allowOverFreeCaregiverLimit,
  }) {
    final normalizedCode = code
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    return _firestore.runTransaction((transaction) async {
      final inviteSnapshot = await transaction.get(_inviteRef(normalizedCode));
      final invite = inviteSnapshot.data();
      final familyId = invite?['familyId'] as String?;
      if (familyId == null || familyId.isEmpty) {
        throw StateError('Invite code not found.');
      }

      final familyReference = _familyRef(familyId);
      final familySnapshot = await transaction.get(familyReference);
      if (!familySnapshot.exists) {
        throw StateError('This care team is no longer available.');
      }

      final current = _stateFromDocument(familyId, familySnapshot.data()!);
      final existing = current.caregivers
          .where((c) => c.id == caregiver.id)
          .firstOrNull;
      final wouldIncreaseActiveMembers = existing == null || !existing.isActive;
      if (!allowOverFreeCaregiverLimit &&
          wouldIncreaseActiveMembers &&
          current.activeCaregivers.length >= freeCaregiverLimit) {
        throw StateError('This care team is full on the free plan.');
      }

      final caregivers = existing != null
          ? current.caregivers
                .map(
                  (c) => c.id == caregiver.id
                      ? c.copyWith(
                          name: caregiver.name,
                          role: CaregiverRole.caregiver,
                          clearRemovedAt: true,
                          lastActiveAt: DateTime.now(),
                        )
                      : c,
                )
                .toList()
          : [
              ...current.caregivers,
              caregiver.copyWith(
                role: CaregiverRole.caregiver,
                lastActiveAt: DateTime.now(),
              ),
            ];
      final joined = current.copyWith(
        caregivers: caregivers,
        currentCaregiverId: caregiver.id,
        onboarded: true,
      );
      transaction.set(familyReference, _familyDocument(joined));
      return joined;
    });
  }

  @override
  Future<void> deleteFamily(FamilyState state) async {
    if (state.familyId.isEmpty) return;
    final batch = _firestore.batch();
    batch.delete(_familyRef(state.familyId));
    if (state.inviteCode.isNotEmpty) {
      batch.delete(_inviteRef(state.inviteCode));
    }
    await batch.commit();
  }

  @override
  Future<void> dispose() async {
    await _auth.currentUser?.reload();
  }

  FamilyState _stateFromDocument(String familyId, Map<String, dynamic> data) {
    final stateJson = Map<String, dynamic>.from(data['state'] as Map);
    return FamilyState.fromJson(stateJson).copyWith(familyId: familyId);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
