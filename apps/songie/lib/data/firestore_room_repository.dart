import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'song.dart';
import 'songie_room.dart';

/// Firestore repository for live singing rooms.
class FirestoreRoomRepository {
  FirestoreRoomRepository(this._firestore);

  static const _collectionName = 'rooms';
  static const _maximumParticipants = 30;
  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final FirebaseFirestore _firestore;
  final Random _random = Random.secure();

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _firestore.collection(_collectionName);

  Stream<List<SongieRoom>> watchMyRooms(String uid) {
    return _rooms
        .where('participantUids', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      final rooms = snapshot.docs
          .map(
            (document) => SongieRoom.fromFirestore(
              id: document.id,
              data: document.data(),
            ),
          )
          .where((room) => room.isActive)
          .toList(growable: false);
      return rooms;
    });
  }

  Stream<SongieRoom?> watchRoom(String roomCode) {
    return _rooms.doc(_normalizeCode(roomCode)).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return SongieRoom.fromFirestore(
        id: snapshot.id,
        data: snapshot.data()!,
      );
    });
  }

  Stream<List<SongieRoomParticipant>> watchParticipants(String roomCode) {
    return _rooms
        .doc(_normalizeCode(roomCode))
        .collection('participants')
        .snapshots()
        .map((snapshot) {
      final participants = snapshot.docs
          .map(
            (document) => SongieRoomParticipant.fromFirestore(
              uid: document.id,
              data: document.data(),
            ),
          )
          .toList(growable: false);
      return participants;
    });
  }

  Future<String> createRoom({
    required String name,
    required String uid,
    required String displayName,
    required String email,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.length < 2 || normalizedName.length > 60) {
      throw const FormatException(
        'Please enter a room name between 2 and 60 characters.',
      );
    }

    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _generateCode();
      final roomReference = _rooms.doc(code);
      try {
        await _firestore.runTransaction((transaction) async {
          final existing = await transaction.get(roomReference);
          if (existing.exists) {
            throw StateError('room-code-collision');
          }

          final now = FieldValue.serverTimestamp();
          transaction.set(roomReference, {
            'name': normalizedName,
            'ownerUid': uid,
            'ownerName': displayName,
            'status': 'active',
            'participantUids': [uid],
            'currentSongId': null,
            'currentSongTitle': null,
            'currentSongArtist': null,
            'selectedByUid': null,
            'selectedByName': null,
            'selectedAt': null,
            'closedAt': null,
            'createdAt': now,
            'updatedAt': now,
          });
          transaction.set(
            roomReference.collection('participants').doc(uid),
            {
              'uid': uid,
              'displayName': displayName,
              'email': email,
              'role': 'owner',
              'openedSongId': null,
              'lastOpenedSongAt': null,
              'joinedAt': now,
            },
          );
        });
        return code;
      } on StateError catch (error) {
        if (error.message == 'room-code-collision' && attempt < 4) continue;
        rethrow;
      }
    }

    throw StateError('Could not generate a unique room code. Please try again.');
  }

  /// Joins the room addressed by its invitation code.
  ///
  /// Returns false when the user was already a participant.
  Future<bool> joinRoom({
    required String roomCode,
    required String uid,
    required String displayName,
    required String email,
  }) async {
    final code = _normalizeCode(roomCode);
    if (code.length != 8) {
      throw const FormatException('Please enter the 8-character room code.');
    }

    final roomReference = _rooms.doc(code);
    final participantReference =
        roomReference.collection('participants').doc(uid);

    return _firestore.runTransaction<bool>((transaction) async {
      final roomSnapshot = await transaction.get(roomReference);
      if (!roomSnapshot.exists) {
        throw StateError('No room found for this code.');
      }

      final data = roomSnapshot.data()!;
      if (data['status'] != 'active') {
        throw StateError('This room has already been closed.');
      }

      final participantUids = (data['participantUids'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          <String>[];
      if (participantUids.contains(uid)) return false;
      if (participantUids.length >= _maximumParticipants) {
        throw StateError('This room is full (maximum $_maximumParticipants people).');
      }

      final now = FieldValue.serverTimestamp();
      transaction.update(roomReference, {
        'participantUids': FieldValue.arrayUnion([uid]),
        'updatedAt': now,
      });
      transaction.set(participantReference, {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'role': 'member',
        'openedSongId': null,
        'lastOpenedSongAt': null,
        'joinedAt': now,
      });
      return true;
    });
  }

  Future<void> selectSong({
    required SongieRoom room,
    required SongieSong song,
    required String uid,
    required String displayName,
  }) {
    if (!room.isOwner(uid)) {
      throw StateError('Only the room owner can select a song.');
    }
    return _rooms.doc(room.id).update({
      'currentSongId': song.id,
      'currentSongTitle': song.title,
      'currentSongArtist': song.artist,
      'selectedByUid': uid,
      'selectedByName': displayName,
      'selectedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markSongOpened({
    required String roomCode,
    required String uid,
    required String songId,
  }) {
    return _rooms
        .doc(_normalizeCode(roomCode))
        .collection('participants')
        .doc(uid)
        .update({
      'openedSongId': songId,
      'lastOpenedSongAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> leaveRoom({
    required SongieRoom room,
    required String uid,
  }) async {
    if (room.isOwner(uid)) {
      throw StateError('The room owner must close the room instead of leaving.');
    }

    final roomReference = _rooms.doc(room.id);
    final participantReference =
        roomReference.collection('participants').doc(uid);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(roomReference);
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      final participantUids = (data['participantUids'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          <String>[];
      if (!participantUids.contains(uid)) return;

      transaction.update(roomReference, {
        'participantUids': FieldValue.arrayRemove([uid]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.delete(participantReference);
    });
  }

  Future<void> closeRoom(SongieRoom room, String uid) async {
    if (!room.isOwner(uid)) {
      throw StateError('Only the room owner can close this room.');
    }
    await _rooms.doc(room.id).update({
      'status': 'closed',
      'closedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String _generateCode() {
    return List.generate(
      8,
      (_) => _codeAlphabet[_random.nextInt(_codeAlphabet.length)],
    ).join();
  }

  String _normalizeCode(String value) =>
      value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}
